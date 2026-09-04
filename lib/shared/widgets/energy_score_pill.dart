import 'package:flutter/material.dart';

class EnergyScorePill extends StatefulWidget {
  const EnergyScorePill({
    super.key,
    required this.score,
    this.height = 28,
    this.compact = false,
  });

  final int score;
  final double height;
  final bool compact;

  @override
  State<EnergyScorePill> createState() => _EnergyScorePillState();
}

class _EnergyScorePillState extends State<EnergyScorePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glare;

  @override
  void initState() {
    super.initState();
    _glare = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
  }

  @override
  void didUpdateWidget(covariant EnergyScorePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.score > oldWidget.score) {
      _glare.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _glare.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const sky = Color(0xFF0284C7);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        height: widget.height,
        padding: EdgeInsets.symmetric(horizontal: widget.compact ? 9 : 11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFF0F9FF), Color(0xFFDFF4FF)],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFBAE6FD)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: sky.withValues(alpha: 0.09),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: widget.compact ? 17 : 19,
                  height: widget.compact ? 17 : 19,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFBAE6FD),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt_rounded, size: 12, color: sky),
                ),
                const SizedBox(width: 5),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: widget.score.toDouble()),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text(
                    value.round().toString(),
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF075985),
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _glare,
                  builder: (context, _) {
                    final value = Curves.easeOutCubic.transform(_glare.value);
                    return FractionalTranslation(
                      translation: Offset(-1.4 + value * 2.8, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                Colors.white.withOpacity(0),
                                Colors.white.withOpacity(0.62),
                                Colors.white.withOpacity(0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
