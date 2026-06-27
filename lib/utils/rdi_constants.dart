import '../models/user_profile.dart';

/// Reference Daily Intake values (adult, 2000 kcal baseline).
/// All values in same unit as DB columns (kcal / g / mg).
class RdiConstants {
  // Base RDI — normal diet, 2000 kcal reference
  static const int baseCalories = 2000;
  static const int baseTotalFat = 78; // g
  static const int baseSaturatedFat = 20; // g
  static const int baseTransFat = 2; // g  (WHO: <1% energy, ~2g cap)
  static const int baseCholesterol = 300; // mg
  static const int baseSodium = 2300; // mg
  static const int basePotassium = 4700; // mg
  static const int baseTotalCarbs = 275; // g
  static const int baseProtein = 50; // g
  static const int baseSugars = 50; // g  (WHO: <10% energy)
  static const int baseFiber = 28; // g

  /// Returns RDI map adjusted for dietary mode.
  /// Keys match DB column names exactly.
  static Map<String, int> forMode(DietaryMode mode) {
    switch (mode) {
      case DietaryMode.keto:
        return {
          'Calories': baseCalories,
          'Total Fat': 165, // ~70% of 2000 kcal
          'Saturated Fat': baseSaturatedFat,
          'Trans Fat': baseTransFat,
          'Cholesterol': baseCholesterol,
          'Sodium': baseSodium,
          'Potassium': basePotassium,
          'Total Carbs': 25, // strict keto cap
          'Protein': 125, // ~25% of 2000 kcal
          'Sugars': 10, // very low
          'Fiber': baseFiber,
        };

      case DietaryMode.lowSodium:
        return {
          'Calories': baseCalories,
          'Total Fat': baseTotalFat,
          'Saturated Fat': baseSaturatedFat,
          'Trans Fat': baseTransFat,
          'Cholesterol': baseCholesterol,
          'Sodium': 1500, // stricter sodium cap
          'Potassium': basePotassium,
          'Total Carbs': baseTotalCarbs,
          'Protein': baseProtein,
          'Sugars': baseSugars,
          'Fiber': baseFiber,
        };

      case DietaryMode.highProtein:
        return {
          'Calories': baseCalories,
          'Total Fat': 65, // slightly lower fat
          'Saturated Fat': baseSaturatedFat,
          'Trans Fat': baseTransFat,
          'Cholesterol': baseCholesterol,
          'Sodium': baseSodium,
          'Potassium': basePotassium,
          'Total Carbs': 200, // moderate carbs
          'Protein': 150, // ~30% of 2000 kcal
          'Sugars': baseSugars,
          'Fiber': baseFiber,
        };

      case DietaryMode.normal:
      default:
        return {
          'Calories': baseCalories,
          'Total Fat': baseTotalFat,
          'Saturated Fat': baseSaturatedFat,
          'Trans Fat': baseTransFat,
          'Cholesterol': baseCholesterol,
          'Sodium': baseSodium,
          'Potassium': basePotassium,
          'Total Carbs': baseTotalCarbs,
          'Protein': baseProtein,
          'Sugars': baseSugars,
          'Fiber': baseFiber,
        };
    }
  }

  /// TDEE — Total Daily Energy Expenditure in kcal.
  /// Mifflin-St Jeor BMR × activity multiplier.
  /// [isMale] defaults to true for conservative estimate when unknown.
  static int tdee({
    required double weightKg,
    required int age,
    required ActivityLevel activityLevel,
    bool isMale = true,
    double heightCm = 170, // fallback if not collected
  }) {
    // Mifflin-St Jeor BMR
    final bmr = isMale
        ? (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5
        : (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    return (bmr * activityLevel.multiplier).round();
  }

  /// Calories RDI scaled to user's TDEE.
  /// Other macros scale proportionally.
  static Map<String, int> scaledForUser(UserProfile profile) {
    final base = forMode(profile.dietaryMode);
    final userCal = tdee(
      weightKg: profile.weightKg,
      age: profile.age,
      activityLevel: profile.activityLevel,
    );
    final scale = userCal / baseCalories;

    return base.map((key, value) {
      // Scale macros proportionally; leave thresholds (TransFat, Cholesterol) fixed
      final fixed = {'Trans Fat', 'Cholesterol'};
      return MapEntry(
        key,
        fixed.contains(key) ? value : (value * scale).round(),
      );
    });
  }

  /// Quick accessors used by alert checker.
  static int sodiumRdi(UserProfile p) =>
      scaledForUser(p)['Sodium'] ?? baseSodium;
  static int sugarRdi(UserProfile p) =>
      scaledForUser(p)['Sugars'] ?? baseSugars;
  static int fatRdi(UserProfile p) =>
      scaledForUser(p)['Total Fat'] ?? baseTotalFat;
}
