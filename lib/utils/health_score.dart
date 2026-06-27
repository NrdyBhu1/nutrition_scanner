import 'package:flutter/material.dart';
import '../models/product.dart';

class HealthScore {
  /// Computes 0–100 health score from product nutrients.
  ///
  /// Deductions (bad):
  ///   Trans Fat      × 10
  ///   Saturated Fat  × 3
  ///   Cholesterol    × 0.1
  ///   Sodium         × 0.02
  ///   Sugars         × 1.5
  ///
  /// Additions (good):
  ///   Fiber          × 4
  ///   Protein        × 2
  ///   Potassium      × 0.01
  static bool hasAnyData(Product p) {
    return [
      p.calories,
      p.totalFat,
      p.saturatedFat,
      p.transFat,
      p.cholesterol,
      p.sodium,
      p.potassium,
      p.totalCarbs,
      p.protein,
      p.sugars,
      p.fiber,
    ].any((v) => v != null);
  }

  static int compute(Product p) {
    if (!hasAnyData(p)) return 0;

    double score = 100;

    score -= (p.transFat ?? 0.0) * 10.0;
    score -= (p.saturatedFat ?? 0.0) * 3.0;
    score -= (p.cholesterol ?? 0.0) * 0.1;
    score -= (p.sodium ?? 0.0) * 0.02;
    score -= (p.sugars ?? 0.0) * 1.5;

    score += (p.fiber ?? 0.0) * 4.0;
    score += (p.protein ?? 0.0) * 2.0;
    score += (p.potassium ?? 0.0) * 0.01;

    return score.round().clamp(0, 100);
  }

  /// Label based on score range.
  static String label(int score) {
    if (score >= 70) return 'Excellent';
    if (score >= 40) return 'Fair';
    return 'Poor';
  }

  /// Color: green ≥70, orange 40–69, red <40.
  static Color color(int score) {
    if (score >= 70) return const Color(0xFF2E7D32); // deep green
    if (score >= 40) return const Color(0xFFE65100); // deep orange
    return const Color(0xFFC62828); // deep red
  }

  /// Light background tint for score card.
  static Color bgColor(int score) {
    if (score >= 70) return const Color(0xFFE8F5E9);
    if (score >= 40) return const Color(0xFFFBE9E7);
    return const Color(0xFFFFEBEE);
  }
}
