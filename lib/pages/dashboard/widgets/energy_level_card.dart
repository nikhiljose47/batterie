import 'package:flutter/material.dart';

/// Energy level card that renders the value as a phone-style battery.
/// The fill, percent number, and status animate whenever [percent] changes.
class EnergyLevelCard extends StatefulWidget {
  const EnergyLevelCard({
    super.key,
    required this.label,
    required this.percent,
    required this.subtitle,
    required this.accentColor,
    required this.backgroundColor,
    required this.icon,
  });

  final String label;
  final double percent; // 0.0–1.0
  final String subtitle;
  final Color accentColor;
  final Color backgroundColor;
  final IconData icon;

  @override
  State<EnergyLevelCard> createState() => _EnergyLevelCardState();
}

class _EnergyLevelCardState extends State<EnergyLevelCard> {
  double _previousPercent = 0;
  _EnergyTrend _trend = _EnergyTrend.none;

  @override
  void didUpdateWidget(EnergyLevelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percent != widget.percent) {
      _previousPercent = oldWidget.percent;
      _trend = widget.percent > oldWidget.percent
          ? _EnergyTrend.gaining
          : _EnergyTrend.draining;
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.percent.clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(widget.icon, size: 15, color: widget.accentColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.accentColor,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _TrendBadge(trend: _trend, color: widget.accentColor),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: _previousPercent, end: target),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (context, animatedPercent, _) {
                return _BatteryGauge(
                  percent: animatedPercent,
                  accentColor: widget.accentColor,
                  charging: _trend == _EnergyTrend.gaining,
                );
              },
            ),
          ),
          if (widget.subtitle.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              widget.subtitle,
              style: TextStyle(
                fontSize: 11,
                color: widget.accentColor.withValues(alpha: 0.72),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

enum _EnergyTrend { none, gaining, draining }

/// Small ▲ / ▼ chip shown next to the label after an update.
class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.trend, required this.color});

  final _EnergyTrend trend;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (trend) {
        _EnergyTrend.none => const SizedBox.shrink(),
        _EnergyTrend.gaining => Icon(
            key: const ValueKey<String>('up'),
            Icons.arrow_drop_up_rounded,
            size: 20,
            color: color,
          ),
        _EnergyTrend.draining => Icon(
            key: const ValueKey<String>('down'),
            Icons.arrow_drop_down_rounded,
            size: 20,
            color: color.withValues(alpha: 0.7),
          ),
      },
    );
  }
}

/// Vertical phone-style battery: rounded body, top cap, animated fill,
/// percent readout inside, bolt overlay while charging (gaining energy).
class _BatteryGauge extends StatelessWidget {
  const _BatteryGauge({
    required this.percent,
    required this.accentColor,
    required this.charging,
  });

  final double percent;
  final Color accentColor;
  final bool charging;

  Color get _fillColor {
    if (percent <= 0.2) return const Color(0xFFE5484D); // critical red
    if (percent <= 0.4) return const Color(0xFFF5A623); // warning amber
    return accentColor;
  }

  @override
  Widget build(BuildContext context) {
    final pct = (percent * 100).round();

    return Center(
      child: AspectRatio(
        aspectRatio: 0.52,
        child: Column(
          children: <Widget>[
            // Battery cap
            FractionallySizedBox(
              widthFactor: 0.34,
              child: Container(
                height: 7,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.45),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ),
            ),
            // Battery body
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.45),
                    width: 2.5,
                  ),
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.all(3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: <Widget>[
                      // Animated fill rising from the bottom
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: percent.clamp(0.0, 1.0),
                          widthFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: <Color>[
                                  _fillColor,
                                  _fillColor.withValues(alpha: 0.75),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Percent readout + bolt
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (charging)
                              Icon(
                                Icons.bolt_rounded,
                                size: 18,
                                color: percent > 0.55
                                    ? Colors.white
                                    : _fillColor,
                              ),
                            Text(
                              '$pct%',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                color: percent > 0.55
                                    ? Colors.white
                                    : accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
