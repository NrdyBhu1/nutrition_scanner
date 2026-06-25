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
  static int compute(Product p) {
    double score = 100;

    // Deductions
    score -= p.safeVal(p.transFat) * 10.0;
    score -= p.safeVal(p.saturatedFat) * 3.0;
    score -= p.safeVal(p.cholesterol) * 0.1;
    score -= p.safeVal(p.sodium) * 0.02;
    score -= p.safeVal(p.sugars) * 1.5;

    // Additions
    score += p.safeVal(p.fiber) * 4.0;
    score += p.safeVal(p.protein) * 2.0;
    score += p.safeVal(p.potassium) * 0.01;

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
