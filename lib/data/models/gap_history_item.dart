import '../../domain/entities/chat_message.dart';

/// One row from GET `/users/me/gap-history` (`job_analysis_insights`).
class GapHistoryItem {
  const GapHistoryItem({
    required this.id,
    this.jobTitle,
    this.companyName,
    this.jobSummary,
    this.matchScore = 0,
    this.strengths = const [],
    this.criticalGaps = const [],
    this.matchingSkills = const [],
    this.missingSkills = const [],
    this.generationBlocked = false,
    this.blockedReason,
    this.createdAt,
  });

  final String id;
  final String? jobTitle;
  final String? companyName;
  final String? jobSummary;
  final int matchScore;
  final List<String> strengths;
  final List<String> criticalGaps;
  final List<String> matchingSkills;
  final List<String> missingSkills;
  final bool generationBlocked;
  final String? blockedReason;
  final DateTime? createdAt;

  /// Maps API JSON (SQLite or Mongo) into items. Unknown/malformed rows are skipped.
  static List<GapHistoryItem> listFromResponse(dynamic data) {
    final rawItems = _extractItems(data);
    if (rawItems == null) {
      return const [];
    }

    final parsed = <GapHistoryItem>[];
    for (final item in rawItems) {
      if (item is! Map) {
        continue;
      }
      final mapped = fromJson(Map<dynamic, dynamic>.from(item));
      if (mapped != null) {
        parsed.add(mapped);
      }
    }
    return parsed;
  }

  static GapHistoryItem? fromJson(Map<dynamic, dynamic> json) {
    final id = _readId(json['id'] ?? json['insight_id']);
    if (id == null) {
      return null;
    }

    return GapHistoryItem(
      id: id,
      jobTitle: _readString(json['job_title']),
      companyName: _readString(json['company_name']),
      jobSummary: _readString(json['job_summary']),
      matchScore: _readInt(json['match_score']),
      strengths: _readStringList(json['strengths']),
      criticalGaps: _readStringList(json['critical_gaps']),
      matchingSkills: _readStringList(json['matching_skills']),
      missingSkills: _readStringList(json['missing_skills']),
      generationBlocked: json['generation_blocked'] == true,
      blockedReason: _readString(json['blocked_reason']),
      createdAt: _readDate(json['created_at']),
    );
  }

  String get displayText {
    final buffer = StringBuffer();
    final title = jobTitle?.trim() ?? '';
    final company = companyName?.trim() ?? '';
    if (title.isNotEmpty) {
      buffer.writeln(title);
    }
    if (company.isNotEmpty) {
      buffer.writeln('Empresa: $company');
    }
    buffer.writeln('Aderencia: $matchScore/100');
    if (generationBlocked) {
      final reason = blockedReason?.trim();
      buffer.writeln(
        (reason == null || reason.isEmpty)
            ? 'PDF nao gerado.'
            : 'PDF nao gerado: $reason',
      );
    }

    final summary = jobSummary?.trim() ?? '';
    if (summary.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(summary);
    }
    if (strengths.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Pontos fortes: ${strengths.join(', ')}');
    }
    if (criticalGaps.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Lacunas criticas: ${criticalGaps.join(', ')}');
    }

    return buffer.toString().trim();
  }

  ChatMessage toChatMessage() {
    return ChatMessage(
      id: id,
      text: displayText,
      isUser: false,
      timestamp: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static List<dynamic>? _extractItems(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is Map) {
      final items = data['items'];
      if (items is List) {
        return items;
      }
    }
    return null;
  }

  static String? _readId(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? _readString(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static DateTime? _readDate(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      if (value > 9999999999) {
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      }
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}
