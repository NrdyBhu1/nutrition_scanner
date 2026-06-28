import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenFoodFactsResult {
  final bool found;
  final Map<String, dynamic>? data; // parsed product row ready for DB insert

  const OpenFoodFactsResult({required this.found, this.data});
}

class OpenFoodFactsService {
  static const String _base = 'https://world.openfoodfacts.org/api/v2/product';

  static const Duration _timeout = Duration(seconds: 10);

  /// Fetch product by barcode. Returns parsed DB-ready map or null if not found.
  static Future<OpenFoodFactsResult> fetch(int barcode) async {
    try {
      final uri = Uri.parse('$_base/$barcode.json');
      final resp = await http
          .get(uri, headers: {'User-Agent': 'NutritionScannerApp/1.0'})
          .timeout(_timeout);

      if (resp.statusCode != 200) {
        return const OpenFoodFactsResult(found: false);
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;

      // status 0 = not found, 1 = found
      if ((json['status'] as int? ?? 0) == 0) {
        return const OpenFoodFactsResult(found: false);
      }

      final product = json['product'] as Map<String, dynamic>? ?? {};
      final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};

      // Parse allergens — strip "en:" prefix, join as comma string
      final allergenTags = (product['allergens_tags'] as List<dynamic>? ?? [])
          .map((e) => (e as String).replaceFirst('en:', '').toLowerCase())
          .join(',');

      final name =
          (product['product_name_en'] as String?)?.trim().isNotEmpty == true
          ? product['product_name_en'] as String
          : (product['product_name'] as String?)?.trim().isNotEmpty == true
          ? product['product_name'] as String
          : null;

      // Build DB-ready row
      final row = <String, dynamic>{
        'product_id': barcode,
        'Name': name,
        'weight_g': _parseWeight(
          product['product_quantity'] ?? product['quantity'],
        ),
        'Calories': _num(nutriments['energy-kcal_100g']),
        'Total Fat': _num(nutriments['fat_100g']),
        'Saturated Fat': _num(nutriments['saturated-fat_100g']),
        'Trans Fat': _num(nutriments['trans-fat_100g']),
        'Cholesterol': _numMgFromG(nutriments['cholesterol_100g']),
        'Sodium': _num(nutriments['sodium_100g']),
        'Potassium': _num(nutriments['potassium_100g']),
        'Total Carbs': _num(nutriments['carbohydrates_100g']),
        'Protein': _num(nutriments['proteins_100g']),
        'Sugars': _num(nutriments['sugars_100g']),
        'Fiber': _num(nutriments['fiber_100g']),
        'Allergens': allergenTags.isEmpty ? null : allergenTags,
      };

      return OpenFoodFactsResult(found: true, data: row);
    } catch (_) {
      return const OpenFoodFactsResult(found: false);
    }
  }

  // Safely cast num → double, null if absent
  static double? _num(dynamic v) {
    if (v == null) return null;
    return (v as num).toDouble();
  }

  // Cholesterol in OFF is stored in kg/100g, need mg
  // Actually OFF stores cholesterol_100g in g, convert to mg
  static double? _numMgFromG(dynamic v) {
    if (v == null) return null;
    return (v as num).toDouble() * 1000;
  }

  /// Parse weight from product_quantity field e.g. "400", "400 g", "400g", "1 kg"
  static double? _parseWeight(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim().toLowerCase();

    // Extract first number from string
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(str);
    if (match == null) return null;

    final value = double.tryParse(match.group(1)!);
    if (value == null) return null;

    // Convert kg to g
    if (str.contains('kg')) return value * 1000;
    return value;
  }
}
