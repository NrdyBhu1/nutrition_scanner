import 'package:flutter/material.dart';
import '../models/product.dart';

enum ConsumptionRating { daily, occasional, limit, rarely }

class ConsumptionResult {
  final ConsumptionRating rating;
  final String label;
  final String description;
  final String emoji;
  final Color color;
  final Color bgColor;
  final List<String> reasons; // why this rating was given

  const ConsumptionResult({
    required this.rating,
    required this.label,
    required this.description,
    required this.emoji,
    required this.color,
    required this.bgColor,
    required this.reasons,
  });
}

class ConsumptionRater {
  /// Thresholds per 100g
  // Trans fat
  static const double _transFatRarely = 0.5; // >0.5g/100g → rarely
  static const double _transFatLimit = 0.1; // >0.1g/100g → limit

  // Sodium (mg per 100g)
  static const double _sodiumRarely = 800; // >800mg → rarely
  static const double _sodiumLimit = 400; // >400mg → limit
  static const double _sodiumOccasional = 200; // >200mg → occasional

  // Sugars (g per 100g)
  static const double _sugarsRarely = 30.0; // >30g → rarely
  static const double _sugarsLimit = 20.0; // >20g → limit
  static const double _sugarsOccasional = 10.0; // >10g → occasional

  // Saturated fat (g per 100g)
  static const double _satFatRarely = 15.0; // >15g → rarely
  static const double _satFatLimit = 8.0; // >8g → limit
  static const double _satFatOccasional = 4.0; // >4g → occasional

  // Calories (kcal per 100g)
  static const double _caloriesRarely = 500; // >500kcal → rarely
  static const double _caloriesLimit = 350; // >350kcal → limit

  static ConsumptionResult rate(Product p, int healthScore) {
    final reasons = <String>[];
    var worst = ConsumptionRating.daily;

    // Always per 100g for frequency rating — not scaled by weight
    final transFat = p.transFat ?? 0.0;
    final sodium = p.sodium ?? 0.0;
    final sugars = p.sugars ?? 0.0;
    final saturatedFat = p.saturatedFat ?? 0.0;
    final calories = p.calories ?? 0.0;

    // ── Trans Fat checks ──────────────────────────────────────────────────
    if (transFat > _transFatRarely) {
      worst = _worst(worst, ConsumptionRating.rarely);
      reasons.add('Very high trans fat (${transFat.toStringAsFixed(1)}g/100g)');
    } else if (transFat > _transFatLimit) {
      worst = _worst(worst, ConsumptionRating.limit);
      reasons.add('Contains trans fat (${transFat.toStringAsFixed(1)}g/100g)');
    }

    // ── Sodium checks ─────────────────────────────────────────────────────
    if (sodium > _sodiumRarely) {
      worst = _worst(worst, ConsumptionRating.rarely);
      reasons.add('Very high sodium (${sodium.toStringAsFixed(0)}mg/100g)');
    } else if (sodium > _sodiumLimit) {
      worst = _worst(worst, ConsumptionRating.limit);
      reasons.add('High sodium (${sodium.toStringAsFixed(0)}mg/100g)');
    } else if (sodium > _sodiumOccasional) {
      worst = _worst(worst, ConsumptionRating.occasional);
      reasons.add('Moderate sodium (${sodium.toStringAsFixed(0)}mg/100g)');
    }

    // ── Sugar checks ──────────────────────────────────────────────────────
    if (sugars > _sugarsRarely) {
      worst = _worst(worst, ConsumptionRating.rarely);
      reasons.add('Very high sugars (${sugars.toStringAsFixed(1)}g/100g)');
    } else if (sugars > _sugarsLimit) {
      worst = _worst(worst, ConsumptionRating.limit);
      reasons.add('High sugars (${sugars.toStringAsFixed(1)}g/100g)');
    } else if (sugars > _sugarsOccasional) {
      worst = _worst(worst, ConsumptionRating.occasional);
      reasons.add('Moderate sugars (${sugars.toStringAsFixed(1)}g/100g)');
    }

    // ── Saturated fat checks ──────────────────────────────────────────────
    if (saturatedFat > _satFatRarely) {
      worst = _worst(worst, ConsumptionRating.rarely);
      reasons.add(
        'Very high saturated fat (${saturatedFat.toStringAsFixed(1)}g/100g)',
      );
    } else if (saturatedFat > _satFatLimit) {
      worst = _worst(worst, ConsumptionRating.limit);
      reasons.add(
        'High saturated fat (${saturatedFat.toStringAsFixed(1)}g/100g)',
      );
    } else if (saturatedFat > _satFatOccasional) {
      worst = _worst(worst, ConsumptionRating.occasional);
      reasons.add(
        'Moderate saturated fat (${saturatedFat.toStringAsFixed(1)}g/100g)',
      );
    }

    // ── Calorie checks ────────────────────────────────────────────────────
    if (calories > _caloriesRarely) {
      worst = _worst(worst, ConsumptionRating.rarely);
      reasons.add(
        'Very high calories (${calories.toStringAsFixed(0)}kcal/100g)',
      );
    } else if (calories > _caloriesLimit) {
      worst = _worst(worst, ConsumptionRating.limit);
      reasons.add('High calories (${calories.toStringAsFixed(0)}kcal/100g)');
    }

    // ── Health score override ─────────────────────────────────────────────
    // If health score is very low, bump to at least limit
    if (healthScore < 20 && worst.index < ConsumptionRating.limit.index) {
      worst = ConsumptionRating.limit;
      reasons.add('Low overall health score');
    }

    if (reasons.isEmpty) {
      reasons.add('Balanced nutrient profile');
    }

    return _build(worst, reasons);
  }

  /// Returns the worse of two ratings
  static ConsumptionRating _worst(ConsumptionRating a, ConsumptionRating b) {
    return a.index > b.index ? a : b;
  }

  static ConsumptionResult _build(
    ConsumptionRating rating,
    List<String> reasons,
  ) {
    switch (rating) {
      case ConsumptionRating.daily:
        return ConsumptionResult(
          rating: rating,
          label: 'Daily',
          description: 'Safe for everyday consumption',
          emoji: '✅',
          color: const Color(0xFF2E7D32),
          bgColor: const Color(0xFFE8F5E9),
          reasons: reasons,
        );
      case ConsumptionRating.occasional:
        return ConsumptionResult(
          rating: rating,
          label: 'Occasional',
          description: 'Fine a few times a week',
          emoji: '🔁',
          color: const Color(0xFF1565C0),
          bgColor: const Color(0xFFE3F2FD),
          reasons: reasons,
        );
      case ConsumptionRating.limit:
        return ConsumptionResult(
          rating: rating,
          label: 'Limit',
          description: 'Once a week or less',
          emoji: '⚠️',
          color: const Color(0xFFE65100),
          bgColor: const Color(0xFFFBE9E7),
          reasons: reasons,
        );
      case ConsumptionRating.rarely:
        return ConsumptionResult(
          rating: rating,
          label: 'Rarely',
          description: 'Avoid or consume very rarely',
          emoji: '🚫',
          color: const Color(0xFFC62828),
          bgColor: const Color(0xFFFFEBEE),
          reasons: reasons,
        );
    }
  }
}
