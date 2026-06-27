import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models/user_profile.dart';
import '../utils/allergen_checker.dart';
import '../utils/rdi_constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtr = TextEditingController();
  final _ageCtr = TextEditingController();
  final _weightCtr = TextEditingController();

  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  ActivityLevel _activity = ActivityLevel.moderate;
  DietaryMode _diet = DietaryMode.normal;
  int _alertSod = 50;
  int _alertSug = 50;
  int _alertFat = 50;
  List<String> _allergens = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtr.dispose();
    _ageCtr.dispose();
    _weightCtr.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await DatabaseHelper.instance.fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _nameCtr.text = p.name;
        _ageCtr.text = p.age.toString();
        _weightCtr.text = p.weightKg.toString();
        _activity = p.activityLevel;
        _diet = p.dietaryMode;
        _alertSod = p.alertSodiumPct;
        _alertSug = p.alertSugarPct;
        _alertFat = p.alertFatPct;
        _allergens = List.from(p.knownAllergens);
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = UserProfile(
        id: 1,
        name: _nameCtr.text.trim(),
        age: int.tryParse(_ageCtr.text) ?? 25,
        weightKg: double.tryParse(_weightCtr.text) ?? 70.0,
        activityLevel: _activity,
        dietaryMode: _diet,
        alertSodiumPct: _alertSod,
        alertSugarPct: _alertSug,
        alertFatPct: _alertFat,
        knownAllergens: _allergens,
      );
      await DatabaseHelper.instance.saveProfile(updated);
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text(
                'Save',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00BCD4),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _load)
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionCard(
                      title: 'Personal Info',
                      icon: Icons.person_rounded,
                      children: [
                        _FieldRow(
                          label: 'Name',
                          child: TextFormField(
                            controller: _nameCtr,
                            decoration: _inputDeco('Your name'),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        _FieldRow(
                          label: 'Age',
                          child: TextFormField(
                            controller: _ageCtr,
                            decoration: _inputDeco('Years'),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n < 1 || n > 120) {
                                return 'Enter valid age';
                              }
                              return null;
                            },
                          ),
                        ),
                        _FieldRow(
                          label: 'Weight (kg)',
                          child: TextFormField(
                            controller: _weightCtr,
                            decoration: _inputDeco('kg'),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              if (n == null || n < 20 || n > 300) {
                                return 'Enter valid weight';
                              }
                              return null;
                            },
                          ),
                        ),
                        _FieldRow(
                          label: 'Activity Level',
                          child: _SegmentedPicker<ActivityLevel>(
                            values: ActivityLevel.values,
                            labels: ActivityLevel.values
                                .map((e) => e.label)
                                .toList(),
                            current: _activity,
                            onChanged: (v) => setState(() => _activity = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _SectionCard(
                      title: 'Dietary Mode',
                      icon: Icons.restaurant_rounded,
                      children: [
                        ...DietaryMode.values.map(
                          (mode) => RadioListTile<DietaryMode>(
                            value: mode,
                            groupValue: _diet,
                            title: Text(
                              mode.label,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              _dietSubtitle(mode),
                              style: const TextStyle(fontSize: 12),
                            ),
                            activeColor: const Color(0xFF00BCD4),
                            onChanged: (v) => setState(() => _diet = v!),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _SectionCard(
                      title: 'Nutrient Alerts',
                      icon: Icons.notifications_active_rounded,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Alert when daily intake exceeds % of RDI:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ),
                        _SliderRow(
                          label: 'Sodium',
                          value: _alertSod,
                          color: const Color(0xFFFF5722),
                          onChanged: (v) => setState(() => _alertSod = v),
                        ),
                        _SliderRow(
                          label: 'Sugars',
                          value: _alertSug,
                          color: const Color(0xFFE91E63),
                          onChanged: (v) => setState(() => _alertSug = v),
                        ),
                        _SliderRow(
                          label: 'Total Fat',
                          value: _alertFat,
                          color: const Color(0xFF2196F3),
                          onChanged: (v) => setState(() => _alertFat = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _SectionCard(
                      title: 'My Allergens',
                      icon: Icons.warning_amber_rounded,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Select allergens to flag on scan:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: AllergenChecker.registry.map((meta) {
                            final selected = _allergens.contains(meta.key);
                            return FilterChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    meta.icon,
                                    size: 14,
                                    color: selected ? Colors.white : meta.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    meta.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF333333),
                                    ),
                                  ),
                                ],
                              ),
                              selected: selected,
                              selectedColor: meta.color,
                              backgroundColor: meta.color.withOpacity(0.08),
                              checkmarkColor: Colors.white,
                              side: BorderSide(
                                color: meta.color.withOpacity(0.3),
                              ),
                              onSelected: (on) {
                                setState(() {
                                  if (on) {
                                    _allergens.add(meta.key);
                                  } else {
                                    _allergens.remove(meta.key);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_profile != null) _RdiPreviewCard(profile: _profile!),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BCD4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Save Profile',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  String _dietSubtitle(DietaryMode m) {
    switch (m) {
      case DietaryMode.keto:
        return 'High fat, very low carbs (≤25g/day)';
      case DietaryMode.lowSodium:
        return 'Sodium capped at 1500mg/day';
      case DietaryMode.highProtein:
        return 'Protein target raised to 150g/day';
      case DietaryMode.normal:
      default:
        return 'Standard 2000 kcal reference targets';
    }
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFBBBBBB)),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 1.5),
    ),
  );
}

// ─── RDI Preview Card ─────────────────────────────────────────────────────────

class _RdiPreviewCard extends StatelessWidget {
  final UserProfile profile;
  const _RdiPreviewCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final rdi = RdiConstants.scaledForUser(profile);
    final tdee = RdiConstants.tdee(
      weightKg: profile.weightKg,
      age: profile.age,
      activityLevel: profile.activityLevel,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Color(0xFF1565C0),
              ),
              const SizedBox(width: 6),
              const Text(
                'Your estimated daily targets',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1565C0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'TDEE: $tdee kcal  •  Mode: ${profile.dietaryMode.label}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: rdi.entries
                .map(
                  (e) => Text(
                    '${e.key}: ${e.value}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF333333),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Container(
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF00BCD4)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
        const Divider(height: 20),
        ...children,
      ],
    ),
  );
}

class _FieldRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _FieldRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF555555),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}

class _SliderRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final void Function(int) onChanged;
  const _SliderRow({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 10,
            max: 100,
            divisions: 18,
            activeColor: color,
            inactiveColor: color.withOpacity(0.2),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$value%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SegmentedPicker<T> extends StatelessWidget {
  final List<T> values;
  final List<String> labels;
  final T current;
  final void Function(T) onChanged;
  const _SegmentedPicker({
    required this.values,
    required this.labels,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: List.generate(values.length, (i) {
      final selected = values[i] == current;
      return GestureDetector(
        onTap: () => onChanged(values[i]),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF00BCD4) : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            labels[i],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF555555),
            ),
          ),
        ),
      );
    }),
  );
}

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
