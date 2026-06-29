import 'package:flutter/material.dart';

enum IngredientFlagSeverity {
  info, // just informational
  caution, // moderate concern
  warning, // significant concern
  danger, // avoid
}

class IngredientFlag {
  final String name;
  final String description;
  final IngredientFlagSeverity severity;
  final List<String> matchedTerms; // what was found in ingredients

  const IngredientFlag({
    required this.name,
    required this.description,
    required this.severity,
    required this.matchedTerms,
  });

  Color get color {
    switch (severity) {
      case IngredientFlagSeverity.info:
        return const Color(0xFF1565C0);
      case IngredientFlagSeverity.caution:
        return const Color(0xFFE65100);
      case IngredientFlagSeverity.warning:
        return const Color(0xFFC62828);
      case IngredientFlagSeverity.danger:
        return const Color(0xFF6A1B9A);
    }
  }

  Color get bgColor {
    switch (severity) {
      case IngredientFlagSeverity.info:
        return const Color(0xFFE3F2FD);
      case IngredientFlagSeverity.caution:
        return const Color(0xFFFBE9E7);
      case IngredientFlagSeverity.warning:
        return const Color(0xFFFFEBEE);
      case IngredientFlagSeverity.danger:
        return const Color(0xFFF3E5F5);
    }
  }

  IconData get icon {
    switch (severity) {
      case IngredientFlagSeverity.info:
        return Icons.info_outline_rounded;
      case IngredientFlagSeverity.caution:
        return Icons.warning_amber_rounded;
      case IngredientFlagSeverity.warning:
        return Icons.report_outlined;
      case IngredientFlagSeverity.danger:
        return Icons.dangerous_outlined;
    }
  }

  String get severityLabel {
    switch (severity) {
      case IngredientFlagSeverity.info:
        return 'Info';
      case IngredientFlagSeverity.caution:
        return 'Caution';
      case IngredientFlagSeverity.warning:
        return 'Warning';
      case IngredientFlagSeverity.danger:
        return 'Danger';
    }
  }

  /// Health score penalty for this flag
  int get scorePenalty {
    switch (severity) {
      case IngredientFlagSeverity.info:
        return 0;
      case IngredientFlagSeverity.caution:
        return 5;
      case IngredientFlagSeverity.warning:
        return 15;
      case IngredientFlagSeverity.danger:
        return 25;
    }
  }
}

class IngredientAnalysisResult {
  final List<IngredientFlag> flags;
  final bool hasArtificialSweeteners;
  final bool hasPreservatives;
  final bool hasArtificialColours;
  final bool isUltraProcessed;
  final int totalPenalty;

  const IngredientAnalysisResult({
    required this.flags,
    required this.hasArtificialSweeteners,
    required this.hasPreservatives,
    required this.hasArtificialColours,
    required this.isUltraProcessed,
    required this.totalPenalty,
  });

  bool get hasAnyFlags => flags.isNotEmpty;

  /// Worst severity found
  IngredientFlagSeverity? get worstSeverity {
    if (flags.isEmpty) return null;
    return flags
        .map((f) => f.severity)
        .reduce((a, b) => a.index > b.index ? a : b);
  }
}

class IngredientAnalyzer {
  /// Groups of ingredients to flag, with their match terms
  static const _groups = [
    _IngredientGroup(
      name: 'Artificial Sweeteners',
      description:
          'Artificial sweeteners may affect gut microbiome and '
          'insulin response despite being calorie-free',
      severity: IngredientFlagSeverity.caution,
      terms: [
        'aspartame', 'e951',
        'sucralose', 'e955',
        'acesulfame', 'acesulfame-k', 'e950',
        'saccharin', 'e954',
        'neotame', 'e961',
        'advantame', 'e969',
        'cyclamate', 'e952',
        'stevia', 'steviol', 'e960', // natural but still a sweetener flag
        'erythritol',
        'xylitol',
        'sorbitol', 'e420',
        'maltitol', 'e965',
        'isomalt', 'e953',
      ],
    ),
    _IngredientGroup(
      name: 'Artificial Colours',
      description:
          'Some artificial colours are linked to hyperactivity '
          'in children and allergic reactions',
      severity: IngredientFlagSeverity.warning,
      terms: [
        'e102',
        'tartrazine',
        'e104',
        'quinoline yellow',
        'e110',
        'sunset yellow',
        'e122',
        'carmoisine',
        'e124',
        'ponceau',
        'e129',
        'allura red',
        'e133',
        'brilliant blue',
        'e142',
        'green s',
        'e151',
        'brilliant black',
        'e155',
        'brown ht',
        'artificial color',
        'artificial colour',
        'artificial dye',
      ],
    ),
    _IngredientGroup(
      name: 'Preservatives',
      description:
          'Chemical preservatives can cause reactions in '
          'sensitive individuals and have long-term health concerns',
      severity: IngredientFlagSeverity.caution,
      terms: [
        'sodium benzoate',
        'e211',
        'potassium benzoate',
        'e212',
        'sodium nitrite',
        'e250',
        'sodium nitrate',
        'e251',
        'potassium nitrite',
        'e249',
        'potassium nitrate',
        'e252',
        'sodium sorbate',
        'potassium sorbate',
        'e202',
        'calcium propionate',
        'e282',
        'sodium propionate',
        'e281',
        'bha',
        'butylated hydroxyanisole',
        'e320',
        'bht',
        'butylated hydroxytoluene',
        'e321',
        'tbhq',
        'e319',
      ],
    ),
    _IngredientGroup(
      name: 'High Fructose Corn Syrup',
      description:
          'Linked to obesity, insulin resistance, and fatty liver '
          'disease when consumed regularly',
      severity: IngredientFlagSeverity.danger,
      terms: [
        'high fructose corn syrup',
        'hfcs',
        'corn syrup',
        'glucose-fructose syrup',
        'glucose fructose syrup',
        'fructose syrup',
        'isoglucose',
      ],
    ),
    _IngredientGroup(
      name: 'Phosphoric Acid',
      description:
          'Found in colas — linked to reduced bone density '
          'and dental erosion with regular consumption',
      severity: IngredientFlagSeverity.caution,
      terms: ['phosphoric acid', 'e338'],
    ),
    _IngredientGroup(
      name: 'Caffeine',
      description:
          'Stimulant — not suitable for children, pregnant women, '
          'or caffeine-sensitive individuals',
      severity: IngredientFlagSeverity.info,
      terms: [
        'caffeine',
        'guarana', // natural caffeine source
      ],
    ),
    _IngredientGroup(
      name: 'Palm Oil',
      description:
          'High in saturated fat and associated with '
          'environmental concerns',
      severity: IngredientFlagSeverity.caution,
      terms: ['palm oil', 'palm fat', 'palm kernel oil', 'palm olein'],
    ),
    _IngredientGroup(
      name: 'Ultra-Processed Markers',
      description:
          'Multiple additives indicate heavy industrial processing '
          '— associated with poor long-term health outcomes',
      severity: IngredientFlagSeverity.warning,
      terms: [
        'modified starch',
        'modified corn starch',
        'modified tapioca starch',
        'hydrolysed',
        'hydrogenated',
        'partially hydrogenated',
        'interesterified',
        'textured',
        'artificial flavor', 'artificial flavour',
        'natural flavor',
        'natural flavour', // often synthetic in processed foods
        'emulsifier',
        'mono and diglycerides',
        'carrageenan', 'e407',
        'cellulose', 'e460',
        'xanthan gum', 'e415',
        'carboxymethylcellulose', 'e466',
      ],
      minMatchCount: 3, // only flag if 3+ ultra-processed markers found
    ),
    _IngredientGroup(
      name: 'Monosodium Glutamate',
      description:
          'Flavour enhancer — may cause reactions in sensitive '
          'individuals (MSG symptom complex)',
      severity: IngredientFlagSeverity.caution,
      terms: [
        'monosodium glutamate',
        'msg',
        'e621',
        'glutamate',
        'yeast extract', // often used as hidden MSG source
      ],
    ),
    _IngredientGroup(
      name: 'Sulphites',
      description:
          'Can cause asthma and allergic reactions, '
          'especially in sensitive individuals',
      severity: IngredientFlagSeverity.caution,
      terms: [
        'sulphite',
        'sulfite',
        'sulphur dioxide',
        'sulfur dioxide',
        'e220',
        'e221',
        'e222',
        'e223',
        'e224',
        'e225',
        'e226',
        'sodium metabisulphite',
        'sodium metabisulfite',
      ],
    ),
  ];

  /// Analyse ingredients text and return flags + penalties
  static IngredientAnalysisResult analyse(String? ingredientsText) {
    if (ingredientsText == null || ingredientsText.trim().isEmpty) {
      return const IngredientAnalysisResult(
        flags: [],
        hasArtificialSweeteners: false,
        hasPreservatives: false,
        hasArtificialColours: false,
        isUltraProcessed: false,
        totalPenalty: 0,
      );
    }

    final lower = ingredientsText.toLowerCase();
    final flags = <IngredientFlag>[];
    int penalty = 0;

    bool hasArtificialSweeteners = false;
    bool hasPreservatives = false;
    bool hasArtificialColours = false;
    bool isUltraProcessed = false;

    for (final group in _groups) {
      final matched = group.terms
          .where((term) => lower.contains(term))
          .toList();

      final minCount = group.minMatchCount ?? 1;
      if (matched.length < minCount) continue;

      flags.add(
        IngredientFlag(
          name: group.name,
          description: group.description,
          severity: group.severity,
          matchedTerms: matched,
        ),
      );
      penalty += IngredientFlag(
        name: group.name,
        description: group.description,
        severity: group.severity,
        matchedTerms: matched,
      ).scorePenalty;

      // Set category flags
      if (group.name == 'Artificial Sweeteners') {
        hasArtificialSweeteners = true;
      }
      if (group.name == 'Preservatives') hasPreservatives = true;
      if (group.name == 'Artificial Colours') hasArtificialColours = true;
      if (group.name == 'Ultra-Processed Markers') isUltraProcessed = true;
    }

    // Sort by severity — worst first
    flags.sort((a, b) => b.severity.index.compareTo(a.severity.index));

    return IngredientAnalysisResult(
      flags: flags,
      hasArtificialSweeteners: hasArtificialSweeteners,
      hasPreservatives: hasPreservatives,
      hasArtificialColours: hasArtificialColours,
      isUltraProcessed: isUltraProcessed,
      totalPenalty: penalty.clamp(0, 60), // cap at 60pt penalty
    );
  }
}

/// Internal group definition
class _IngredientGroup {
  final String name;
  final String description;
  final IngredientFlagSeverity severity;
  final List<String> terms;
  final int? minMatchCount;

  const _IngredientGroup({
    required this.name,
    required this.description,
    required this.severity,
    required this.terms,
    this.minMatchCount,
  });
}
