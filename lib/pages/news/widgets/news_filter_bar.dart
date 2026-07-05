import 'package:flutter/material.dart';

import '../../../constants/app_spacing.dart';

class NewsFilterBar extends StatelessWidget {
  const NewsFilterBar({
    super.key,
    required this.filters,
    required this.selectedFilter,
    required this.onSelected,
  });

  final List<String> filters;
  final String selectedFilter;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.filterBarHeight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.small),
        itemBuilder: (context, index) {
          final filter = filters[index];

          return ChoiceChip(
            label: Text(filter),
            selected: filter == selectedFilter,
            onSelected: (_) => onSelected(filter),
          );
        },
      ),
    );
  }
}
