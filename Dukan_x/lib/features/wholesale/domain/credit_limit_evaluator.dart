/// Credit-limit enforcement modes.
///
/// Determines behavior when a bill exceeds the party's configured credit limit.
enum CreditMode {
  /// Reject the bill outright — persist nothing and return a limit-exceeded
  /// error naming the limit.
  hardBlock,

  /// Warn the operator (naming the limit) and let them proceed or cancel.
  /// The bill CAN be saved if the operator confirms.
  softWarning,
}

/// The result of evaluating a bill against a party's credit limit.
///
/// All money values are integer Paise (1/100th of a Rupee).
class CreditDecision {
  /// Whether the bill would cause the party to exceed their credit limit.
  final bool exceeded;

  /// The enforcement mode that was applied.
  final CreditMode mode;

  /// The configured credit limit in Paise. A value of 0 means "no limit
  /// configured" — the party is always allowed.
  final int limitPaise;

  /// The total outstanding after adding the current bill:
  /// `outstandingPaise + billPaise`.
  final int currentTotalPaise;

  /// A human-readable warning message when [exceeded] is true.
  /// Null when not exceeded.
  final String? warningMessage;

  const CreditDecision({
    required this.exceeded,
    required this.mode,
    required this.limitPaise,
    required this.currentTotalPaise,
    this.warningMessage,
  });
}

/// Evaluates whether a bill exceeds a party's credit limit.
///
/// All values are compared in integer Paise. The evaluator is a pure,
/// deterministic domain class with no side effects.
///
/// Rules:
/// - A [limitPaise] of 0 means "no limit configured" — always allow.
/// - exceeded ⇔ `(outstandingPaise + billPaise) > limitPaise` when
///   limitPaise > 0.
/// - In [CreditMode.hardBlock]: reject (persist nothing, return
///   limit-exceeded error naming the limit).
/// - In [CreditMode.softWarning]: warn (naming the limit) and let the
///   operator proceed or cancel.
class CreditLimitEvaluator {
  const CreditLimitEvaluator();

  /// Evaluates whether the combined outstanding + bill exceeds the limit.
  ///
  /// Parameters:
  /// - [mode]: The enforcement mode (hardBlock or softWarning).
  /// - [limitPaise]: The party's credit limit in Paise. 0 = no limit.
  /// - [outstandingPaise]: Current outstanding balance in Paise (>= 0).
  /// - [billPaise]: The current bill amount in Paise (>= 0).
  ///
  /// Returns a [CreditDecision] indicating whether the limit is exceeded,
  /// the enforcement mode, and an optional warning message.
  CreditDecision evaluate({
    required CreditMode mode,
    required int limitPaise,
    required int outstandingPaise,
    required int billPaise,
  }) {
    final currentTotalPaise = outstandingPaise + billPaise;

    // A limitPaise of 0 means "no limit configured" — always allow.
    if (limitPaise <= 0) {
      return CreditDecision(
        exceeded: false,
        mode: mode,
        limitPaise: limitPaise,
        currentTotalPaise: currentTotalPaise,
      );
    }

    final exceeded = currentTotalPaise > limitPaise;

    if (!exceeded) {
      return CreditDecision(
        exceeded: false,
        mode: mode,
        limitPaise: limitPaise,
        currentTotalPaise: currentTotalPaise,
      );
    }

    // Limit exceeded — build the appropriate warning message.
    final limitRupees = limitPaise ~/ 100;
    final limitFraction = limitPaise % 100;
    final totalRupees = currentTotalPaise ~/ 100;
    final totalFraction = currentTotalPaise % 100;

    final limitStr =
        '₹$limitRupees.${limitFraction.toString().padLeft(2, '0')}';
    final totalStr =
        '₹$totalRupees.${totalFraction.toString().padLeft(2, '0')}';

    final String message;
    switch (mode) {
      case CreditMode.hardBlock:
        message =
            'Credit limit exceeded. Limit: $limitStr, '
            'Outstanding + Bill: $totalStr. '
            'Bill cannot be saved.';
      case CreditMode.softWarning:
        message =
            'Warning: Credit limit will be exceeded. Limit: $limitStr, '
            'Outstanding + Bill: $totalStr. '
            'Proceed or cancel?';
    }

    return CreditDecision(
      exceeded: true,
      mode: mode,
      limitPaise: limitPaise,
      currentTotalPaise: currentTotalPaise,
      warningMessage: message,
    );
  }
}
