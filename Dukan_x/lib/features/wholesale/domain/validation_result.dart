/// Sealed validation result for the wholesale domain layer.
///
/// Used by [MoqValidator], [UnitConverter], and other domain validators
/// to express success/failure in a type-safe manner.
sealed class ValidationResult {
  const ValidationResult();

  /// Whether the validation succeeded.
  bool get isValid => this is ValidationSuccess;

  /// Whether the validation failed.
  bool get isInvalid => this is ValidationFailure;
}

/// Validation passed — the input is acceptable.
class ValidationSuccess extends ValidationResult {
  const ValidationSuccess();
}

/// Validation failed — includes a human-readable reason.
class ValidationFailure extends ValidationResult {
  /// A short, human-readable description of why validation failed.
  final String reason;

  const ValidationFailure(this.reason);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidationFailure &&
          runtimeType == other.runtimeType &&
          reason == other.reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'ValidationFailure($reason)';
}
