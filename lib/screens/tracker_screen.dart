import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../db_helper.dart';
import '../models/daily_intake.dart';
import '../models/user_profile.dart';
import '../utils/rdi_constants.dart';
import 'nutrition_screen.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  DailyIntake? _today;
  List<DailyIntake> _week = [];
  UserProfile? _profile;
  Map<String, int> _rdi = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await DatabaseHelper.instance.fetchProfile();
      final today = await DatabaseHelper.instance.fetchDailyIntake(
        DailyIntake.todayKey,
      );
      final week = await DatabaseHelper.instance.fetchWeeklyIntake();
      final rdi = RdiConstants.scaledForUser(profile);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _today = today;
        _week = week;
        _rdi = rdi;
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _removeProduct(int productId) async {
    await DatabaseHelper.instance.removeFromDaily(
      productId,
      DailyIntake.todayKey,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Daily Tracker',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Date header ──────────────────────────────────
                    _DateHeader(date: DailyIntake.todayKey),
                    const SizedBox(height: 16),

                    // ── Calorie ring card ────────────────────────────
                    _CalorieRingCard(
                      consumed: _today?.totalCalories ?? 0.0,
                      target: _rdi['Calories'] ?? RdiConstants.baseCalories,
                    ),
                    const SizedBox(height: 20),

                    // ── Nutrient progress bars ───────────────────────
                    _SectionLabel(label: 'Nutrient Progress'),
                    const SizedBox(height: 12),
                    _NutrientProgressCard(today: _today!, rdi: _rdi),
                    const SizedBox(height: 20),

                    // ── Weekly calorie chart ─────────────────────────
                    _SectionLabel(label: '7-Day Calories'),
                    const SizedBox(height: 12),
                    _WeeklyChart(
                      week: _week,
                      target: _rdi['Calories'] ?? RdiConstants.baseCalories,
                    ),
                    const SizedBox(height: 20),

                    // ── Logged products ──────────────────────────────
                    _SectionLabel(
                      label:
                          "Today's Products"
                          " (${_today?.productIds.length ?? 0})",
                    ),
                    const SizedBox(height: 12),
                    _LoggedProductsList(
                      today: _today!,
                      onRemove: _removeProduct,
                      onViewProduct: (id) async {
                        final p = await DatabaseHelper.instance.queryProduct(
                          id,
                        );
                        if (p != null && mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NutritionScreen(product: p),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─── Date Header ──────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final String date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final display = '${now.day} ${months[now.month - 1]} ${now.year}';
    return Row(
      children: [
        const Icon(
          Icons.calendar_today_rounded,
          size: 16,
          color: Color(0xFF888888),
        ),
        const SizedBox(width: 6),
        Text(
          display,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF888888),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Calorie Ring Card ────────────────────────────────────────────────────────

class _CalorieRingCard extends StatelessWidget {
  final double consumed;
  final int target;
  const _CalorieRingCard({required this.consumed, required this.target});

  @override
  Widget build(BuildContext context) {
    final pct = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final remaining = (target - consumed).clamp(0, target.toDouble());
    final over = consumed > target;
    final ringColor = over
        ? const Color(0xFFC62828)
        : pct > 0.75
        ? const Color(0xFFE65100)
        : const Color(0xFF2E7D32);

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          // Ring
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: pct,
                  strokeWidth: 8,
                  backgroundColor: const Color(0xFFEEEEEE),
                  valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                ),
                Text(
                  '${(pct * 100).round()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: ringColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // '$consumed kcal',
                  '${consumed % 1 == 0 ? consumed.toInt() : consumed.toStringAsFixed(1)} kcal',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'of $target kcal target',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ringColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    over
                        //  ? '${consumed - target} kcal over'
                        //  : '$remaining kcal remaining',over
                        ? '${(consumed - target).toStringAsFixed(1)} kcal over'
                        : '${remaining.toStringAsFixed(1)} kcal remaining',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ringColor,
                    ),
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

// ─── Nutrient Progress Card ───────────────────────────────────────────────────

class _NutrientProgressCard extends StatelessWidget {
  final DailyIntake today;
  final Map<String, int> rdi;
  const _NutrientProgressCard({required this.today, required this.rdi});

  static const _tracked = [
    ('Total Fat', Color(0xFF2196F3)),
    ('Sodium', Color(0xFFFF5722)),
    ('Total Carbs', Color(0xFF4CAF50)),
    ('Protein', Color(0xFFFF9800)),
    ('Sugars', Color(0xFFE91E63)),
    ('Fiber', Color(0xFF009688)),
    ('Cholesterol', Color(0xFF9C27B0)),
  ];

  double _val(String key) {
    switch (key) {
      case 'Total Fat':
        return today.totalFat;
      case 'Sodium':
        return today.totalSodium;
      case 'Total Carbs':
        return today.totalCarbs;
      case 'Protein':
        return today.totalProtein;
      case 'Sugars':
        return today.totalSugars;
      case 'Fiber':
        return today.totalFiber;
      case 'Cholesterol':
        return today.totalCholesterol;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: _tracked.map((t) {
          final key = t.$1;
          final color = t.$2;
          final val = _val(key);
          final target = rdi[key] ?? 1;
          final pct = (val / target).clamp(0.0, 1.0);
          final over = val > target;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      key,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF333333),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '$val / $target',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: over
                                ? const Color(0xFFC62828)
                                : const Color(0xFF555555),
                          ),
                        ),
                        if (over) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: Color(0xFFC62828),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: color.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      over ? const Color(0xFFC62828) : color,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Weekly Bar Chart ─────────────────────────────────────────────────────────

class _WeeklyChart extends StatelessWidget {
  final List<DailyIntake> week;
  final int target;
  const _WeeklyChart({required this.week, required this.target});

  @override
  Widget build(BuildContext context) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxY =
        (week.map((d) => d.totalCalories).fold(0.0, (a, b) => a > b ? a : b) *
                1.3)
            .clamp(target * 1.2, double.infinity);

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
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
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: target / 2,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: const Color(0xFFEEEEEE), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: target / 2,
                getTitlesWidget: (v, _) => Text(
                  v >= 1000
                      ? '${(v / 1000).toStringAsFixed(1)}k'
                      : v.toInt().toString(),
                  style: const TextStyle(fontSize: 9, color: Color(0xFF999999)),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= week.length) return const SizedBox();
                  final d = DateTime.now().subtract(
                    Duration(days: week.length - 1 - idx),
                  );
                  return Text(
                    days[d.weekday - 1],
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF999999),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          // Target line
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: target.toDouble(),
                color: const Color(0xFF2E7D32).withOpacity(0.5),
                strokeWidth: 1.5,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600,
                  ),
                  labelResolver: (_) => 'Target',
                ),
              ),
            ],
          ),
          barGroups: List.generate(week.length, (i) {
            final cal = week[i].totalCalories;
            final over = cal > target;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: cal.toDouble(),
                  width: 18,
                  color: over
                      ? const Color(0xFFC62828)
                      : const Color(0xFF00BCD4),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ─── Logged Products List ─────────────────────────────────────────────────────

class _LoggedProductsList extends StatelessWidget {
  final DailyIntake today;
  final void Function(int) onRemove;
  final void Function(int) onViewProduct;

  const _LoggedProductsList({
    required this.today,
    required this.onRemove,
    required this.onViewProduct,
  });

  @override
  Widget build(BuildContext context) {
    if (today.productIds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'No products logged today.\nScan a product and tap "Add to Today".',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ),
      );
    }

    // Group by productId to show count
    final counts = <int, int>{};
    for (final id in today.productIds) {
      counts[id] = (counts[id] ?? 0) + 1;
    }

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
        children: counts.entries.toList().asMap().entries.map((entry) {
          final i = entry.key;
          final id = entry.value.key;
          final count = entry.value.value;
          final isLast = i == counts.length - 1;
          final isFirst = i == 0;

          return Container(
            decoration: BoxDecoration(
              border: !isLast
                  ? const Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))
                  : null,
              borderRadius: BorderRadius.vertical(
                top: isFirst ? const Radius.circular(16) : Radius.zero,
                bottom: isLast ? const Radius.circular(16) : Radius.zero,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_rounded,
                  color: Color(0xFF00BCD4),
                  size: 20,
                ),
              ),
              title: Text(
                'Barcode: $id',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              subtitle: count > 1
                  ? Text(
                      '×$count servings',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF888888),
                      ),
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: Color(0xFF00BCD4),
                    ),
                    tooltip: 'View nutrition',
                    onPressed: () => onViewProduct(id),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline_rounded,
                      size: 18,
                      color: Colors.red,
                    ),
                    tooltip: 'Remove one',
                    onPressed: () => onRemove(id),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1A1A2E),
    ),
  );
}

// ─── Error View ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
