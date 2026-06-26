import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../db_helper.dart';
import 'nutrition_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.start();
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
      final product = await DatabaseHelper.instance.queryProduct(id);
      if (!mounted) return;

      if (product == null) {
        _showSnack('Product not found: $raw');
        await _controller.start();
        setState(() => _isProcessing = false);
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NutritionScreen(product: product)),
        );
        // Back from NutritionScreen — re-enable scanner
        if (mounted) {
          await _controller.start();
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
