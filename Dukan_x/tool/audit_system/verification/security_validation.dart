// AUDIT_SYSTEM — SECURITY & VALIDATION CLASSIFIERS (Task 19.1)
//
// Pure decision logic for the per-screen verification of the Security and
// Validation audit categories. Three independent classifiers live here:
//
//   1. Auth-session (Req 12.1) — a tenant-data action (create/read/update/
//      delete) is permitted IF AND ONLY IF a valid, unexpired Cognito-issued
//      token is present. An action that is invocable without an authenticated
//      session flags the Screen as non-compliant.
//
//   2. Input-validation (Req 12.3, 12.5) — a user-editable field value is
//      accepted for submit/persist IF AND ONLY IF it satisfies every rule in
//      its rule set (required/optional, data type, allowed range or format,
//      maximum length). On failure the submit/persist is blocked, the
//      underlying data is left unchanged, and a message naming the failing
//      field and the reason is produced.
//
//   3. Sanitization (Req 12.4) — neutralizes HTML/script and query control
//      characters in a user-supplied string. Neutralization is performed by
//      REMOVING the dangerous characters, which makes the sanitizer IDEMPOTENT:
//      sanitize(sanitize(x)) == sanitize(x) for every input.
//
// The underlying security mechanisms (Cognito token issuance/verification, the
// RBAC role model, server-side authorization) are owned by the sibling
// `rbac-login-integration` spec; that spec is referenced conceptually but is
// NOT imported here. These classifiers only model the per-screen verification
// that those mechanisms' rules were applied correctly.
//
// NOTE: The server-side tenant/role authorization classifier (Req 12.7,
// Property 38) and the workflow-error classifier (Req 13.5, Property 39) are
// implemented below in the SERVER-SIDE AUTHORIZATION (Section 4) and
// WORKFLOW-ERROR (Section 5) sections (Task 19.5).
//
// This file is PURE, dependency-light Dart (only `dart:core`), so it imports
// cleanly into `flutter_test` + `dartproptest` VM suites, matching the rest of
// the Audit_System governance core.
//
// Part of: per-screen-business-type-audit-remediation (Tasks 19.1, 19.5)
// _Requirements: 12.1, 12.3, 12.4, 12.5, 12.7, 13.5_

// ===========================================================================
// SECTION 1 — AUTH-SESSION CLASSIFIER (Req 12.1)
// ===========================================================================

/// The state of the Cognito-issued session token, modeled as a pure value so
/// the classifier can be exercised exhaustively over every possibility.
enum SessionTokenState {
  /// A valid, unexpired Cognito-issued token is present. This is the ONLY state
  /// under which a tenant-data action is permitted (Req 12.1).
  validUnexpired,

  /// A Cognito token is present but has expired; it does not authenticate the
  /// session.
  expired,

  /// No token is present — the session is unauthenticated.
  absent,
}

/// A tenant-data operation: the four actions that create, read, update, or
/// delete tenant data and therefore require an authenticated session (Req 12.1).
enum TenantDataOperation { create, read, update, delete }

/// The outcome of classifying a single observed tenant-data action against the
/// session token state.
///
/// [permitted] is the rule's verdict (what the Screen SHOULD allow), while
/// [invocable] is the observed behavior (what the Screen actually allowed). The
/// Screen is compliant only when the two agree for every action.
class AuthSessionResult {
  AuthSessionResult({
    required this.operation,
    required this.tokenState,
    required this.invocable,
  });

  /// The tenant-data operation that was observed.
  final TenantDataOperation operation;

  /// The session token state in effect when the action was invoked.
  final SessionTokenState tokenState;

  /// Observed behavior: whether the Screen actually allowed the action to be
  /// invoked under [tokenState].
  final bool invocable;

  /// The rule's verdict: a tenant-data action is permitted IF AND ONLY IF a
  /// valid, unexpired token is present (Req 12.1).
  bool get permitted => tokenState == SessionTokenState.validUnexpired;

  /// True iff observed invocability matches the required permission — the
  /// action is invocable exactly when (and only when) it is permitted.
  bool get compliant => invocable == permitted;

  /// True iff the Screen is non-compliant: most importantly, an action that is
  /// invocable without an authenticated session (Req 12.1), but also an action
  /// wrongly blocked while authenticated.
  bool get screenNonCompliant => !compliant;

  @override
  String toString() =>
      'AuthSessionResult(${operation.name}, ${tokenState.name}, '
      'invocable=$invocable, ${compliant ? 'compliant' : 'NON-COMPLIANT'})';
}

/// Pure classifier for the authenticated-session requirement on tenant data
/// (Req 12.1).
///
/// The rule is total over [SessionTokenState]: a tenant-data action is
/// permitted **if and only if** the token state is [SessionTokenState.validUnexpired].
class AuthSessionClassifier {
  const AuthSessionClassifier();

  /// True iff a tenant-data action is permitted under [tokenState] — i.e. a
  /// valid, unexpired Cognito-issued token is present (Req 12.1).
  bool isPermitted(SessionTokenState tokenState) =>
      tokenState == SessionTokenState.validUnexpired;

  /// Classify an observed tenant-data action invocation.
  ///
  /// * [operation]  — which CRUD action was observed.
  /// * [tokenState] — the session token state when the action was invoked.
  /// * [invocable]  — observed behavior: whether the Screen allowed invocation.
  AuthSessionResult classify({
    required TenantDataOperation operation,
    required SessionTokenState tokenState,
    required bool invocable,
  }) {
    return AuthSessionResult(
      operation: operation,
      tokenState: tokenState,
      invocable: invocable,
    );
  }

  /// True iff the observed action is compliant — invocable exactly when a valid,
  /// unexpired token is present.
  bool isCompliant({
    required TenantDataOperation operation,
    required SessionTokenState tokenState,
    required bool invocable,
  }) {
    return classify(
      operation: operation,
      tokenState: tokenState,
      invocable: invocable,
    ).compliant;
  }
}

// ===========================================================================
// SECTION 2 — INPUT-VALIDATION CLASSIFIER (Req 12.3, 12.5)
// ===========================================================================

/// The data type a field value must conform to. Used by [DataTypeRule] to
/// decide whether a provided value is parseable as the expected type.
enum FieldDataType {
  /// Any text; always parseable (length/format rules may still constrain it).
  text,

  /// A whole number (e.g. "42", "-7").
  integer,

  /// A decimal number (e.g. "3.14", "10").
  decimal,

  /// A boolean literal ("true" or "false", case-insensitive).
  boolean,
}

/// A single validation rule applied to a field value. A rule returns `null`
/// when the value satisfies it, or a human-readable reason when it fails.
///
/// Content rules ([DataTypeRule], [RangeRule], [MaxLengthRule], [FormatRule])
/// are applied only when a value is present; the presence requirement itself is
/// modeled by [FieldRuleSet.required].
abstract class InputRule {
  const InputRule();

  /// A short, stable identifier for the rule (used in failure messages).
  String get name;

  /// Returns `null` if [value] satisfies this rule, otherwise a human-readable
  /// reason describing why it failed. [value] is the trimmed, non-empty field
  /// value (content rules are not invoked for absent/empty values).
  String? failureReason(String value);
}

/// Requires the field value to parse as [type] (Req 12.3 — data type).
class DataTypeRule extends InputRule {
  const DataTypeRule(this.type);

  /// The data type the value must conform to.
  final FieldDataType type;

  @override
  String get name => 'dataType';

  @override
  String? failureReason(String value) {
    switch (type) {
      case FieldDataType.text:
        return null;
      case FieldDataType.integer:
        return int.tryParse(value) == null ? 'must be a whole number' : null;
      case FieldDataType.decimal:
        return double.tryParse(value) == null ? 'must be a number' : null;
      case FieldDataType.boolean:
        final lower = value.toLowerCase();
        return (lower == 'true' || lower == 'false')
            ? null
            : 'must be true or false';
    }
  }
}

/// Requires a numeric value to fall within an inclusive range (Req 12.3 —
/// allowed value range). At least one of [min] or [max] should be provided.
class RangeRule extends InputRule {
  const RangeRule({this.min, this.max});

  /// Inclusive lower bound, or `null` for no lower bound.
  final num? min;

  /// Inclusive upper bound, or `null` for no upper bound.
  final num? max;

  @override
  String get name => 'range';

  @override
  String? failureReason(String value) {
    final parsed = num.tryParse(value);
    if (parsed == null) return 'must be a number';
    if (min != null && parsed < min!) return 'must be at least $min';
    if (max != null && parsed > max!) return 'must be at most $max';
    return null;
  }
}

/// Requires the value's length to not exceed [maxLength] (Req 12.3 — maximum
/// length).
class MaxLengthRule extends InputRule {
  const MaxLengthRule(this.maxLength);

  /// The maximum allowed number of characters.
  final int maxLength;

  @override
  String get name => 'maxLength';

  @override
  String? failureReason(String value) {
    return value.length > maxLength
        ? 'must be at most $maxLength characters'
        : null;
  }
}

/// Requires the value to match a [pattern] (Req 12.3 — allowed format).
class FormatRule extends InputRule {
  FormatRule(this.pattern, {String? description})
    : description = description ?? 'must match the required format';

  /// The pattern the value must match in full.
  final RegExp pattern;

  /// Human-readable description of the expected format.
  final String description;

  @override
  String get name => 'format';

  @override
  String? failureReason(String value) {
    final match = pattern.firstMatch(value);
    final matchesWhole =
        match != null && match.start == 0 && match.end == value.length;
    return matchesWhole ? null : description;
  }
}

/// A field together with its complete rule set (Req 12.3): whether it is
/// required, and the content rules applied when a value is present.
class FieldRuleSet {
  const FieldRuleSet({
    required this.field,
    this.required = false,
    this.rules = const [],
  });

  /// The user-visible field name, used to identify the field in failure
  /// messages (Req 12.5).
  final String field;

  /// Whether a value must be supplied. When `false`, an absent/empty value is
  /// accepted and content rules are skipped (optional field).
  final bool required;

  /// The content rules applied only when a value is present.
  final List<InputRule> rules;
}

/// A single rule failure, identifying the failing field and the reason
/// (Req 12.5).
class ValidationFailure {
  const ValidationFailure({
    required this.field,
    required this.rule,
    required this.reason,
  });

  /// The field that failed validation.
  final String field;

  /// The name of the rule that failed.
  final String rule;

  /// The human-readable reason the value was rejected.
  final String reason;

  /// A user-visible message naming the field and the reason (Req 12.5).
  String get message => '$field: $reason';

  @override
  String toString() => 'ValidationFailure($field, $rule: $reason)';
}

/// The outcome of validating one field value against its [FieldRuleSet].
///
/// The value is [accepted] iff every rule passes; otherwise the submit/persist
/// is [blocked], the underlying data is left unchanged (the caller MUST NOT
/// apply a blocked value), and [failures] carries one message per failing rule
/// (Req 12.5).
class FieldValidationResult {
  FieldValidationResult({required this.field, required this.failures});

  /// The field that was validated.
  final String field;

  /// The list of rule failures; empty iff the value was accepted.
  final List<ValidationFailure> failures;

  /// True iff every rule passed and the value may be submitted/persisted.
  bool get accepted => failures.isEmpty;

  /// True iff the submit/persist MUST be blocked (Req 12.5).
  bool get blocked => failures.isNotEmpty;

  /// The user-visible messages naming each failing field and reason (Req 12.5).
  List<String> get messages => [for (final f in failures) f.message];

  @override
  String toString() => accepted
      ? 'FieldValidationResult($field, accepted)'
      : 'FieldValidationResult($field, blocked: ${messages.join('; ')})';
}

/// Pure classifier for user-editable input validation (Req 12.3, 12.5).
///
/// A field value is accepted **if and only if** it satisfies every rule in its
/// rule set. On failure the result reports [FieldValidationResult.blocked] and
/// carries a message naming the failing field and reason; the caller is
/// responsible for leaving the underlying data unchanged.
class InputValidationClassifier {
  const InputValidationClassifier();

  /// Whether [value] represents "no value provided" for [ruleSet] purposes — a
  /// `null` or whitespace-only string.
  bool _isAbsent(String? value) => value == null || value.trim().isEmpty;

  /// Validate a single field [value] against its [ruleSet].
  ///
  /// * If the field is required and no value is provided → a `required`
  ///   failure.
  /// * If the field is optional and no value is provided → accepted (content
  ///   rules are skipped).
  /// * Otherwise every content rule is applied and all failures collected.
  FieldValidationResult validate(FieldRuleSet ruleSet, String? value) {
    final failures = <ValidationFailure>[];

    if (_isAbsent(value)) {
      if (ruleSet.required) {
        failures.add(
          ValidationFailure(
            field: ruleSet.field,
            rule: 'required',
            reason: 'is required',
          ),
        );
      }
      return FieldValidationResult(field: ruleSet.field, failures: failures);
    }

    final trimmed = value!.trim();
    for (final rule in ruleSet.rules) {
      final reason = rule.failureReason(trimmed);
      if (reason != null) {
        failures.add(
          ValidationFailure(
            field: ruleSet.field,
            rule: rule.name,
            reason: reason,
          ),
        );
      }
    }
    return FieldValidationResult(field: ruleSet.field, failures: failures);
  }

  /// True iff [value] satisfies every rule in [ruleSet] and may be
  /// submitted/persisted (Req 12.3).
  bool isAccepted(FieldRuleSet ruleSet, String? value) =>
      validate(ruleSet, value).accepted;

  /// Validate a form: a map of field values keyed by field name against their
  /// rule sets. The form is accepted only when every field is accepted; all
  /// failures across all fields are collected (Req 12.5).
  List<FieldValidationResult> validateAll(
    Iterable<FieldRuleSet> ruleSets,
    Map<String, String?> values,
  ) {
    return [
      for (final ruleSet in ruleSets) validate(ruleSet, values[ruleSet.field]),
    ];
  }

  /// True iff every field in the form is accepted.
  bool allAccepted(
    Iterable<FieldRuleSet> ruleSets,
    Map<String, String?> values,
  ) {
    return validateAll(ruleSets, values).every((r) => r.accepted);
  }
}

// ===========================================================================
// SECTION 3 — INJECTION SANITIZER (Req 12.4)
// ===========================================================================

/// Pure sanitizer that neutralizes injection payloads in user-supplied strings
/// (Req 12.4).
///
/// Neutralization is performed by REMOVING the dangerous characters rather than
/// escaping them. Removal guarantees two properties:
///
///   * The output contains no active HTML/script payload (no `<`, `>`, `&`) and
///     no query control character (no quotes, backtick, semicolon, backslash,
///     or NUL).
///   * The sanitizer is IDEMPOTENT: because the output never contains a
///     forbidden character, applying [sanitize] again removes nothing, so
///     `sanitize(sanitize(x)) == sanitize(x)` for every input.
///
/// (Escaping would break idempotence — e.g. `&` → `&amp;` → `&amp;amp;`.)
class InjectionSanitizer {
  const InjectionSanitizer();

  /// The Unicode code points removed during sanitization.
  ///
  /// HTML/script: `<` (0x3C), `>` (0x3E), `&` (0x26).
  /// Query control: `"` (0x22), `'` (0x27), `` ` `` (0x60), `;` (0x3B),
  /// `\` (0x5C), and the NUL byte (0x00).
  static const Set<int> forbiddenCodePoints = {
    0x00, // NUL
    0x22, // "
    0x26, // &
    0x27, // '
    0x3B, // ;
    0x3C, // <
    0x3E, // >
    0x5C, // \
    0x60, // `
  };

  /// Return [input] with every forbidden character removed (Req 12.4).
  ///
  /// The result contains no HTML/script payload or query control character and
  /// is stable under re-application (idempotent).
  String sanitize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (!forbiddenCodePoints.contains(rune)) {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// True iff [value] is already sanitized — it contains no forbidden
  /// character. Equivalent to `sanitize(value) == value`.
  bool isSanitized(String value) =>
      !value.runes.any(forbiddenCodePoints.contains);
}

// ===========================================================================
// SECTION 4 — SERVER-SIDE AUTHORIZATION (Task 19.5, Req 12.7)
// ===========================================================================

/// A server-side data action request, modeled as a pure value so the
/// authorization rule can be exercised exhaustively (Req 12.7, Property 38).
///
/// A request is described by the role it requires, the roles the authenticated
/// user actually holds, the tenant the user is authenticated against, and the
/// tenant that owns the targeted records.
class ServerAuthorizationRequest {
  const ServerAuthorizationRequest({
    required this.requiredRole,
    required this.userRoles,
    required this.authTenant,
    required this.recordTenant,
  });

  /// The RBAC role the backend requires to perform this data action.
  final String requiredRole;

  /// The roles the authenticated user actually holds (from Cognito groups or
  /// claims).
  final Set<String> userRoles;

  /// The tenant the request is authenticated against (the caller's own tenant).
  final String authTenant;

  /// The tenant that owns the records the request is targeting.
  final String recordTenant;

  /// True iff the user holds the role required for this action.
  bool get roleHeld => userRoles.contains(requiredRole);

  /// True iff the targeted records belong to the authenticated user's tenant.
  bool get sameTenant => recordTenant == authTenant;

  /// True iff the request targets another tenant's records (Req 12.7).
  bool get crossTenant => !sameTenant;
}

/// The outcome of classifying an observed server-side authorization decision
/// against the required rule (Req 12.7, Property 38).
///
/// [authorized] is the rule's verdict (what the backend SHOULD allow), while
/// [recordsReturned] is the observed behavior (how many target-tenant records
/// the backend actually returned). The backend is compliant only when the
/// verdict is honored AND a denied request leaks zero data.
class ServerAuthorizationResult {
  ServerAuthorizationResult({
    required this.request,
    required this.recordsReturned,
  });

  /// The data action request that was evaluated.
  final ServerAuthorizationRequest request;

  /// Observed behavior: the number of target-tenant records the backend
  /// actually returned for this request.
  final int recordsReturned;

  /// The rule's verdict: the action is authorized **if and only if** the user
  /// holds the required role AND the records belong to the authenticated user's
  /// tenant (Req 12.7).
  bool get authorized => request.roleHeld && request.sameTenant;

  /// True iff a cross-tenant request leaked data — records were returned even
  /// though the request targeted another tenant (Req 12.7). This is the most
  /// severe non-compliance and MUST never happen.
  bool get crossTenantLeak => request.crossTenant && recordsReturned > 0;

  /// True iff the backend honored the rule: a denied request returned zero
  /// data. (When authorized, returning the matching records is expected, so the
  /// count is not constrained here.)
  bool get compliant => authorized || recordsReturned == 0;

  /// True iff the backend behaved non-compliantly — it returned data for a
  /// request it should have rejected (Req 12.7).
  bool get backendNonCompliant => !compliant;

  @override
  String toString() =>
      'ServerAuthorizationResult(${request.requiredRole}, '
      'auth=${request.authTenant}, record=${request.recordTenant}, '
      '${authorized ? 'authorized' : 'denied'}, '
      'returned=$recordsReturned, '
      '${compliant ? 'compliant' : 'NON-COMPLIANT'})';
}

/// Pure classifier for server-side tenant/role authorization (Req 12.7).
///
/// The rule is total over `(requiredRole, userRoles, authTenant, recordTenant)`:
/// a data action is authorized **if and only if** the user holds the required
/// role AND `recordTenant == authTenant`. A cross-tenant request
/// (`recordTenant != authTenant`) is rejected with ZERO target-tenant data
/// returned, even when the role would otherwise permit the action.
class ServerAuthorizationClassifier {
  const ServerAuthorizationClassifier();

  /// True iff the action described by [request] is authorized — the user holds
  /// the required role AND the records belong to the authenticated user's
  /// tenant (Req 12.7).
  bool isAuthorized(ServerAuthorizationRequest request) =>
      request.roleHeld && request.sameTenant;

  /// Classify an observed authorization decision.
  ///
  /// * [request]         — the role/tenant description of the data action.
  /// * [recordsReturned] — observed behavior: how many target-tenant records
  ///   the backend actually returned.
  ServerAuthorizationResult classify({
    required ServerAuthorizationRequest request,
    required int recordsReturned,
  }) {
    return ServerAuthorizationResult(
      request: request,
      recordsReturned: recordsReturned,
    );
  }

  /// True iff the observed decision is compliant — the backend authorized
  /// exactly when permitted and a denied request leaked zero data (Req 12.7).
  bool isCompliant({
    required ServerAuthorizationRequest request,
    required int recordsReturned,
  }) {
    return classify(
      request: request,
      recordsReturned: recordsReturned,
    ).compliant;
  }
}

// ===========================================================================
// SECTION 5 — WORKFLOW-ERROR CLASSIFIER (Task 19.5, Req 13.5)
// ===========================================================================

/// A workflow step that has failed, together with the user-entered input that
/// was present when it failed (Req 13.5, Property 39).
///
/// This models the truth the Screen must preserve and surface: which step
/// failed, what the user had typed, and what corrective action resolves it.
class WorkflowStepFailure {
  const WorkflowStepFailure({
    required this.failedStep,
    required this.correctiveAction,
    required this.userInput,
  });

  /// The name of the workflow step that failed.
  final String failedStep;

  /// The corrective action the user should take to resolve the failure.
  final String correctiveAction;

  /// The user-entered input present when the step failed, keyed by field name.
  final Map<String, String> userInput;
}

/// The behavior a Screen actually exhibited after a workflow step failed
/// (Req 13.5, Property 39).
///
/// The Screen is compliant only when its observed error display names the
/// failed step and a corrective action, retains the user's input unchanged, and
/// leaves the workflow in a resumable state.
class WorkflowErrorObservation {
  const WorkflowErrorObservation({
    required this.displayedStep,
    required this.displayedCorrectiveAction,
    required this.retainedInput,
    required this.canRetryWithoutReentry,
  });

  /// The failed-step name shown in the Screen's error message (empty if none).
  final String displayedStep;

  /// The corrective action shown in the Screen's error message (empty if none).
  final String displayedCorrectiveAction;

  /// The user input the Screen retained after the failure, keyed by field name.
  final Map<String, String> retainedInput;

  /// Observed behavior: whether the user can retry from the current state
  /// without re-entering data.
  final bool canRetryWithoutReentry;
}

/// The outcome of classifying a Screen's response to a failed workflow step
/// (Req 13.5, Property 39).
class WorkflowErrorResult {
  WorkflowErrorResult({required this.failure, required this.observation});

  /// The workflow step failure (the truth the Screen must preserve and surface).
  final WorkflowStepFailure failure;

  /// The behavior the Screen actually exhibited after the failure.
  final WorkflowErrorObservation observation;

  /// True iff the displayed error identifies the failed step (Req 13.5).
  bool get identifiesStep =>
      observation.displayedStep == failure.failedStep &&
      observation.displayedStep.isNotEmpty;

  /// True iff the displayed error names a non-empty corrective action
  /// (Req 13.5).
  bool get namesCorrectiveAction =>
      observation.displayedCorrectiveAction == failure.correctiveAction &&
      observation.displayedCorrectiveAction.isNotEmpty;

  /// True iff every field of the user's input was retained unchanged — same
  /// keys and same values (Req 13.5).
  bool get inputRetained =>
      _mapsEqual(failure.userInput, observation.retainedInput);

  /// True iff the workflow is left in a resumable state — the user can retry
  /// without re-entering data (Req 13.5).
  bool get resumable => observation.canRetryWithoutReentry;

  /// True iff the Screen handled the failure compliantly: it names the failed
  /// step and a corrective action, retains all input unchanged, and leaves a
  /// resumable state (Req 13.5).
  bool get compliant =>
      identifiesStep && namesCorrectiveAction && inputRetained && resumable;

  /// True iff the Screen mishandled the failure (Req 13.5).
  bool get screenNonCompliant => !compliant;

  static bool _mapsEqual(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() =>
      'WorkflowErrorResult(step=${failure.failedStep}, '
      'identifiesStep=$identifiesStep, '
      'namesCorrectiveAction=$namesCorrectiveAction, '
      'inputRetained=$inputRetained, resumable=$resumable, '
      '${compliant ? 'compliant' : 'NON-COMPLIANT'})';
}

/// Pure classifier for the workflow-error requirement (Req 13.5).
///
/// When a workflow step fails, the Screen is compliant **if and only if** its
/// observed response (1) identifies the failed step, (2) names the corrective
/// action, (3) retains all user-entered input unchanged, and (4) leaves the
/// workflow in a state from which the user can retry without re-entering data.
class WorkflowErrorClassifier {
  const WorkflowErrorClassifier();

  /// Classify a Screen's [observation] of a workflow step [failure].
  WorkflowErrorResult classify({
    required WorkflowStepFailure failure,
    required WorkflowErrorObservation observation,
  }) {
    return WorkflowErrorResult(failure: failure, observation: observation);
  }

  /// True iff the Screen handled the [failure] compliantly given its
  /// [observation] (Req 13.5).
  bool isCompliant({
    required WorkflowStepFailure failure,
    required WorkflowErrorObservation observation,
  }) {
    return classify(failure: failure, observation: observation).compliant;
  }
}
