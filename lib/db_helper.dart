import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'models/product.dart';

class DatabaseHelper {
  // Singleton
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;

  Database? _db;

  /// Opens DB at ApplicationDocumentsDirectory/nutrition.db.
  /// Never creates or migrates — file must already exist.
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _openDB();
    return _db!;
  }

  Future<Database> _openDB() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'nutrition.db');

    return await openDatabase(
      path,
      readOnly: true, // existing data only — no accidental writes
      // No onCreate / onUpgrade — app does NOT own this DB's schema
    );
  }

  /// Query product by barcode (product_id).
  /// Returns [Product] if found, null otherwise.
  Future<Product?> queryProduct(int barcode) async {
    final db = await database;
    final rows = await db.query(
      'products',
      where: 'product_id = ?',
      whereArgs: [barcode],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  /// Close DB — call on app dispose if needed.
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
