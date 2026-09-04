import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../constants/article_constants.dart';
import '../../../constants/app_spacing.dart';

class ArticleHeroImage extends StatelessWidget {
  const ArticleHeroImage({
    super.key,
    required this.imageUrl,
    this.imageTag = ArticleConstants.defaultImageTag,
    this.searchText = '',
    this.height = AppSpacing.detailImageHeight,
  });

  final String imageUrl;
  final String imageTag;
  final String searchText;
  final double height;

  static Future<List<String>>? _assetFuture;

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
          ? _LocalArticleImage(imageTag: imageTag, searchText: searchText)
          : Image.network(
              url,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              errorBuilder: (context, error, stackTrace) {
                return _LocalArticleImage(
                  imageTag: imageTag,
                  searchText: searchText,
                );
              },
            ),
    );
  }

  static Future<List<String>> articleAssets() {
    return _assetFuture ??= AssetManifest.loadFromAssetBundle(rootBundle).then(
        (manifest) => manifest
            .listAssets()
            .where((asset) => asset.startsWith('assets/articles/'))
            .toList(growable: false));
  }
}

class _LocalArticleImage extends StatelessWidget {
  const _LocalArticleImage({
    required this.imageTag,
    required this.searchText,
  });

  final String imageTag;
  final String searchText;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: ArticleHeroImage.articleAssets(),
      builder: (context, snapshot) {
        final asset = _bestAsset(snapshot.data ?? const <String>[]);
        if (asset.endsWith('.svg')) {
          return SvgPicture.asset(asset, fit: BoxFit.cover);
        }
        return Image.asset(asset, fit: BoxFit.cover);
      },
    );
  }

  String _bestAsset(List<String> assets) {
    final exact = ArticleConstants.assetForTag(imageTag);
    if (assets.contains(exact)) return exact;

    final words = _words('$imageTag $searchText');
    var best = '';
    var bestScore = 0;
    for (final asset in assets) {
      final file = asset.split('/').last.toLowerCase();
      var score = 0;
      for (final word in words) {
        if (file.contains(word)) score++;
      }
      if (score > bestScore) {
        best = asset;
        bestScore = score;
      }
    }
    if (bestScore > 0) return best;
    const fallback = 'assets/articles/hydration.jpg';
    if (assets.contains(fallback)) return fallback;
    return assets.isNotEmpty ? assets.first : exact;
  }

  List<String> _words(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length > 2)
        .toSet()
        .toList(growable: false);
  }
}
