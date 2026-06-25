class Product {
  final int productId;
  final int? calories;
  final int? totalFat;
  final int? saturatedFat;
  final int? transFat;
  final int? cholesterol;
  final int? sodium;
  final int? potassium;
  final int? totalCarbs;
  final int? protein;
  final int? sugars;
  final int? fiber;

  const Product({
    required this.productId,
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
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      productId: map['product_id'] as int,
      calories: map['Calories'] as int?,
      totalFat: map['Total Fat'] as int?,
      saturatedFat: map['Saturated Fat'] as int?,
      transFat: map['Trans Fat'] as int?,
      cholesterol: map['Cholesterol'] as int?,
      sodium: map['Sodium'] as int?,
      potassium: map['Potassium'] as int?,
      totalCarbs: map['Total Carbs'] as int?,
      protein: map['Protein'] as int?,
      sugars: map['Sugars'] as int?,
      fiber: map['Fiber'] as int?,
    );
  }

  /// Returns nutrient value or 0 if null — used for calculations.
  int safeVal(int? v) => v ?? 0;

  /// All chart-eligible nutrients (excludes Calories).
  Map<String, int> get chartNutrients {
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

  /// Full nutrition table rows including Calories — null shown as "—" in UI.
  List<MapEntry<String, int?>> get tableRows => [
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
  ];
}
