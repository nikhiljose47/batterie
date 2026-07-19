import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import 'data/service_catalog.dart';

/// Scaffolded landing page for a service that hasn't been built yet.
/// Shows what the module will include so the hub feels complete while
/// each service is implemented one by one. Once a service gets a real
/// page, register it in `services_page.dart` → `_openService()` and this
/// scaffold stops being used for it.
class ServiceDetailPage extends StatelessWidget {
  const ServiceDetailPage({super.key, required this.service});

  final AppService service;

  @override
  Widget build(BuildContext context) {
    final accent = categoryAccent(service.category);
    final tint = categoryTint(service.category);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        scrolledUnderElevation: 0,
        title: Text(
          service.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: <Widget>[
          // Hero
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withOpacity(0.25)),
            ),
            child: Row(
              children: <Widget>[
                Text(service.emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        service.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        service.tagline,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Status chip
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceTint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: const Text(
                  '🚧 COMING SOON',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Planned features
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'WHAT IT WILL INCLUDE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textMuted,
              ),
            ),
          ),
          for (final feature in service.features)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outline.withOpacity(0.8)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: accent.withOpacity(0.7)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2A2E3B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
