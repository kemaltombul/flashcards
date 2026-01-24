class TelemetryData {
  final int? id;
  final int wordId;
  final int sessionId;
  final int timestamp;
  
  // Interaction Metrics
  final int durationMs;
  final bool popupOpened;
  final int popupDurationMs;
  final String actionType; // 'next', 'prev', 'restart', 'close'

  // Context Metrics
  final int wordLength;
  final int sessionStepIndex;
  final int totalViewCount;
  final int? hoursSinceLastView;

  // Verification Label
  final double currentAlgoScore;
  final int? userRating; // 1-6, optional
  final int? actualMastery; // Reserved for future use

  TelemetryData({
    this.id,
    required this.wordId,
    required this.sessionId,
    required this.timestamp,
    required this.durationMs,
    required this.popupOpened,
    required this.popupDurationMs,
    required this.actionType,
    required this.wordLength,
    required this.sessionStepIndex,
    required this.totalViewCount,
    this.hoursSinceLastView,
    required this.currentAlgoScore,
    this.userRating,
    this.actualMastery,
  });

  Map<String, dynamic> toMap() {
    return {
      'word_id': wordId,
      'session_id': sessionId,
      'timestamp': timestamp,
      'duration_ms': durationMs,
      'popup_opened': popupOpened ? 1 : 0,
      'popup_duration_ms': popupDurationMs,
      'action_type': actionType,
      'word_length': wordLength,
      'session_step_index': sessionStepIndex,
      'total_view_count': totalViewCount,
      'hours_since_last_view': hoursSinceLastView,
      'current_algo_score': currentAlgoScore,
      'user_rating': userRating,
      'actual_mastery': actualMastery,
    };
  }

  @override
  String toString() {
    return 'TelemetryData(wordId: $wordId, score: $currentAlgoScore, rating: $userRating)';
  }
}
