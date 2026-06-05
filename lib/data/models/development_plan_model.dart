class DevelopmentPlanModel {
  final String pdiId;
  final String title;
  final String mainObjective;
  final String summary;
  final List<String> secondaryObjectives;
  final List<String> priorityAreas;
  final List<String> priorityGaps;
  final List<String> strengthsToLeverage;
  final int progressPercent;
  final String status;
  final Map<String, List<DevelopmentPlanItemModel>> sections;
  final List<DevelopmentPlanItemModel> checklistItems;
  final String? createdAt;
  final String? updatedAt;
  final String? completedAt;

  const DevelopmentPlanModel({
    required this.pdiId,
    required this.title,
    required this.mainObjective,
    required this.summary,
    required this.secondaryObjectives,
    required this.priorityAreas,
    required this.priorityGaps,
    required this.strengthsToLeverage,
    required this.progressPercent,
    required this.status,
    required this.sections,
    required this.checklistItems,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  factory DevelopmentPlanModel.fromJson(Map<String, dynamic> json) {
    final sectionsJson = json['sections'];
    final sections = <String, List<DevelopmentPlanItemModel>>{
      '70': const [],
      '20': const [],
      '10': const [],
    };

    if (sectionsJson is Map<String, dynamic>) {
      for (final category in sections.keys) {
        final items = sectionsJson[category];
        sections[category] = _parseItems(items);
      }
    }

    return DevelopmentPlanModel(
      pdiId: _string(json['pdi_id']),
      title: _string(json['title'], fallback: 'PDI'),
      mainObjective: _string(json['main_objective']),
      summary: _string(json['summary']),
      secondaryObjectives: _parseStrings(json['secondary_objectives']),
      priorityAreas: _parseStrings(json['priority_areas']),
      priorityGaps: _parseStrings(json['priority_gaps']),
      strengthsToLeverage: _parseStrings(json['strengths_to_leverage']),
      progressPercent: _int(json['progress_percent']),
      status: _string(json['status'], fallback: 'active'),
      sections: sections,
      checklistItems: _parseItems(json['checklist_items']),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      completedAt: json['completed_at'] as String?,
    );
  }

  DevelopmentPlanModel copyWith({
    int? progressPercent,
    String? status,
    Map<String, List<DevelopmentPlanItemModel>>? sections,
    List<DevelopmentPlanItemModel>? checklistItems,
  }) {
    return DevelopmentPlanModel(
      pdiId: pdiId,
      title: title,
      mainObjective: mainObjective,
      summary: summary,
      secondaryObjectives: secondaryObjectives,
      priorityAreas: priorityAreas,
      priorityGaps: priorityGaps,
      strengthsToLeverage: strengthsToLeverage,
      progressPercent: progressPercent ?? this.progressPercent,
      status: status ?? this.status,
      sections: sections ?? this.sections,
      checklistItems: checklistItems ?? this.checklistItems,
      createdAt: createdAt,
      updatedAt: updatedAt,
      completedAt: completedAt,
    );
  }

  static List<DevelopmentPlanItemModel> _parseItems(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(DevelopmentPlanItemModel.fromJson)
        .toList();
  }

  static List<String> _parseStrings(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String _string(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class DevelopmentPlanItemModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String gap;
  final String priority;
  final String status;
  final int weight;

  const DevelopmentPlanItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.gap,
    required this.priority,
    required this.status,
    required this.weight,
  });

  factory DevelopmentPlanItemModel.fromJson(Map<String, dynamic> json) {
    return DevelopmentPlanItemModel(
      id: DevelopmentPlanModel._string(json['id']),
      title: DevelopmentPlanModel._string(json['title']),
      description: DevelopmentPlanModel._string(json['description']),
      category: DevelopmentPlanModel._string(json['category']),
      gap: DevelopmentPlanModel._string(json['gap']),
      priority: DevelopmentPlanModel._string(json['priority'], fallback: 'medium'),
      status: DevelopmentPlanModel._string(json['status'], fallback: 'pending'),
      weight: DevelopmentPlanModel._int(json['weight']),
    );
  }

  DevelopmentPlanItemModel copyWith({String? status}) {
    return DevelopmentPlanItemModel(
      id: id,
      title: title,
      description: description,
      category: category,
      gap: gap,
      priority: priority,
      status: status ?? this.status,
      weight: weight,
    );
  }
}
