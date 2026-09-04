class DailyScoreRules {
  const DailyScoreRules._();

  static const int appUseMinutesPerPoint = 5;
  static const int maxPointsPerFeature = 3;
  static const int serviceLogPoint = 1;
  static const int dayTrackAnyLogPoints = 1;
  static const int dayTrackAllLoggedPoints = 2;

  static int appUsePoints(int minutes) {
    return (minutes ~/ appUseMinutesPerPoint)
        .clamp(0, maxPointsPerFeature)
        .toInt();
  }

  static int serviceLogPoints(int count) {
    return (count * serviceLogPoint).clamp(0, maxPointsPerFeature).toInt();
  }

  static int dayTrackPoints({
    required int loggedCount,
    required int totalCount,
  }) {
    if (loggedCount <= 0 || totalCount <= 0) return 0;
    if (loggedCount >= totalCount) return dayTrackAllLoggedPoints;
    return dayTrackAnyLogPoints;
  }
}
