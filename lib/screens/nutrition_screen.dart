import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/product.dart';
import '../utils/health_score.dart';
import '../db_helper.dart';
import '../utils/allergen_checker.dart';
import '../utils/consumption_rating.dart';
import '../utils/ingredient_analyzer.dart';

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
    final hasData = HealthScore.hasAnyData(product);
    final score = HealthScore.compute(product);
    final rating = hasData ? ConsumptionRater.rate(product, score) : null;
    final ingredientResult = IngredientAnalyzer.analyse(product.ingredients);
    final chartData = product.chartNutrients; // Map<String, int>
    final entries = chartData.entries.toList();
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);

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
      body: !hasData
          ? _NoDataView(product: product)
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    product.productName,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Health Score Card ─────────────────────────────────────────
                  _HealthScoreCard(score: score, weightG: product.weightG),
                  const SizedBox(height: 20),

                  // ── Consumption Rating ────────────────────────────────────────
                  if (rating != null) _ConsumptionRatingCard(result: rating),
                  const SizedBox(height: 20),

                  // ── Ingredient Flags ──────────────────────────────────────────
                  if (ingredientResult.hasAnyFlags) ...[
                    _IngredientFlagsCard(result: ingredientResult),
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 8),

                  // ── Calories Badge ────────────────────────────────────────────
                  _CaloriesBadge(calories: product.calories?.toInt()),
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

                  // ── Allergen Banner ───────────────────────────────────────────
                  _AllergenBanner(product: product),
                  const SizedBox(height: 12),

                  // ── Nutrition Table ───────────────────────────────────────────
                  _SectionHeader(title: 'Full Nutrition Facts'),
                  const SizedBox(height: 12),
                  _NutritionTable(rows: product.tableRows),
                  const SizedBox(height: 32),
                  // ── Add to Daily Tracker ──────────────────────────────────────
                  //
                  if (hasData) _AddToDailyButton(product: product),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
// ─── No Data View ─────────────────────────────────────────────────────────────

class _NoDataView extends StatelessWidget {
  final Product product;
  const _NoDataView({required this.product});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Still show allergen banner — may have allergen data even
          // without nutrition values
          _AllergenBanner(product: product),
          const SizedBox(height: 16),

          // No data card
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.no_food_rounded,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Nutrition Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This product exists but has no\nnutrition values available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 24),
                // Health score 0 badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFEF9A9A)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFC62828),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Health Score: 0',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFC62828),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Health Score Card ────────────────────────────────────────────────────────

class _HealthScoreCard extends StatelessWidget {
  final int score;
  final double? weightG;
  const _HealthScoreCard({required this.score, this.weightG});

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
                  weightG != null
                      ? 'Health Score  •  for ${weightG!.toStringAsFixed(0)}g'
                      : 'Health Score  •  per 100g',
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
  final List<MapEntry<String, double>> entries;
  final double total;
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
              value: entry.value,
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
  final List<MapEntry<String, double>> entries;
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
  final List<MapEntry<String, double?>> rows;
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
                  // row.value != null ? '${row.value}' : '—',
                  row.value != null
                      ? row.value! % 1 == 0
                            ? '${row.value!.toInt()}'
                            : row.value!.toStringAsFixed(2)
                      : '—',
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
// ─── Allergen Banner ──────────────────────────────────────────────────────────

class _AllergenBanner extends StatefulWidget {
  final Product product;
  const _AllergenBanner({required this.product});

  @override
  State<_AllergenBanner> createState() => _AllergenBannerState();
}

class _AllergenBannerState extends State<_AllergenBanner> {
  AllergenResult? _result;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final profile = await DatabaseHelper.instance.fetchProfile();
    final result = AllergenChecker.check(widget.product, profile);
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    if (_result == null) return const SizedBox.shrink();

    final allFlags = _result!.allFlags;
    if (allFlags.isEmpty) return const SizedBox.shrink();

    final hasMatch = _result!.hasMatch;
    final bgColor = hasMatch
        ? const Color(0xFFFFEBEE)
        : const Color(0xFFFFF8E1);
    final border = hasMatch ? const Color(0xFFEF9A9A) : const Color(0xFFFFD54F);
    final iconColor = hasMatch
        ? const Color(0xFFC62828)
        : const Color(0xFFF57F17);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                hasMatch ? 'Allergen Match!' : 'Contains Allergens',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                ),
              ),
            ],
          ),
          if (hasMatch) ...[
            const SizedBox(height: 6),
            Text(
              _result!.matchSummary,
              style: const TextStyle(fontSize: 12, color: Color(0xFFC62828)),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: allFlags.map((key) {
              final color = AllergenChecker.colorFor(key);
              final matched = _result!.matched.contains(key);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(matched ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: color.withOpacity(matched ? 0.6 : 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AllergenChecker.iconFor(key), size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(
                      AllergenChecker.labelFor(key),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: matched ? FontWeight.w700 : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Add to Daily Button ──────────────────────────────────────────────────────

class _AddToDailyButton extends StatefulWidget {
  final Product product;
  const _AddToDailyButton({required this.product});

  @override
  State<_AddToDailyButton> createState() => _AddToDailyButtonState();
}

class _AddToDailyButtonState extends State<_AddToDailyButton> {
  bool _adding = false;
  bool _added = false;

  Future<void> _add() async {
    setState(() => _adding = true);
    await DatabaseHelper.instance.logToDaily(widget.product.productId);
    if (mounted) {
      setState(() {
        _adding = false;
        _added = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to today\'s tracker')),
      );
      // Reset after 3s so user can add again (multiple servings)
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _added = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _adding ? null : _add,
        icon: _adding
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                _added
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color: _added
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF00BCD4),
              ),
        label: Text(
          _adding
              ? 'Adding…'
              : _added
              ? 'Added to Tracker'
              : 'Add to Today\'s Tracker',
          style: TextStyle(
            color: _added ? const Color(0xFF2E7D32) : const Color(0xFF00BCD4),
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(
            color: _added ? const Color(0xFF2E7D32) : const Color(0xFF00BCD4),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ─── Consumption Rating Card ──────────────────────────────────────────────────
class _ConsumptionRatingCard extends StatelessWidget {
  final ConsumptionResult result;
  const _ConsumptionRatingCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: result.bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: result.color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text(result.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: result.color,
                    ),
                  ),
                  Text(
                    result.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: result.color.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Frequency dots indicator
              Row(
                children: List.generate(4, (i) {
                  final filled = i <= result.rating.index;
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? result.color
                          : result.color.withOpacity(0.2),
                    ),
                  );
                }),
              ),
            ],
          ),

          // Reasons
          if (result.reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            ...result.reasons.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.arrow_right_rounded,
                      size: 16,
                      color: result.color,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        r,
                        style: TextStyle(
                          fontSize: 12,
                          color: result.color.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Ingredient Flags Card ────────────────────────────────────────────────────

class _IngredientFlagsCard extends StatefulWidget {
  final IngredientAnalysisResult result;
  const _IngredientFlagsCard({required this.result});

  @override
  State<_IngredientFlagsCard> createState() => _IngredientFlagsCardState();
}

class _IngredientFlagsCardState extends State<_IngredientFlagsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final flags = widget.result.flags;
    final worst = widget.result.worstSeverity;
    final worstFlag = flags.firstWhere(
      (f) => f.severity == worst,
      orElse: () => flags.first,
    );

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
        children: [
          // Header — always visible
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: worstFlag.bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      worstFlag.icon,
                      color: worstFlag.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ingredient Concerns',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        Text(
                          '${flags.length} issue${flags.length > 1 ? 's' : ''} found'
                          ' • Worst: ${worstFlag.severityLabel}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF888888),
                  ),
                ],
              ),
            ),
          ),

          // Expanded flags list
          if (_expanded) ...[
            const Divider(height: 1),
            ...flags.map((flag) => _FlagTile(flag: flag)),
          ],
        ],
      ),
    );
  }
}

class _FlagTile extends StatelessWidget {
  final IngredientFlag flag;
  const _FlagTile({required this.flag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: flag.bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(flag.icon, size: 14, color: flag.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      flag.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: flag.color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: flag.bgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        flag.severityLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: flag.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  flag.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF666666),
                  ),
                ),
                if (flag.matchedTerms.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: flag.matchedTerms
                        .take(4) // show max 4 matched terms
                        .map(
                          (term) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: flag.color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              term,
                              style: TextStyle(
                                fontSize: 10,
                                color: flag.color,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
