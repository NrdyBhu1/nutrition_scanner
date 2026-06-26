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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE "products" (
            "product_id"     INTEGER NOT NULL UNIQUE,
            "Calories"       INTEGER,
            "Total Fat"      INTEGER,
            "Saturated Fat"  INTEGER,
            "Trans Fat"      INTEGER,
            "Cholesterol"    INTEGER,
            "Sodium"         INTEGER,
            "Potassium"      INTEGER,
            "Total Carbs"    INTEGER,
            "Protein"        INTEGER,
            "Sugars"         INTEGER,
            "Fiber"          INTEGER
          )
        ''');

        await db.execute('''
          INSERT INTO products
            (product_id, Calories, "Total Fat", "Saturated Fat", "Trans Fat",
             Cholesterol, Sodium, Potassium, "Total Carbs", Protein, Sugars, Fiber)
          VALUES
            (8901491361026, 558, 34, 16, 0, 0, 0, 0, 55, 6, 1, 0);
        ''');
      },
    );
  }

  /// Query product by barcode (product_id).
  /// (8901491361026, 558, 34.6, 16, 0.1, 0, 0.892, 0, 55.2, 6.4, 1.0, 0);
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
