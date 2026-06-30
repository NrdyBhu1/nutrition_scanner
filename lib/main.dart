import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/tracker_screen.dart';
import 'screens/sync_screen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait — scanner UX breaks in landscape
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Edge-to-edge, transparent status bar over camera feed
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final dir = await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(dir.path, 'nutrition.db'));
  final needsSync = !await dbFile.exists();

  await NotificationService.instance.init();

  runApp(NutritionScannerApp(needsSync: needsSync));
}

class NutritionScannerApp extends StatelessWidget {
  final bool needsSync;
  const NutritionScannerApp({super.key, this.needsSync = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nutrition Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BCD4), // cyan — matches scan reticle
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A2E),
          titleTextStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
            letterSpacing: 0.3,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF1A1A2E),
          contentTextStyle: TextStyle(color: Colors.white, fontSize: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        scaffoldBackgroundColor: Color(0xFFF5F7FA),
      ),
      home: needsSync ? const _AutoSyncWrapper() : const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tab = 0;

  static const List<Widget> _screens = [
    const HistoryScreen(),
    const TrackerScreen(),
    const ProfileScreen(),
    const SyncScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(isActive: _tab == 0), // passes active flag
          ..._screens,
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF00BCD4).withOpacity(0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_rounded),
            selectedIcon: Icon(
              Icons.qr_code_scanner_rounded,
              color: Color(0xFF00BCD4),
            ),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded, color: Color(0xFF00BCD4)),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes_rounded),
            selectedIcon: Icon(
              Icons.track_changes_rounded,
              color: Color(0xFF00BCD4),
            ),
            label: 'Tracker',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF00BCD4)),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_sync_outlined),
            selectedIcon: Icon(
              Icons.cloud_sync_rounded,
              color: Color(0xFF00BCD4),
            ),
            label: 'Sync',
          ),
        ],
      ),
    );
  }
}
// ─── Auto Sync Wrapper ────────────────────────────────────────────────────────

class _AutoSyncWrapper extends StatefulWidget {
  const _AutoSyncWrapper();

  @override
  State<_AutoSyncWrapper> createState() => _AutoSyncWrapperState();
}

class _AutoSyncWrapperState extends State<_AutoSyncWrapper> {
  String _message = 'Checking database…';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _autoSync();
  }

  Future<void> _autoSync() async {
    try {
      setState(() => _message = 'Downloading database…');

      final result = await http
          .get(
            Uri.parse(kDbUrl),
            headers: {'User-Agent': 'NutritionScannerApp/1.0'},
          )
          .timeout(const Duration(seconds: 60));

      if (result.statusCode != 200) {
        throw Exception('Server returned ${result.statusCode}');
      }

      setState(() => _message = 'Installing database…');

      final dir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dir.path, 'nutrition.db');
      await File(dbPath).writeAsBytes(result.bodyBytes);

      setState(() => _message = 'Done!');
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const RootShell()));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = 'Failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_sync_rounded,
                  size: 64,
                  color: Color(0xFF00BCD4),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Setting up database',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 32),
                if (!_failed)
                  const CircularProgressIndicator(color: Color(0xFF00BCD4))
                else ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _failed = false;
                        _message = 'Retrying…';
                      });
                      _autoSync();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BCD4),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const RootShell()),
                    ),
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
