import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../constants/article_constants.dart';
import '../../../constants/app_spacing.dart';

class ArticleHeroImage extends StatelessWidget {
  const ArticleHeroImage({
    super.key,
    required this.imageUrl,
    this.imageTag = ArticleConstants.defaultImageTag,
    this.height = AppSpacing.detailImageHeight,
  });

  final String imageUrl;
  final String imageTag;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim().isEmpty
        ? ArticleConstants.defaultWebImageForTag(imageTag)
        : imageUrl.trim();
    final cacheWidth = (MediaQuery.sizeOf(context).width *
            MediaQuery.devicePixelRatioOf(context) *
            ArticleConstants.webImageCacheScale)
        .round();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: url == null || url.isEmpty
          ? _LocalArticleImage(imageTag: imageTag)
          : Image.network(
              url,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              errorBuilder: (context, error, stackTrace) {
                return _LocalArticleImage(imageTag: imageTag);
              },
            ),
    );
  }
}

class _LocalArticleImage extends StatelessWidget {
  const _LocalArticleImage({required this.imageTag});

  final String imageTag;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      ArticleConstants.assetForTag(imageTag),
      fit: BoxFit.cover,
    );
  }
}
