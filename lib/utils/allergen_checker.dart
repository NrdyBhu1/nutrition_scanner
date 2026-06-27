import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/user_profile.dart';

/// Result of an allergen check on a single product.
class AllergenResult {
  final bool hasMatch;
  final List<String> matched; // allergens found in product
  final List<String> allFlags; // all allergens product contains

  const AllergenResult({
    required this.hasMatch,
    required this.matched,
    required this.allFlags,
  });

  String get matchSummary {
    if (!hasMatch) return 'No allergen matches';
    final joined = matched.map(_capitalize).join(', ');
    return 'Contains: $joined';
  }

  String get fullFlagSummary {
    if (allFlags.isEmpty) return 'No allergens listed';
    return allFlags.map(_capitalize).join(' • ');
  }
}

/// Known major allergens with display metadata.
/// Extend this list to add more allergens.
class AllergenMeta {
  final String key; // lowercase, matches DB value
  final String label; // display name
  final IconData icon;
  final Color color;

  const AllergenMeta({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class AllergenChecker {
  // Canonical allergen registry — keys must match what's stored in DB
  static const List<AllergenMeta> registry = [
    AllergenMeta(
      key: 'gluten',
      label: 'Gluten',
      icon: Icons.grain_rounded,
      color: Color(0xFFD4A017),
    ),
    AllergenMeta(
      key: 'wheat',
      label: 'Wheat',
      icon: Icons.grass_rounded,
      color: Color(0xFFB8860B),
    ),
    AllergenMeta(
      key: 'nuts',
      label: 'Nuts',
      icon: Icons.eco_rounded,
      color: Color(0xFF8B4513),
    ),
    AllergenMeta(
      key: 'peanuts',
      label: 'Peanuts',
      icon: Icons.circle_rounded,
      color: Color(0xFFC8860A),
    ),
    AllergenMeta(
      key: 'dairy',
      label: 'Dairy',
      icon: Icons.water_drop_rounded,
      color: Color(0xFF4FC3F7),
    ),
    AllergenMeta(
      key: 'milk',
      label: 'Milk',
      icon: Icons.water_drop_outlined,
      color: Color(0xFF29B6F6),
    ),
    AllergenMeta(
      key: 'eggs',
      label: 'Eggs',
      icon: Icons.egg_rounded,
      color: Color(0xFFFDD835),
    ),
    AllergenMeta(
      key: 'soy',
      label: 'Soy',
      icon: Icons.spa_rounded,
      color: Color(0xFF66BB6A),
    ),
    AllergenMeta(
      key: 'fish',
      label: 'Fish',
      icon: Icons.set_meal_rounded,
      color: Color(0xFF42A5F5),
    ),
    AllergenMeta(
      key: 'shellfish',
      label: 'Shellfish',
      icon: Icons.water_rounded,
      color: Color(0xFFEF5350),
    ),
    AllergenMeta(
      key: 'sesame',
      label: 'Sesame',
      icon: Icons.blur_on_rounded,
      color: Color(0xFFFFB300),
    ),
    AllergenMeta(
      key: 'mustard',
      label: 'Mustard',
      icon: Icons.circle_outlined,
      color: Color(0xFFFFEE58),
    ),
    AllergenMeta(
      key: 'sulphites',
      label: 'Sulphites',
      icon: Icons.science_rounded,
      color: Color(0xFFAB47BC),
    ),
    AllergenMeta(
      key: 'celery',
      label: 'Celery',
      icon: Icons.yard_rounded,
      color: Color(0xFF26A69A),
    ),
  ];

  /// Run allergen check for a product against a user's known allergens.
  static AllergenResult check(Product product, UserProfile profile) {
    final matched = product.matchedAllergens(profile.knownAllergens);
    return AllergenResult(
      hasMatch: matched.isNotEmpty,
      matched: matched,
      allFlags: product.allergens,
    );
  }

  /// Metadata for a given allergen key. Returns null if not in registry.
  static AllergenMeta? meta(String key) {
    final k = key.toLowerCase().trim();
    try {
      return registry.firstWhere((m) => m.key == k || k.contains(m.key));
    } catch (_) {
      return null;
    }
  }

  /// Color for a given allergen — falls back to grey if not in registry.
  static Color colorFor(String key) =>
      meta(key)?.color ?? const Color(0xFF9E9E9E);

  /// Icon for a given allergen — falls back to warning icon.
  static IconData iconFor(String key) =>
      meta(key)?.icon ?? Icons.warning_amber_rounded;

  /// Label for a given allergen — capitalizes if not in registry.
  static String labelFor(String key) => meta(key)?.label ?? _capitalize(key);

  /// All allergen keys available for user profile selection.
  static List<String> get allKeys => registry.map((m) => m.key).toList();
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
