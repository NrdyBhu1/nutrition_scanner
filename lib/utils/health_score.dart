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

    // Scale factor — if weight unknown default to 100g (no scaling)
    final weight = p.weightG ?? 100.0;
    final scale = weight / 100.0;

    // Scale all per-100g values to actual product weight
    final transFat = (p.transFat ?? 0.0) * scale;
    final saturatedFat = (p.saturatedFat ?? 0.0) * scale;
    final cholesterol = (p.cholesterol ?? 0.0) * scale;
    final sodium = (p.sodium ?? 0.0) * scale;
    final sugars = (p.sugars ?? 0.0) * scale;
    final fiber = (p.fiber ?? 0.0) * scale;
    final protein = (p.protein ?? 0.0) * scale;
    final potassium = (p.potassium ?? 0.0) * scale;

    double score = 100;

    score -= transFat * 10.0;
    score -= saturatedFat * 3.0;
    score -= cholesterol * 0.1;
    score -= sodium * 0.02;
    score -= sugars * 1.5;

    score += fiber * 4.0;
    score += protein * 2.0;
    score += potassium * 0.01;

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
