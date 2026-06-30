import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../db_helper.dart';
import 'nutrition_screen.dart';
import '../utils/allergen_checker.dart';
import '../utils/rdi_constants.dart';
import '../models/daily_intake.dart';
import '../models/product.dart';
import '../services/openfoodfacts_service.dart';
import '../services/notification_service.dart';
import '../models/daily_intake.dart';

class HomeScreen extends StatefulWidget {
  final bool isActive;
  const HomeScreen({super.key, this.isActive = true});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false; // debounce flag

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Don't start if launched inactive (shouldn't happen but safe)
    if (!widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.stop();
      });
    }
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    if (old.isActive == widget.isActive) return;

    if (widget.isActive) {
      // Came back to scan tab — restart only if not processing
      if (!_isProcessing) {
        _controller.start();
      }
    } else {
      // Left scan tab — stop camera immediately
      _controller.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Only restart if this tab is active and not mid-processing
      if (widget.isActive && !_isProcessing) {
        _controller.start();
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final raw = barcode.rawValue!;
    final id = int.tryParse(raw);
    if (id == null) {
      _showSnack('Invalid barcode format: $raw');
      return;
    }

    setState(() => _isProcessing = true);
    await _controller.stop();

    try {
      Product? product = await DatabaseHelper.instance.queryProduct(id);

      // Not in local DB — try OpenFoodFacts API
      if (product == null) {
        if (mounted) {
          setState(() {
            // reuse _isProcessing to keep spinner, update hint text
          });
        }
        _showSnack('Not in local DB, checking OpenFoodFacts…');

        final offResult = await OpenFoodFactsService.fetch(id);

        if (!offResult.found || offResult.data == null) {
          if (mounted) {
            _showSnack('Product not found: $raw');
            await _controller.start();
            setState(() => _isProcessing = false);
          }
          return;
        }

        // Check if API returned any nutrition values at all
        final data = offResult.data!;
        print(offResult);
        final hasNutrition = [
          data['Calories'],
          data['Total Fat'],
          data['Total Carbs'],
          data['Protein'],
          data['Sugars'],
          data['Sodium'],
        ].any((v) => v != null);

        if (!hasNutrition) {
          if (mounted) {
            _showSnack('Product found but has no nutrition data');
            await _controller.start();
            setState(() => _isProcessing = false);
          }
          return;
        }

        // Insert into local DB safely
        try {
          await DatabaseHelper.instance.insertProduct(offResult.data!);
          // Re-query to get proper Product object
          product = await DatabaseHelper.instance.queryProduct(id);
        } catch (_) {
          // ignored
        }

        // Final fallback — build directly from API map
        if (product == null && offResult.data != null) {
          try {
            product = Product.fromMap(offResult.data!);
          } catch (_) {
            product = null;
          }
        }
      }

      if (!mounted) return;

      if (product == null) {
        _showSnack('Product not found: $raw');
        await _controller.start();
        setState(() => _isProcessing = false);
      } else if (product != null) {
        await DatabaseHelper.instance.insertScanEntry(
          product.productId,
          product.productName,
        );
        final profile = await DatabaseHelper.instance.fetchProfile();
        final rdi = RdiConstants.scaledForUser(profile);
        final today = await DatabaseHelper.instance.fetchDailyIntake(
          DailyIntake.todayKey,
        );
        final allergenResult = AllergenChecker.check(product!, profile);

        // Show allergen warning before navigating
        if (allergenResult.hasMatch && mounted) {
          await _showAllergenWarning(allergenResult);
        }

        // Nutrient alert check
        // Per-nutrient alert checks — sends notification once per nutrient per day
        await _checkAndNotify(
          nutrient: 'Sodium',
          consumed: today.totalSodium,
          rdi: rdi['Sodium'] ?? 2300,
          alertPct: profile.alertSodiumPct,
        );
        await _checkAndNotify(
          nutrient: 'Sugars',
          consumed: today.totalSugars,
          rdi: rdi['Sugars'] ?? 50,
          alertPct: profile.alertSugarPct,
        );
        await _checkAndNotify(
          nutrient: 'Total Fat',
          consumed: today.totalFat,
          rdi: rdi['Total Fat'] ?? 78,
          alertPct: profile.alertFatPct,
        );
        await _checkAndNotify(
          nutrient: 'Potassium',
          consumed: today.totalPotassium,
          rdi: rdi['Potassium'] ?? 4700,
          alertPct: profile.alertPotassiumPct,
        );
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NutritionScreen(product: product!)),
        );
        // Back from NutritionScreen — re-enable scanner
        if (mounted && widget.isActive) {
          await _controller.start();
          setState(() => _isProcessing = false);
        } else if (mounted) {
          // Switched tab while NutritionScreen was open — just clear flag
          setState(() => _isProcessing = false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnack('DB error: $e');
        await _controller.start();
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _showAllergenWarning(AllergenResult result) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.red,
          size: 36,
        ),
        title: const Text(
          'Allergen Alert',
          style: TextStyle(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.matchSummary,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'All flags: ${result.fullFlagSummary}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAndNotify({
    required String nutrient,
    required double consumed,
    required int rdi,
    required int alertPct,
  }) async {
    if (rdi <= 0) return;
    final pct = (consumed / rdi * 100);
    if (pct < alertPct) return;

    final todayKey = DailyIntake.todayKey;
    final alreadyFired = await DatabaseHelper.instance.hasAlertFiredToday(
      nutrient,
      todayKey,
    );
    if (alreadyFired) return;

    await NotificationService.instance.showNutrientAlert(
      title: '$nutrient limit reached',
      body:
          'You\'ve consumed ${consumed.toStringAsFixed(0)} of your '
          '$rdi daily limit (${pct.toStringAsFixed(0)}%)',
      id: nutrient.hashCode & 0x7FFFFFFF,
    );
    await DatabaseHelper.instance.markAlertFired(nutrient, todayKey);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Nutrition Scanner',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            tooltip: 'Toggle Torch',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera feed
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return _CameraError(error: error);
            },
          ),

          // Scanning overlay
          const _ScanOverlay(),

          // Processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Looking up product…',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom hint
          if (!_isProcessing)
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'Point camera at a barcode',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Scan reticle overlay ────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cutW = size.width * 0.72;
    final cutH = cutW * 0.55;
    final left = (size.width - cutW) / 2;
    final top = (size.height - cutH) / 2 - 40;
    final corner = 20.0;
    final stroke = 3.0;
    final cLen = 28.0;
    final color = const Color(0xFF00E5FF); // cyan accent

    return Stack(
      children: [
        // Dark scrim with transparent cutout
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.55),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Positioned(
                left: left,
                top: top,
                child: Container(
                  width: cutW,
                  height: cutH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(corner),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Corner brackets
        Positioned(
          left: left,
          top: top,
          child: CustomPaint(
            size: Size(cutW, cutH),
            painter: _CornerPainter(
              color: color,
              stroke: stroke,
              cornerLen: cLen,
              cornerRadius: corner,
            ),
          ),
        ),
      ],
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double stroke;
  final double cornerLen;
  final double cornerRadius;

  const _CornerPainter({
    required this.color,
    required this.stroke,
    required this.cornerLen,
    required this.cornerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final r = cornerRadius;
    final l = cornerLen;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, r + l)
        ..lineTo(0, r)
        ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
        ..lineTo(r + l, 0),
      paint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(w - r - l, 0)
        ..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
        ..lineTo(w, r + l),
      paint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(w, h - r - l)
        ..lineTo(w, h - r)
        ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
        ..lineTo(w - r - l, h),
      paint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(r + l, h)
        ..lineTo(r, h)
        ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
        ..lineTo(0, h - r - l),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

// ─── Camera permission / error widget ────────────────────────────────────────

class _CameraError extends StatelessWidget {
  final MobileScannerException error;
  const _CameraError({required this.error});

  @override
  Widget build(BuildContext context) {
    final msg = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Camera permission denied.\nGo to Settings → App → Camera and enable it.',
      MobileScannerErrorCode.unsupported =>
        'Camera not supported on this device.',
      _ => 'Camera error: ${error.errorCode}',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white54,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
