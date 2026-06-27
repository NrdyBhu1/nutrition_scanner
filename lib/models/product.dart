class Product {
  final int productId;
  final String productName;
  final double? calories;
  final double? totalFat;
  final double? saturatedFat;
  final double? transFat;
  final double? cholesterol;
  final double? sodium;
  final double? potassium;
  final double? totalCarbs;
  final double? protein;
  final double? sugars;
  final double? fiber;
  final List<String> allergens;

  const Product({
    required this.productId,
    required this.productName,
    this.calories,
    this.totalFat,
    this.saturatedFat,
    this.transFat,
    this.cholesterol,
    this.sodium,
    this.potassium,
    this.totalCarbs,
    this.protein,
    this.sugars,
    this.fiber,
    this.allergens = const [],
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      productId: map['product_id'] as int,
      productName: map['Name'] as String,
      calories: (map['Calories'] as num?)?.toDouble(),
      totalFat: (map['Total Fat'] as num?)?.toDouble(),
      saturatedFat: (map['Saturated Fat'] as num?)?.toDouble(),
      transFat: (map['Trans Fat'] as num?)?.toDouble(),
      cholesterol: (map['Cholesterol'] as num?)?.toDouble(),
      sodium: (map['Sodium'] as num?)?.toDouble(),
      potassium: (map['Potassium'] as num?)?.toDouble(),
      totalCarbs: (map['Total Carbs'] as num?)?.toDouble(),
      protein: (map['Protein'] as num?)?.toDouble(),
      sugars: (map['Sugars'] as num?)?.toDouble(),
      fiber: (map['Fiber'] as num?)?.toDouble(),
      allergens: _parseAllergens(map['Allergens'] as String?),
    );
  }

  static List<String> _parseAllergens(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw.split(',').map((e) => e.trim().toLowerCase()).toList();
  }

  /// Returns nutrient value or 0 if null — used for calculations.
  // int safeVal(int? v) => v ?? 0;
  double safeVal(double? v) => v ?? 0;

  /// All chart-eligible nutrients (excludes Calories).
  Map<String, double> get chartNutrients {
    final raw = {
      'Total Fat': totalFat,
      'Total Carbs': totalCarbs,
      'Protein': protein,
      'Sugars': sugars,
      'Fiber': fiber,
      'Cholesterol': cholesterol,
      'Sodium': sodium,
      'Potassium': potassium,
      'Saturated Fat': saturatedFat,
      'Trans Fat': transFat,
    };
    // Only include non-null, non-zero entries in pie chart
    return Map.fromEntries(
      raw.entries
          .where((e) => e.value != null && e.value! > 0)
          .map((e) => MapEntry(e.key, e.value!)),
    );
  }

  /// True if product contains any of the user's known allergens.
  bool hasAllergenMatch(List<String> userAllergens) {
    if (allergens.isEmpty || userAllergens.isEmpty) return false;
    return allergens.any(
      (a) => userAllergens.any((u) => a.contains(u) || u.contains(a)),
    );
  }

  /// Allergens that match user's known list.
  List<String> matchedAllergens(List<String> userAllergens) {
    if (allergens.isEmpty || userAllergens.isEmpty) return [];
    return allergens
        .where((a) => userAllergens.any((u) => a.contains(u) || u.contains(a)))
        .toList();
  }

  /// Full nutrition table rows including Calories — null shown as "—" in UI.
  List<MapEntry<String, double?>> get tableRows => [
    MapEntry('Calories', calories),
    MapEntry('Total Fat', totalFat),
    MapEntry('Saturated Fat', saturatedFat),
    MapEntry('Trans Fat', transFat),
    MapEntry('Cholesterol', cholesterol),
    MapEntry('Sodium', sodium),
    MapEntry('Potassium', potassium),
    MapEntry('Total Carbs', totalCarbs),
    MapEntry('Protein', protein),
    MapEntry('Sugars', sugars),
    MapEntry('Fiber', fiber),
    // MapEntry('Allergens', allergens),
  ];
}
