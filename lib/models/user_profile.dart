class UserProfile {
  final int id;
  final String name;
  final int age;
  final double weightKg;
  final ActivityLevel activityLevel;
  final DietaryMode dietaryMode;
  final int alertSodiumPct; // % of RDI before alert fires
  final int alertSugarPct;
  final int alertFatPct;
  final List<String> knownAllergens; // e.g. ['gluten','nuts','dairy']

  const UserProfile({
    this.id = 1,
    this.name = '',
    this.age = 25,
    this.weightKg = 70.0,
    this.activityLevel = ActivityLevel.moderate,
    this.dietaryMode = DietaryMode.normal,
    this.alertSodiumPct = 50,
    this.alertSugarPct = 50,
    this.alertFatPct = 50,
    this.knownAllergens = const [],
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final allergenRaw = map['known_allergens'] as String? ?? '';
    return UserProfile(
      id: map['id'] as int,
      name: map['name'] as String? ?? '',
      age: map['age'] as int? ?? 25,
      weightKg: (map['weight_kg'] as num?)?.toDouble() ?? 70.0,
      activityLevel: ActivityLevel.fromString(
        map['activity_level'] as String? ?? 'moderate',
      ),
      dietaryMode: DietaryMode.fromString(
        map['dietary_mode'] as String? ?? 'normal',
      ),
      alertSodiumPct: map['alert_sodium'] as int? ?? 50,
      alertSugarPct: map['alert_sugar'] as int? ?? 50,
      alertFatPct: map['alert_fat'] as int? ?? 50,
      knownAllergens: allergenRaw.isEmpty
          ? []
          : allergenRaw.split(',').map((e) => e.trim()).toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'age': age,
    'weight_kg': weightKg,
    'activity_level': activityLevel.value,
    'dietary_mode': dietaryMode.value,
    'alert_sodium': alertSodiumPct,
    'alert_sugar': alertSugarPct,
    'alert_fat': alertFatPct,
    'known_allergens': knownAllergens.join(','),
  };

  UserProfile copyWith({
    String? name,
    int? age,
    double? weightKg,
    ActivityLevel? activityLevel,
    DietaryMode? dietaryMode,
    int? alertSodiumPct,
    int? alertSugarPct,
    int? alertFatPct,
    List<String>? knownAllergens,
  }) {
    return UserProfile(
      id: this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      weightKg: weightKg ?? this.weightKg,
      activityLevel: activityLevel ?? this.activityLevel,
      dietaryMode: dietaryMode ?? this.dietaryMode,
      alertSodiumPct: alertSodiumPct ?? this.alertSodiumPct,
      alertSugarPct: alertSugarPct ?? this.alertSugarPct,
      alertFatPct: alertFatPct ?? this.alertFatPct,
      knownAllergens: knownAllergens ?? this.knownAllergens,
    );
  }
}

// ─── Enums ────────────────────────────────────────────────────────────────────

enum ActivityLevel {
  sedentary('sedentary', 'Sedentary', 1.2),
  light('light', 'Light', 1.375),
  moderate('moderate', 'Moderate', 1.55),
  active('active', 'Active', 1.725);

  final String value;
  final String label;
  final double multiplier; // TDEE multiplier

  const ActivityLevel(this.value, this.label, this.multiplier);

  static ActivityLevel fromString(String v) => ActivityLevel.values.firstWhere(
    (e) => e.value == v,
    orElse: () => ActivityLevel.moderate,
  );
}

enum DietaryMode {
  normal('normal', 'Normal'),
  keto('keto', 'Keto'),
  lowSodium('low_sodium', 'Low Sodium'),
  highProtein('high_protein', 'High Protein');

  final String value;
  final String label;

  const DietaryMode(this.value, this.label);

  static DietaryMode fromString(String v) => DietaryMode.values.firstWhere(
    (e) => e.value == v,
    orElse: () => DietaryMode.normal,
  );
}
