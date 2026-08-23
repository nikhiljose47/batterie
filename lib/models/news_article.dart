class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.imageUrl,
    required this.publishedAt,
    required this.readTimeMinutes,
    required this.sections,
    this.imageTag = '',
  });

  final String id;
  final String title;
  final String summary;
  final String category;
  final String imageUrl;
  final String imageTag;
  final DateTime publishedAt;
  final int readTimeMinutes;
  final List<ArticleSection> sections;

  factory NewsArticle.fromMap(Map<String, dynamic> map) {
    final category = (map['category'] as String?) ?? '';
    return NewsArticle(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      summary: (map['summary'] as String?) ?? '',
      category: category,
      imageUrl: (map['imageUrl'] as String?) ?? '',
      imageTag: (map['imageTag'] as String?) ?? category,
      publishedAt: DateTime.tryParse((map['publishedAt'] as String?) ?? '') ??
          DateTime.now(),
      readTimeMinutes: (map['readTimeMinutes'] as num?)?.round() ?? 3,
      sections: ((map['sections'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ArticleSection.fromMap)
          .toList(growable: false),
    );
  }
}

class ArticleSection {
  const ArticleSection({
    required this.heading,
    required this.body,
  });

  final String heading;
  final String body;

  factory ArticleSection.fromMap(Map<String, dynamic> map) {
    return ArticleSection(
      heading: (map['heading'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
    );
  }
}
