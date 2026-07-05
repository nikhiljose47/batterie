import 'package:flutter/material.dart';

import '../../../constants/app_spacing.dart';

class ArticleHeroImage extends StatelessWidget {
  const ArticleHeroImage({
    super.key,
    required this.imageUrl,
    this.height = AppSpacing.detailImageHeight,
  });

  final String imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child:
                const Center(child: Icon(Icons.image_not_supported_outlined)),
          );
        },
      ),
    );
  }
}
