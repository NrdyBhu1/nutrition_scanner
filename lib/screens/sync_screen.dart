import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../db_helper.dart';

// ── Hardcoded sync URL ────────────────────────────────────────────────────────
const String _kDbUrl =
    'http://10.0.2.2:9001/nutrition.db'; // ← replace with real URL

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  _SyncState _state = _SyncState.idle;
  double _progress = 0;
  String _statusMsg = '';
  String? _error;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _loadLastSync();
  }

  Future<void> _loadLastSync() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'nutrition.db'));
    if (await file.exists()) {
      final modified = await file.lastModified();
      if (mounted) setState(() => _lastSync = modified);
    }
  }

  Future<void> _startSync() async {
    setState(() {
      _state = _SyncState.downloading;
      _progress = 0;
      _statusMsg = 'Connecting…';
      _error = null;
    });

    try {
      // ── 1. HEAD request to get content-length ─────────────────────────
      setState(() => _statusMsg = 'Checking remote file…');
      final headResp = await http
          .head(Uri.parse(_kDbUrl))
          .timeout(const Duration(seconds: 15));

      if (headResp.statusCode != 200) {
        throw Exception('Server returned ${headResp.statusCode}');
      }

      final contentLength =
          int.tryParse(headResp.headers['content-length'] ?? '') ?? 0;

      // ── 2. Stream download to temp file ───────────────────────────────
      setState(() => _statusMsg = 'Downloading database…');

      final dir = await getApplicationDocumentsDirectory();
      final tmpPath = p.join(dir.path, 'nutrition_tmp.db');
      final tmpFile = File(tmpPath);
      final sink = tmpFile.openWrite();

      final request = http.Request('GET', Uri.parse(_kDbUrl));
      final response = await request.send().timeout(
        const Duration(seconds: 60),
      );

      if (response.statusCode != 200) {
        throw Exception('Download failed: ${response.statusCode}');
      }

      int received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0 && mounted) {
          setState(() {
            _progress = received / contentLength;
            _statusMsg =
                'Downloading… ${_fmtBytes(received)} / ${_fmtBytes(contentLength)}';
          });
        }
      }
      await sink.flush();
      await sink.close();

      // ── 3. Validate — check SQLite magic bytes ────────────────────────
      setState(() => _statusMsg = 'Validating file…');
      final magic = await _readMagicBytes(tmpFile);
      if (!magic) {
        await tmpFile.delete();
        throw Exception('Downloaded file is not a valid SQLite database.');
      }

      // ── 4. Replace existing DB ────────────────────────────────────────
      setState(() => _statusMsg = 'Installing database…');
      final finalPath = p.join(dir.path, 'nutrition.db');
      final finalFile = File(finalPath);

      // Backup existing DB just in case
      if (await finalFile.exists()) {
        await finalFile.copy(p.join(dir.path, 'nutrition_backup.db'));
      }

      await tmpFile.copy(finalPath);
      await tmpFile.delete();

      // ── 5. Reopen DB connection ───────────────────────────────────────
      setState(() => _statusMsg = 'Reconnecting…');
      await DatabaseHelper.instance.reopenProductDb();

      // ── 6. Done ───────────────────────────────────────────────────────
      final now = DateTime.now();
      if (mounted) {
        setState(() {
          _state = _SyncState.success;
          _progress = 1.0;
          _statusMsg = 'Database updated successfully';
          _lastSync = now;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _SyncState.error;
          _error = e.toString();
          _statusMsg = 'Sync failed';
        });
      }
    }
  }

  Future<bool> _readMagicBytes(File file) async {
    try {
      final bytes = await file.openRead(0, 16).first;
      // SQLite magic: first 16 bytes start with "SQLite format 3\000"
      const magic = [
        83,
        81,
        76,
        105,
        116,
        101,
        32,
        102,
        111,
        114,
        109,
        97,
        116,
        32,
        51,
        0,
      ];
      if (bytes.length < 16) return false;
      for (int i = 0; i < 16; i++) {
        if (bytes[i] != magic[i]) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  String _fmtBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1048576).toStringAsFixed(1)}MB';
  }

  String _fmtDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hm =
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $hm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Database Sync',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Info Card ─────────────────────────────────────────────
            _InfoCard(lastSync: _lastSync, fmtDate: _fmtDate, syncUrl: _kDbUrl),
            const SizedBox(height: 20),

            // ── Status Card ───────────────────────────────────────────
            _StatusCard(
              state: _state,
              progress: _progress,
              statusMsg: _statusMsg,
              error: _error,
            ),
            const SizedBox(height: 24),

            // ── Sync Button ───────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _state == _SyncState.downloading ? null : _startSync,
              icon: _state == _SyncState.downloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(
                _state == _SyncState.downloading
                    ? 'Syncing…'
                    : _state == _SyncState.success
                    ? 'Sync Again'
                    : 'Sync Now',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Warning ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD54F)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFF57F17),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Before syncing',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF57F17),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'The existing nutrition.db will be replaced. '
                          'A backup is saved as nutrition_backup.db '
                          'in the same directory. '
                          'Your scan history and profile are not affected.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF795548),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Sync State ───────────────────────────────────────────────────────────────

enum _SyncState { idle, downloading, success, error }

// ─── Info Card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final DateTime? lastSync;
  final String Function(DateTime) fmtDate;
  final String syncUrl;

  const _InfoCard({
    required this.lastSync,
    required this.fmtDate,
    required this.syncUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cloud_sync_rounded,
                color: Color(0xFF00BCD4),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Sync Info',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _InfoRow(
            icon: Icons.link_rounded,
            label: 'Source URL',
            value: syncUrl,
            mono: true,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.access_time_rounded,
            label: 'Last synced',
            value: lastSync != null ? fmtDate(lastSync!) : 'Never',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.storage_rounded,
            label: 'Target file',
            value: 'ApplicationDocuments/nutrition.db',
            mono: true,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF888888)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF333333),
                  fontFamily: mono ? 'monospace' : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Status Card ─────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final _SyncState state;
  final double progress;
  final String statusMsg;
  final String? error;

  const _StatusCard({
    required this.state,
    required this.progress,
    required this.statusMsg,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon, bg) = switch (state) {
      _SyncState.idle => (
        const Color(0xFF888888),
        Icons.cloud_outlined,
        const Color(0xFFF5F5F5),
      ),
      _SyncState.downloading => (
        const Color(0xFF00BCD4),
        Icons.downloading_rounded,
        const Color(0xFFE0F7FA),
      ),
      _SyncState.success => (
        const Color(0xFF2E7D32),
        Icons.check_circle_rounded,
        const Color(0xFFE8F5E9),
      ),
      _SyncState.error => (
        const Color(0xFFC62828),
        Icons.error_rounded,
        const Color(0xFFFFEBEE),
      ),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusMsg,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              if (state == _SyncState.success)
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
            ],
          ),

          // Progress bar — shown during download
          if (state == _SyncState.downloading) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                minHeight: 6,
                backgroundColor: color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],

          // Error detail
          if (state == _SyncState.error && error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                error!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFC62828),
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
