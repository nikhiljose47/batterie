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
  });

  final String id;
  final String title;
  final String summary;
  final String category;
  final String imageUrl;
  final DateTime publishedAt;
  final int readTimeMinutes;
  final List<ArticleSection> sections;
}

class ArticleSection {
  const ArticleSection({
    required this.heading,
    required this.body,
  });

  final String heading;
  final String body;
}
