class PlanCard {
  const PlanCard({
    required this.id,
    required this.title,
    required this.startOffsetMinutes,
    required this.endOffsetMinutes,
    required this.position,
    this.description,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String? description;
  final int startOffsetMinutes;
  final int endOffsetMinutes;
  final int position;
  final String? imageUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        if (description != null && description!.trim().isNotEmpty)
          'description': description,
        'startOffsetMinutes': startOffsetMinutes,
        'endOffsetMinutes': endOffsetMinutes,
        'position': position,
        if (imageUrl != null && imageUrl!.trim().isNotEmpty)
          'imageUrl': imageUrl,
      };

  factory PlanCard.fromJson(Map<String, dynamic> json) {
    return PlanCard(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: json['description'] as String?,
      startOffsetMinutes: (json['startOffsetMinutes'] as num?)?.round() ?? 0,
      endOffsetMinutes: (json['endOffsetMinutes'] as num?)?.round() ?? 0,
      position: (json['position'] as num?)?.round() ?? 0,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

class Plan {
  const Plan({
    required this.id,
    required this.shortName,
    required this.longName,
    required this.description,
    required this.authorId,
    required this.status,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
    required this.cards,
    this.imageUrl,
  });

  final String id;
  final String shortName;
  final String longName;
  final String description;
  final String? imageUrl;
  final String authorId;
  final String status;
  final String visibility;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PlanCard> cards;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'shortName': shortName,
        'longName': longName,
        'description': description,
        if (imageUrl != null && imageUrl!.trim().isNotEmpty)
          'imageUrl': imageUrl,
        'authorId': authorId,
        'status': status,
        'visibility': visibility,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'cards': cards.map((card) => card.toJson()).toList(),
      };

  factory Plan.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final cards = ((json['cards'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PlanCard.fromJson)
        .where((card) => card.id.isNotEmpty && card.title.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    DateTime readDate(String key) {
      final value = json[key];
      if (value is DateTime) return value;
      return DateTime.tryParse((value as String?) ?? '') ?? now;
    }

    return Plan(
      id: (json['id'] as String?) ?? '',
      shortName:
          (json['shortName'] as String?) ?? (json['name'] as String?) ?? 'Plan',
      longName:
          (json['longName'] as String?) ?? (json['name'] as String?) ?? 'Plan',
      description: (json['description'] as String?) ?? '',
      imageUrl: json['imageUrl'] as String?,
      authorId:
          (json['authorId'] as String?) ?? (json['owner_id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'draft',
      visibility: (json['visibility'] as String?) ?? 'private',
      createdAt: readDate('createdAt'),
      updatedAt: readDate('updatedAt'),
      cards: List<PlanCard>.unmodifiable(cards),
    );
  }
}
