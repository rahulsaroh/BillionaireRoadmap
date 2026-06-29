/// A timezone-aware validator for calculating streaks.
class StreakState {
  final int currentStreak;
  final int longestStreak;
  final int activeFreezesCount;
  final DateTime? lastCompletedDate; // UTC Time

  StreakState({
    required this.currentStreak,
    required this.longestStreak,
    required this.activeFreezesCount,
    this.lastCompletedDate,
  });

  StreakState copyWith({
    int? currentStreak,
    int? longestStreak,
    int? activeFreezesCount,
    DateTime? lastCompletedDate,
  }) {
    return StreakState(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      activeFreezesCount: activeFreezesCount ?? this.activeFreezesCount,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
    );
  }
}

class ValidationResult {
  final String action; // "INCREMENT", "NO_OP", "CONSUME_FREEZE", "RESET"
  final StreakState newState;
  final String logMessage;

  ValidationResult({
    required this.action,
    required this.newState,
    required this.logMessage,
  });
}

class StreakValidator {
  /// Evaluates the new streak state based on completion time and timezone offset.
  static ValidationResult validateStreak({
    required DateTime completionTimeUtc,
    required Duration timezoneOffset,
    required StreakState currentState,
  }) {
    // 1. Resolve absolute UTC timestamp to the user's local calendar date
    final localToday = completionTimeUtc.add(timezoneOffset);
    final localTodayDateOnly = DateTime(localToday.year, localToday.month, localToday.day);

    // If starting a fresh streak
    if (currentState.lastCompletedDate == null) {
      final updatedState = currentState.copyWith(
        currentStreak: 1,
        longestStreak: currentState.longestStreak < 1 ? 1 : currentState.longestStreak,
        lastCompletedDate: localTodayDateOnly,
      );
      return ValidationResult(
        action: "INCREMENT",
        newState: updatedState,
        logMessage: "Streak initiated. Streak set to 1 day.",
      );
    }

    // Resolve stored last completed date
    final localLastDate = currentState.lastCompletedDate!.add(timezoneOffset);
    final localLastDateOnly = DateTime(localLastDate.year, localLastDate.month, localLastDate.day);

    // Calculate calendar date difference
    final dayDifference = localTodayDateOnly.difference(localLastDateOnly).inDays;

    if (dayDifference == 0) {
      // Case A: User completed another task on the same calendar day (No-Op)
      return ValidationResult(
        action: "NO_OP",
        newState: currentState,
        logMessage: "Task completed on the same calendar day. No-Op.",
      );
    } else if (dayDifference == 1) {
      // Case B: Streak continued consecutively (Increment)
      final newStreak = currentState.currentStreak + 1;
      final updatedState = currentState.copyWith(
        currentStreak: newStreak,
        longestStreak: newStreak > currentState.longestStreak ? newStreak : currentState.longestStreak,
        lastCompletedDate: localTodayDateOnly,
      );
      return ValidationResult(
        action: "INCREMENT",
        newState: updatedState,
        logMessage: "Consecutive day completed! Streak incremented to $newStreak.",
      );
    } else {
      // Case C: User missed one or more days
      final missedDays = dayDifference - 1;
      final availableFreezes = currentState.activeFreezesCount;

      if (availableFreezes >= missedDays) {
        // Safe: Consumes freeze to protect streak
        final newFreezesCount = availableFreezes - missedDays;
        final newStreak = currentState.currentStreak + 1;
        final updatedState = currentState.copyWith(
          currentStreak: newStreak,
          longestStreak: newStreak > currentState.longestStreak ? newStreak : currentState.longestStreak,
          activeFreezesCount: newFreezesCount,
          lastCompletedDate: localTodayDateOnly,
        );
        return ValidationResult(
          action: "CONSUME_FREEZE",
          newState: updatedState,
          logMessage: "Missed $missedDays days. Consumed $missedDays Streak Freeze(s). Streak preserved at $newStreak.",
        );
      } else {
        // Streak broken: Reset to 1
        final updatedState = currentState.copyWith(
          currentStreak: 1,
          lastCompletedDate: localTodayDateOnly,
        );
        return ValidationResult(
          action: "RESET",
          newState: updatedState,
          logMessage: "Missed $missedDays days with insufficient freezes. Streak reset to 1.",
        );
      }
    }
  }
}
