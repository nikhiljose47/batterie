/// Estimated physical and brain readiness at a point in time.
/// Both scores are on a 0–100 scale (not measured physiology — a heuristic).
class EnergyState {
  const EnergyState({
    required this.physical,
    required this.brain,
    required this.confidence,
  });

  /// Estimated physical readiness. 0 = depleted, 100 = peak.
  final int physical;

  /// Estimated brain / cognitive readiness. 0 = depleted, 100 = peak.
  final int brain;

  /// How reliable this estimate is. Starts at 0.55 from a baseline,
  /// and is lowered by each activity that has 'medium' or 'low' confidence.
  /// Range: 0.0–1.0.
  final double confidence;

  EnergyState copyWith({int? physical, int? brain, double? confidence}) {
    return EnergyState(
      physical: physical ?? this.physical,
      brain: brain ?? this.brain,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  String toString() =>
      'EnergyState(physical: $physical, brain: $brain, confidence: ${confidence.toStringAsFixed(2)})';
}
