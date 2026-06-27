import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'models/product.dart';
import 'models/scan_entry.dart';
import 'models/user_profile.dart';
import 'models/daily_intake.dart';

class DatabaseHelper {
  // Singleton
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;

  // Two separate DB connections:
  // _productDb  → nutrition.db   (existing, read-only products table)
  // _appDb      → app_data.db    (app-owned: history, intake, profile)
  Database? _productDb;
  Database? _appDb;

  // ─── Product DB (read-only, pre-existing) ──────────────────────────────────

  Future<Database> get productDatabase async {
    if (_productDb != null && _productDb!.isOpen) return _productDb!;
    _productDb = await _openProductDb();
    return _productDb!;
  }

  Future<Database> _openProductDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'nutrition.db');
    return await openDatabase(path, readOnly: true);
  }

  /// Re-open product DB after sync replaces the file.
  Future<void> reopenProductDb() async {
    if (_productDb != null && _productDb!.isOpen) await _productDb!.close();
    _productDb = null;
    await productDatabase;
  }

  // ─── App DB (app-owned, writable) ─────────────────────────────────────────

  Future<Database> get appDatabase async {
    if (_appDb != null && _appDb!.isOpen) return _appDb!;
    _appDb = await _openAppDb();
    return _appDb!;
  }

  Future<Database> _openAppDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'app_data.db');
    return await openDatabase(path, version: 1, onCreate: _createAppTables);
  }

  Future<void> _createAppTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scan_history (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id  INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        scanned_at  TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_intake (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        date        TEXT    NOT NULL,
        product_id  INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id              INTEGER PRIMARY KEY,
        name            TEXT,
        age             INTEGER,
        weight_kg       REAL,
        activity_level  TEXT,
        dietary_mode    TEXT,
        alert_sodium    INTEGER,
        alert_sugar     INTEGER,
        alert_fat       INTEGER,
        known_allergens TEXT
      )
    ''');
  }

  // ─── Product queries ───────────────────────────────────────────────────────

  Future<Product?> queryProduct(int barcode) async {
    final db = await productDatabase;
    final rows = await db.query(
      'products',
      where: 'product_id = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<List<Product>> queryProductsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await productDatabase;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.query(
      'products',
      where: 'product_id IN ($placeholders)',
      whereArgs: ids,
    );
    return rows.map(Product.fromMap).toList();
  }

  // ─── Scan history queries ──────────────────────────────────────────────────

  Future<void> insertScanEntry(int productId, String productName) async {
    final db = await appDatabase;
    await db.insert('scan_history', {
      'product_id': productId,
      'product_name': productName,
      'scanned_at': DateTime.now().toIso8601String(),
    });
  }

  /// Returns latest [limit] scan entries, most recent first.
  Future<List<ScanEntry>> fetchScanHistory({int limit = 50}) async {
    final db = await appDatabase;
    final rows = await db.query(
      'scan_history',
      orderBy: 'scanned_at DESC',
      limit: limit,
    );
    return rows.map(ScanEntry.fromMap).toList();
  }

  Future<void> deleteScanEntry(int id) async {
    final db = await appDatabase;
    await db.delete('scan_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearScanHistory() async {
    final db = await appDatabase;
    await db.delete('scan_history');
  }

  // ─── Daily intake queries ──────────────────────────────────────────────────

  Future<void> logToDaily(int productId) async {
    final db = await appDatabase;
    await db.insert('daily_intake', {
      'date': DailyIntake.todayKey,
      'product_id': productId,
    });
  }

  Future<void> removeFromDaily(int productId, String date) async {
    final db = await appDatabase;
    final rows = await db.query(
      'daily_intake',
      where: 'date = ? AND product_id = ?',
      whereArgs: [date, productId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      await db.delete(
        'daily_intake',
        where: 'id = ?',
        whereArgs: [rows.first['id']],
      );
    }
  }

  /// Fetch aggregated DailyIntake for a given date.
  Future<DailyIntake> fetchDailyIntake(String date) async {
    final appDb = await appDatabase;

    final logRows = await appDb.query(
      'daily_intake',
      columns: ['product_id'],
      where: 'date = ?',
      whereArgs: [date],
    );

    final ids = logRows.map((r) => r['product_id'] as int).toList();
    if (ids.isEmpty) {
      return DailyIntake(date: date, productIds: []);
    }

    final productDb = await productDatabase;
    final placeholders = List.filled(ids.length, '?').join(',');
    final productRows = await productDb.query(
      'products',
      where: 'product_id IN ($placeholders)',
      whereArgs: ids,
    );

    return DailyIntake.fromProducts(
      date: date,
      productIds: ids,
      productRows: productRows,
    );
  }

  /// Last 7 days of intake for trend display.
  Future<List<DailyIntake>> fetchWeeklyIntake() async {
    final results = <DailyIntake>[];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key =
          '${day.year}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
      results.add(await fetchDailyIntake(key));
    }
    return results;
  }

  // ─── User profile queries ──────────────────────────────────────────────────

  Future<UserProfile> fetchProfile() async {
    final db = await appDatabase;
    final rows = await db.query('user_profile', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return const UserProfile();
    return UserProfile.fromMap(rows.first);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final db = await appDatabase;
    await db.insert(
      'user_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> close() async {
    if (_productDb != null && _productDb!.isOpen) await _productDb!.close();
    if (_appDb != null && _appDb!.isOpen) await _appDb!.close();
    _productDb = null;
    _appDb = null;
  }
}
