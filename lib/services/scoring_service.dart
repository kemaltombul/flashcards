
class ScoringService {
  /// Determines if a user has learned a word based on implicit behavioral metrics.
  ///
  /// Inputs:
  /// - [timer]: The time in seconds taken to respond.
  /// - [isPopupOpened]: Whether the user opened the hint popup.
  ///
  /// Logic:
  /// 1. Grace Period (0s - 4s): Base Score is 1.0 (Perfect).
  /// 2. Linear Decay (4s - 8s): Score decreases linearly from 1.0 to 0.0.
  /// 3. Time Cut-off (> 8s): Base Score is 0.0.
  /// 4. Hint Penalty: If [isPopupOpened] is true, apply a 20% penalty.
  double calculateLearningScore(double timer, bool isPopupOpened) {
    double score;

    // 1. Calculate Base Score based on time
    if (timer <= 4.0) {
      // Grace Period: Perfect score for quick responses
      score = 1.0;
    } else if (timer > 4.0 && timer <= 8.0) {
      // Linear Decay: Score drops linearly from 1.0 to 0.0 as time approaches 8s
      // Formula: 1.0 - ((timer - 4) / (8 - 4))
      score = 1.0 - ((timer - 4.0) / 4.0);
    } else {
      // Time Cut-off: Too slow, score is 0.0
      score = 0.0;
    }

    // 2. Apply Hints Penalty
    if (isPopupOpened) {
      // Apply 20% penalty multiplier
      score *= 0.8;
    }

    // 3. Ensure bounds (Double check, though logic shouldn't produce < 0)
    if (score < 0.0) {
      score = 0.0;
    }

    return score;
  }
}
