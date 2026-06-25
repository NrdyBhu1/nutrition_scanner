import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/product.dart';
import '../utils/health_score.dart';

// Distinct colors for pie segments
const List<Color> _kSegmentColors = [
  Color(0xFF2196F3), // blue        – Total Fat
  Color(0xFF4CAF50), // green       – Total Carbs
  Color(0xFFFF9800), // orange      – Protein
  Color(0xFFE91E63), // pink        – Sugars
  Color(0xFF009688), // teal        – Fiber
  Color(0xFF9C27B0), // purple      – Cholesterol
  Color(0xFFFF5722), // deep-orange – Sodium
  Color(0xFF00BCD4), // cyan        – Potassium
  Color(0xFFF44336), // red         – Saturated Fat
  Color(0xFF795548), // brown       – Trans Fat
];

class NutritionScreen extends StatefulWidget {
  final Product product;
  const NutritionScreen({super.key, required this.product});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final score = HealthScore.compute(product);
    final chartData = product.chartNutrients; // Map<String, int>
    final entries = chartData.entries.toList();
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nutrition Details',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              'Barcode: ${product.productId}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF888888),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Health Score Card ─────────────────────────────────────────
            _HealthScoreCard(score: score),
            const SizedBox(height: 20),

            // ── Calories Badge ────────────────────────────────────────────
            _CaloriesBadge(calories: product.calories),
            const SizedBox(height: 20),

            // ── Pie Chart ─────────────────────────────────────────────────
            if (entries.isNotEmpty) ...[
              _SectionHeader(title: 'Nutrient Breakdown'),
              const SizedBox(height: 12),
              _PieCard(
                entries: entries,
                total: total,
                touchedIndex: _touchedIndex,
                onTouch: (i) => setState(() => _touchedIndex = i),
              ),
              const SizedBox(height: 8),
              _Legend(entries: entries),
              const SizedBox(height: 20),
            ],

            // ── Nutrition Table ───────────────────────────────────────────
            _SectionHeader(title: 'Full Nutrition Facts'),
            const SizedBox(height: 12),
            _NutritionTable(rows: product.tableRows),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Health Score Card ────────────────────────────────────────────────────────

class _HealthScoreCard extends StatelessWidget {
  final int score;
  const _HealthScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = HealthScore.color(score);
    final bgColor = HealthScore.bgColor(score);
    final label = HealthScore.label(score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          // Score circle
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$score',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Health Score  •  out of 100',
                  style: TextStyle(fontSize: 12, color: color.withOpacity(0.7)),
                ),
                const SizedBox(height: 10),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    backgroundColor: color.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Calories Badge ───────────────────────────────────────────────────────────

class _CaloriesBadge extends StatelessWidget {
  final int? calories;
  const _CaloriesBadge({required this.calories});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFFF9800),
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                'Calories',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            calories != null ? '$calories kcal' : '— kcal',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pie Chart Card ───────────────────────────────────────────────────────────

class _PieCard extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final int total;
  final int touchedIndex;
  final void Function(int) onTouch;

  const _PieCard({
    required this.entries,
    required this.total,
    required this.touchedIndex,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (event, response) {
              if (!event.isInterestedForInteractions ||
                  response == null ||
                  response.touchedSection == null) {
                onTouch(-1);
                return;
              }
              onTouch(response.touchedSection!.touchedSectionIndex);
            },
          ),
          borderData: FlBorderData(show: false),
          sectionsSpace: 2,
          centerSpaceRadius: 52,
          sections: List.generate(entries.length, (i) {
            final touched = i == touchedIndex;
            final entry = entries[i];
            final pct = total > 0 ? (entry.value / total * 100) : 0.0;
            final color = _kSegmentColors[i % _kSegmentColors.length];

            return PieChartSectionData(
              color: color,
              value: entry.value.toDouble(),
              radius: touched ? 72 : 60,
              title: touched ? '${pct.toStringAsFixed(1)}%' : '',
              titleStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              badgeWidget: touched
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.key}\n${entry.value}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : null,
              badgePositionPercentageOffset: 1.35,
            );
          }),
        ),
      ),
    );
  }
}

// ─── Legend ───────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  const _Legend({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: List.generate(entries.length, (i) {
        final color = _kSegmentColors[i % _kSegmentColors.length];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              '${entries[i].key} (${entries[i].value})',
              style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
            ),
          ],
        );
      }),
    );
  }
}

// ─── Nutrition Table ──────────────────────────────────────────────────────────

class _NutritionTable extends StatelessWidget {
  final List<MapEntry<String, int?>> rows;
  const _NutritionTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: List.generate(rows.length, (i) {
          final row = rows[i];
          final isLast = i == rows.length - 1;
          final isFirst = i == 0;
          final isCalorie = row.key == 'Calories';

          return Container(
            decoration: BoxDecoration(
              color: isCalorie
                  ? const Color(0xFFFFF8E1)
                  : (i.isEven ? Colors.white : const Color(0xFFF9FAFB)),
              borderRadius: BorderRadius.vertical(
                top: isFirst ? const Radius.circular(16) : Radius.zero,
                bottom: isLast ? const Radius.circular(16) : Radius.zero,
              ),
              border: !isLast
                  ? const Border(
                      bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                    )
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  row.key,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCalorie ? FontWeight.w700 : FontWeight.w500,
                    color: isCalorie
                        ? const Color(0xFFE65100)
                        : const Color(0xFF333333),
                  ),
                ),
                Text(
                  row.value != null ? '${row.value}' : '—',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCalorie ? FontWeight.w700 : FontWeight.w600,
                    color: isCalorie
                        ? const Color(0xFFE65100)
                        : const Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A2E),
        letterSpacing: 0.3,
      ),
    );
  }
}
