class DailyIntake {
  final String date; // YYYY-MM-DD
  final List<int> productIds; // all products logged this day

  // Aggregated nutrient totals
  final double totalCalories;
  final double totalFat;
  final double totalSaturatedFat;
  final double totalTransFat;
  final double totalCholesterol;
  final double totalSodium;
  final double totalPotassium;
  final double totalCarbs;
  final double totalProtein;
  final double totalSugars;
  final double totalFiber;

  const DailyIntake({
    required this.date,
    required this.productIds,
    this.totalCalories = 0.0,
    this.totalFat = 0.0,
    this.totalSaturatedFat = 0.0,
    this.totalTransFat = 0.0,
    this.totalCholesterol = 0.0,
    this.totalSodium = 0.0,
    this.totalPotassium = 0.0,
    this.totalCarbs = 0.0,
    this.totalProtein = 0.0,
    this.totalSugars = 0.0,
    this.totalFiber = 0.0,
  });

  /// Build DailyIntake by summing nutrients across a list of products.
  factory DailyIntake.fromProducts({
    required String date,
    required List<int> productIds,
    required List<Map<String, dynamic>> productRows,
  }) {
    double cal = 0, fat = 0, satFat = 0, transFat = 0, chol = 0;
    double sod = 0, pot = 0, carbs = 0, prot = 0, sug = 0, fib = 0;

    for (final row in productRows) {
      cal += (row['Calories'] as num? ?? 0).toDouble();
      fat += (row['Total Fat'] as num? ?? 0).toDouble();
      satFat += (row['Saturated Fat'] as num? ?? 0).toDouble();
      transFat += (row['Trans Fat'] as num? ?? 0).toDouble();
      chol += (row['Cholesterol'] as num? ?? 0).toDouble();
      sod += (row['Sodium'] as num? ?? 0).toDouble();
      pot += (row['Potassium'] as num? ?? 0).toDouble();
      carbs += (row['Total Carbs'] as num? ?? 0).toDouble();
      prot += (row['Protein'] as num? ?? 0).toDouble();
      sug += (row['Sugars'] as num? ?? 0).toDouble();
      fib += (row['Fiber'] as num? ?? 0).toDouble();
    }

    return DailyIntake(
      date: date,
      productIds: productIds,
      totalCalories: cal,
      totalFat: fat,
      totalSaturatedFat: satFat,
      totalTransFat: transFat,
      totalCholesterol: chol,
      totalSodium: sod,
      totalPotassium: pot,
      totalCarbs: carbs,
      totalProtein: prot,
      totalSugars: sug,
      totalFiber: fib,
    );
  }

  /// Today's date string.
  static String get todayKey {
    final n = DateTime.now();
    return '${n.year}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  /// Nutrient rows for display — same shape as Product.tableRows.
  List<MapEntry<String, double>> get tableRows => [
    MapEntry('Calories', totalCalories),
    MapEntry('Total Fat', totalFat),
    MapEntry('Saturated Fat', totalSaturatedFat),
    MapEntry('Trans Fat', totalTransFat),
    MapEntry('Cholesterol', totalCholesterol),
    MapEntry('Sodium', totalSodium),
    MapEntry('Potassium', totalPotassium),
    MapEntry('Total Carbs', totalCarbs),
    MapEntry('Protein', totalProtein),
    MapEntry('Sugars', totalSugars),
    MapEntry('Fiber', totalFiber),
  ];

  /// Percentage of RDI for a nutrient given its RDI value.
  double pctOfRdi(double total, int rdi) =>
      rdi > 0 ? (total / rdi * 100).clamp(0, 999) : 0;

  /// True if any tracked nutrient exceeds its alert threshold.
  bool exceedsAlert({
    required int sodiumRdi,
    required int sugarRdi,
    required int fatRdi,
    required int alertSodiumPct,
    required int alertSugarPct,
    required int alertFatPct,
  }) {
    return pctOfRdi(totalSodium, sodiumRdi) > alertSodiumPct.toDouble() ||
        pctOfRdi(totalSugars, sugarRdi) > alertSugarPct.toDouble() ||
        pctOfRdi(totalFat, fatRdi) > alertFatPct.toDouble();
  }
}
