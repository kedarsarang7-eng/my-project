// AUDIT_SYSTEM — BACKEND-INTEGRATION VERIFICATION CLASSIFIERS (Task 18.1)
//
// Pure decision logic for the Backend Integration audit category. This file
// implements two of that category's classifiers:
//
//   1. Backend-source integrity (Req 11.1, 11.2 / Property 30): every data read
//      and write a Screen performs MUST resolve to Backend_Services. The
//      category is marked FAIL if and only if at least one read or write
//      resolves to a mock, stub, hardcoded, or in-memory fixture, and each such
//      occurrence produces a finding identifying the Screen, the operation, and
//      the non-Backend_Services source.
//
//   2. DynamoDB access-pattern compliance (Req 11.3 / Property 31): a DynamoDB
//      access PASSES if and only if it specifies a partition key (and a sort key
//      wherever the table or index defines one), every query filtered on a
//      non-key attribute is served by a defined GSI, and zero access paths use a
//      Scan operation.
//
// The remaining Backend Integration classifiers are implemented in SECTION 3
// (Task 18.4 / Properties 32–34):
//
//   3. S3 presigned-URL/bucket exposure (Req 11.4 / Property 32): an S3 upload
//      or download PASSES if and only if it is performed through a presigned URL
//      with an expiry of at most 900 seconds and the referenced bucket has
//      neither public read nor public write access.
//
//   4. SQS dead-letter-queue configuration (Req 11.7 / Property 33): an SQS
//      queue PASSES if and only if a dead-letter queue is configured with a
//      maxReceiveCount between 1 and 10 (inclusive) and messages exceeding
//      maxReceiveCount are routed to the dead-letter queue.
//
//   5. REST→Lambda route mapping (Req 11.8 / Property 34): a Screen's REST calls
//      PASS if and only if every call maps to a defined API Gateway route backed
//      by a Lambda handler; zero calls target an undefined or unbacked route.
//
// This file is deliberately structured as a set of independent descriptor +
// result + classifier triples.
//
// This file is PURE, dependency-light Dart (only `dart:core`), so it imports
// cleanly into `flutter_test` + `dartproptest` VM suites, matching the rest of
// the Audit_System governance core.
//
// Part of: per-screen-business-type-audit-remediation (Task 18.1, 18.4)
// _Requirements: 11.1, 11.2, 11.3, 11.4, 11.7, 11.8_

// ===========================================================================
// SECTION 1 — Backend-source integrity (Req 11.1, 11.2 / Property 30)
// ===========================================================================

/// The data layer a Screen's read or write call site resolves to.
///
/// Exactly one value — [backendServices] — is compliant. Every other value is a
/// non-Backend_Services source whose presence fails the Backend Integration
/// category (Req 11.1, 11.2).
enum BackendSource {
  /// The remote AWS integration surface (API Gateway, Lambda, DynamoDB, S3,
  /// SNS, SQS). The only compliant source for a read or write.
  backendServices,

  /// A test/dev mock object standing in for a real backend client.
  mock,

  /// A stubbed implementation returning canned responses.
  stub,

  /// Hardcoded literal data baked into the Screen's source.
  hardcoded,

  /// An in-memory fixture (e.g. a local list/map) with no backing service.
  inMemory,
}

/// Whether a backend call site is a read or a write. Both are held to the same
/// integrity bar; modeling the kind keeps descriptors self-describing and lets
/// findings name the operation precisely (Req 11.2).
enum BackendOperationKind { read, write }

extension BackendSourceX on BackendSource {
  /// True iff this source is the compliant Backend_Services surface.
  bool get isBackendServices => this == BackendSource.backendServices;

  /// True iff this source is a non-Backend_Services fixture (mock/stub/
  /// hardcoded/in-memory) — i.e. an integrity violation (Req 11.1).
  bool get isNonBackendFixture => !isBackendServices;
}

/// A single data read/write call site observed on a Screen, together with the
/// data source it actually resolves to.
///
/// This is the unit the [BackendSourceClassifier] inspects: an operation is
/// compliant iff its [resolvedSource] is [BackendSource.backendServices].
class BackendOperation {
  BackendOperation({
    required this.kind,
    required this.resolvedSource,
    this.screenPath,
    this.description,
  });

  /// Whether this is a read or a write operation.
  final BackendOperationKind kind;

  /// The data source the operation actually resolves to (observed behavior).
  final BackendSource resolvedSource;

  /// Forward-slash, package-relative path of the Screen issuing the operation.
  /// Optional, but recommended so findings can identify the Screen (Req 11.2).
  final String? screenPath;

  /// Optional human-readable note describing the call site (e.g. "load orders").
  final String? description;

  /// True iff this operation resolves to Backend_Services (the only compliant
  /// source).
  bool get isCompliant => resolvedSource.isBackendServices;

  @override
  String toString() =>
      'BackendOperation(${kind.name}, source=${resolvedSource.name}'
      '${screenPath == null ? '' : ', screen=$screenPath'}'
      '${description == null ? '' : ', $description'})';
}

/// A finding recorded for a single operation that resolves to a
/// non-Backend_Services source. Identifies the Screen, the operation, and the
/// offending source (Req 11.2).
class BackendSourceFinding {
  BackendSourceFinding({required this.operation})
    : assert(
        operation.resolvedSource.isNonBackendFixture,
        'A finding is only meaningful for a non-Backend_Services source.',
      );

  /// The non-compliant operation this finding describes.
  final BackendOperation operation;

  /// The Screen the offending operation belongs to (may be null if unknown).
  String? get screenPath => operation.screenPath;

  /// The non-Backend_Services source that the operation resolved to.
  BackendSource get source => operation.resolvedSource;

  /// The kind (read/write) of the offending operation.
  BackendOperationKind get kind => operation.kind;

  @override
  String toString() =>
      'BackendSourceFinding(screen=${screenPath ?? '<unknown>'}, '
      '${kind.name}, source=${source.name}'
      '${operation.description == null ? '' : ', ${operation.description}'})';
}

/// The outcome of classifying a Screen's backend read/write call sites: PASS
/// when every operation resolves to Backend_Services, FAIL with one finding per
/// non-Backend_Services occurrence otherwise (Req 11.1, 11.2 / Property 30).
class BackendSourceResult {
  BackendSourceResult({required this.findings});

  /// One finding per operation that resolved to a non-Backend_Services source.
  /// Empty iff the category passes.
  final List<BackendSourceFinding> findings;

  /// True iff the Backend Integration category passes for source integrity —
  /// i.e. zero reads/writes resolve to a non-Backend_Services fixture.
  bool get passed => findings.isEmpty;

  /// True iff the category is FAIL (at least one non-compliant operation).
  bool get failed => !passed;

  @override
  String toString() =>
      'BackendSourceResult(${passed ? 'pass' : 'fail'}, '
      '${findings.length} finding(s))';
}

/// Pure classifier deciding backend-source integrity for a Screen's data
/// read/write call sites (Req 11.1, 11.2 / Property 30).
///
/// The rule is exact: the category is FAIL **if and only if** at least one
/// operation resolves to a mock, stub, hardcoded, or in-memory source. Each
/// such operation yields a [BackendSourceFinding] identifying the Screen, the
/// operation, and the non-Backend_Services source.
class BackendSourceClassifier {
  const BackendSourceClassifier();

  /// Classify all [operations] for a Screen, collecting a finding for every
  /// read/write that resolves to a non-Backend_Services source.
  BackendSourceResult classify(Iterable<BackendOperation> operations) {
    final findings = <BackendSourceFinding>[
      for (final op in operations)
        if (op.resolvedSource.isNonBackendFixture)
          BackendSourceFinding(operation: op),
    ];
    return BackendSourceResult(findings: findings);
  }

  /// True iff every operation resolves to Backend_Services (no fixtures).
  bool hasIntegrity(Iterable<BackendOperation> operations) =>
      classify(operations).passed;
}

// ===========================================================================
// SECTION 2 — DynamoDB access-pattern compliance (Req 11.3 / Property 31)
// ===========================================================================

/// A query filter applied to a single attribute of a DynamoDB access, together
/// with whether that attribute is a key attribute and, when it is not, whether
/// the filter is served by a defined GSI.
///
/// Only filters on non-key attributes need a GSI; filters on key attributes are
/// served by the table/index keys directly (Req 11.3).
class DynamoFilter {
  DynamoFilter({
    required this.attribute,
    required this.isKeyAttribute,
    this.servedByDefinedGsi = false,
  });

  /// The attribute name the filter is applied to.
  final String attribute;

  /// True iff [attribute] is part of the table/index key schema (partition or
  /// sort key). Key-attribute filters never require a GSI.
  final bool isKeyAttribute;

  /// True iff a non-key filter is served by a defined GSI. Ignored for key
  /// attributes.
  final bool servedByDefinedGsi;

  /// True iff this filter is compliant: key-attribute filters always are;
  /// non-key filters are compliant only when served by a defined GSI (Req 11.3).
  bool get isServed => isKeyAttribute || servedByDefinedGsi;

  @override
  String toString() =>
      'DynamoFilter($attribute, key=$isKeyAttribute, gsi=$servedByDefinedGsi)';
}

/// A single DynamoDB access issued by a Screen, described in terms of the
/// access-pattern properties checked by [DynamoAccessClassifier] (Req 11.3).
///
/// The descriptor records, independently of any concrete SDK call:
///   * whether the access uses a Scan operation,
///   * whether it specifies a partition key,
///   * whether the target table/index defines a sort key and, if so, whether
///     the access specifies it,
///   * the filters applied, each tagged as key/non-key and (for non-key)
///     whether a defined GSI serves it.
class DynamoAccess {
  DynamoAccess({
    required this.usesScan,
    required this.specifiesPartitionKey,
    this.tableDefinesSortKey = false,
    this.specifiesSortKey = false,
    List<DynamoFilter>? filters,
    this.screenPath,
    this.description,
  }) : filters = List<DynamoFilter>.unmodifiable(filters ?? const []);

  /// True iff this access path uses a DynamoDB Scan operation. Any Scan fails
  /// the access-pattern check (Req 11.3).
  final bool usesScan;

  /// True iff the access specifies a partition key.
  final bool specifiesPartitionKey;

  /// True iff the target table or index defines a sort key. When true, the
  /// access must also specify the sort key to be compliant.
  final bool tableDefinesSortKey;

  /// True iff the access specifies a sort key value.
  final bool specifiesSortKey;

  /// The filters applied by this access (may be empty).
  final List<DynamoFilter> filters;

  /// Forward-slash, package-relative path of the Screen issuing the access.
  final String? screenPath;

  /// Optional human-readable note describing the access (e.g. "list invoices").
  final String? description;

  /// Non-key filters not served by a defined GSI — i.e. the offending filters.
  List<DynamoFilter> get unservedNonKeyFilters => [
    for (final f in filters)
      if (!f.isServed) f,
  ];

  @override
  String toString() =>
      'DynamoAccess(scan=$usesScan, pk=$specifiesPartitionKey, '
      'definesSk=$tableDefinesSortKey, sk=$specifiesSortKey, '
      '${filters.length} filter(s)'
      '${screenPath == null ? '' : ', screen=$screenPath'}'
      '${description == null ? '' : ', $description'})';
}

/// A distinct reason a [DynamoAccess] fails the access-pattern check. Each
/// failing access can accumulate more than one violation (Req 11.3).
enum DynamoViolation {
  /// The access uses a Scan operation (zero Scans are allowed).
  usesScan,

  /// The access does not specify a partition key.
  missingPartitionKey,

  /// The table/index defines a sort key but the access does not specify it.
  missingSortKey,

  /// At least one non-key-attribute filter is not served by a defined GSI.
  filterNotServedByGsi,
}

/// The outcome of checking a single [DynamoAccess] against the access-pattern
/// rules (Req 11.3 / Property 31): PASS iff there are zero violations.
class DynamoAccessResult {
  DynamoAccessResult({required this.access, required this.violations});

  /// The access that was checked.
  final DynamoAccess access;

  /// The violations found, in detection order. Empty iff the access passes.
  final List<DynamoViolation> violations;

  /// True iff the access satisfies every access-pattern rule.
  bool get passed => violations.isEmpty;

  /// True iff the access violates at least one rule.
  bool get failed => !passed;

  @override
  String toString() =>
      'DynamoAccessResult(${passed ? 'pass' : 'fail'}, '
      'violations=${violations.map((v) => v.name).toList()})';
}

/// Pure classifier deciding DynamoDB access-pattern compliance (Req 11.3 /
/// Property 31).
///
/// An access PASSES **if and only if** all of the following hold:
///   * it specifies a partition key, and
///   * it specifies a sort key wherever the table/index defines one, and
///   * every non-key-attribute filter is served by a defined GSI, and
///   * it does not use a Scan operation.
class DynamoAccessClassifier {
  const DynamoAccessClassifier();

  /// Compute the ordered list of violations for a single [access]. Empty iff
  /// the access is compliant.
  List<DynamoViolation> violationsFor(DynamoAccess access) {
    final violations = <DynamoViolation>[];

    if (access.usesScan) {
      violations.add(DynamoViolation.usesScan);
    }
    if (!access.specifiesPartitionKey) {
      violations.add(DynamoViolation.missingPartitionKey);
    }
    if (access.tableDefinesSortKey && !access.specifiesSortKey) {
      violations.add(DynamoViolation.missingSortKey);
    }
    if (access.unservedNonKeyFilters.isNotEmpty) {
      violations.add(DynamoViolation.filterNotServedByGsi);
    }

    return violations;
  }

  /// Check a single [access] and report its violations.
  DynamoAccessResult check(DynamoAccess access) =>
      DynamoAccessResult(access: access, violations: violationsFor(access));

  /// Check every [accesses] entry. The Screen passes the DynamoDB
  /// access-pattern check only when every access passes.
  List<DynamoAccessResult> checkAll(Iterable<DynamoAccess> accesses) => [
    for (final a in accesses) check(a),
  ];

  /// True iff [access] satisfies every access-pattern rule (Req 11.3).
  bool isCompliant(DynamoAccess access) => check(access).passed;

  /// True iff every access in [accesses] is compliant.
  bool allCompliant(Iterable<DynamoAccess> accesses) =>
      checkAll(accesses).every((r) => r.passed);
}

// ===========================================================================
// SECTION 3 — S3 / SQS / REST-route classifiers (Task 18.4, appended later)
//
// The S3 presigned-URL/bucket-exposure classifier (Property 32), the SQS
// dead-letter-queue classifier (Property 33), and the REST→Lambda route-mapping
// classifier (Property 34) belong to Task 18.4 and will be added below this
// marker as additional descriptor + result + classifier triples, following the
// same shape as Sections 1 and 2.
// ===========================================================================

/// The maximum allowed lifetime, in seconds, of an S3 presigned URL used for a
/// Screen upload or download (Req 11.4 / Property 32).
const int kMaxPresignedUrlExpirySeconds = 900;

/// The inclusive lower bound for a compliant SQS `maxReceiveCount` (Req 11.7 /
/// Property 33).
const int kMinSqsMaxReceiveCount = 1;

/// The inclusive upper bound for a compliant SQS `maxReceiveCount` (Req 11.7 /
/// Property 33).
const int kMaxSqsMaxReceiveCount = 10;

/// A single S3 upload or download referenced by a Screen, described in terms of
/// the access-pattern properties checked by [S3AccessClassifier] (Req 11.4 /
/// Property 32).
///
/// The descriptor records, independently of any concrete SDK call:
///   * whether the transfer is performed through a presigned URL,
///   * the presigned URL's expiry in seconds (when one is used),
///   * whether the referenced bucket allows public read, and
///   * whether the referenced bucket allows public write.
class S3Access {
  S3Access({
    required this.kind,
    required this.usesPresignedUrl,
    this.expirySeconds,
    this.bucketPublicRead = false,
    this.bucketPublicWrite = false,
    this.screenPath,
    this.bucketName,
    this.description,
  });

  /// Whether this is an upload (write) or a download (read) transfer. Both are
  /// held to the same presigned-URL and bucket-exposure bar.
  final BackendOperationKind kind;

  /// True iff the transfer is performed through a presigned URL. When false the
  /// access fails regardless of any other field.
  final bool usesPresignedUrl;

  /// The presigned URL's expiry in seconds, when one is used. Null means no
  /// expiry was specified (which fails the at-most-900-seconds rule).
  final int? expirySeconds;

  /// True iff the referenced bucket allows public read access.
  final bool bucketPublicRead;

  /// True iff the referenced bucket allows public write access.
  final bool bucketPublicWrite;

  /// Forward-slash, package-relative path of the Screen issuing the transfer.
  final String? screenPath;

  /// Optional name of the referenced bucket (for findings).
  final String? bucketName;

  /// Optional human-readable note describing the access (e.g. "upload receipt").
  final String? description;

  /// True iff the bucket exposes either public read or public write access.
  bool get bucketPubliclyExposed => bucketPublicRead || bucketPublicWrite;

  @override
  String toString() =>
      'S3Access(${kind.name}, presigned=$usesPresignedUrl, '
      'expiry=${expirySeconds ?? '<none>'}, publicRead=$bucketPublicRead, '
      'publicWrite=$bucketPublicWrite'
      '${bucketName == null ? '' : ', bucket=$bucketName'}'
      '${screenPath == null ? '' : ', screen=$screenPath'}'
      '${description == null ? '' : ', $description'})';
}

/// A distinct reason an [S3Access] fails the presigned-URL/bucket-exposure
/// check. A failing access can accumulate more than one violation (Req 11.4).
enum S3Violation {
  /// The transfer is not performed through a presigned URL.
  notPresigned,

  /// The presigned URL has no expiry or an expiry exceeding 900 seconds.
  expiryTooLong,

  /// The referenced bucket allows public read access.
  bucketPublicRead,

  /// The referenced bucket allows public write access.
  bucketPublicWrite,
}

/// The outcome of checking a single [S3Access] against the presigned-URL and
/// bucket-exposure rules (Req 11.4 / Property 32): PASS iff zero violations.
class S3AccessResult {
  S3AccessResult({required this.access, required this.violations});

  /// The access that was checked.
  final S3Access access;

  /// The violations found, in detection order. Empty iff the access passes.
  final List<S3Violation> violations;

  /// True iff the access satisfies every presigned-URL/bucket-exposure rule.
  bool get passed => violations.isEmpty;

  /// True iff the access violates at least one rule.
  bool get failed => !passed;

  @override
  String toString() =>
      'S3AccessResult(${passed ? 'pass' : 'fail'}, '
      'violations=${violations.map((v) => v.name).toList()})';
}

/// Pure classifier deciding S3 presigned-URL and bucket-exposure compliance
/// (Req 11.4 / Property 32).
///
/// An access PASSES **if and only if** all of the following hold:
///   * the transfer is performed through a presigned URL, and
///   * the presigned URL's expiry is at most 900 seconds, and
///   * the referenced bucket does not allow public read access, and
///   * the referenced bucket does not allow public write access.
class S3AccessClassifier {
  const S3AccessClassifier();

  /// Compute the ordered list of violations for a single [access]. Empty iff
  /// the access is compliant.
  List<S3Violation> violationsFor(S3Access access) {
    final violations = <S3Violation>[];

    if (!access.usesPresignedUrl) {
      violations.add(S3Violation.notPresigned);
    }
    final expiry = access.expirySeconds;
    if (expiry == null || expiry > kMaxPresignedUrlExpirySeconds) {
      violations.add(S3Violation.expiryTooLong);
    }
    if (access.bucketPublicRead) {
      violations.add(S3Violation.bucketPublicRead);
    }
    if (access.bucketPublicWrite) {
      violations.add(S3Violation.bucketPublicWrite);
    }

    return violations;
  }

  /// Check a single [access] and report its violations.
  S3AccessResult check(S3Access access) =>
      S3AccessResult(access: access, violations: violationsFor(access));

  /// Check every [accesses] entry. The Screen passes the S3 check only when
  /// every access passes.
  List<S3AccessResult> checkAll(Iterable<S3Access> accesses) => [
    for (final a in accesses) check(a),
  ];

  /// True iff [access] satisfies every presigned-URL/bucket-exposure rule.
  bool isCompliant(S3Access access) => check(access).passed;

  /// True iff every access in [accesses] is compliant.
  bool allCompliant(Iterable<S3Access> accesses) =>
      checkAll(accesses).every((r) => r.passed);
}

// ---------------------------------------------------------------------------
// SQS dead-letter-queue configuration compliance (Req 11.7 / Property 33)
// ---------------------------------------------------------------------------

/// A single SQS queue configuration triggered by a Screen, described in terms
/// of the dead-letter-queue properties checked by [SqsQueueClassifier]
/// (Req 11.7 / Property 33).
///
/// The descriptor records, independently of any concrete infrastructure:
///   * whether a dead-letter queue is configured,
///   * the queue's `maxReceiveCount` (when a DLQ is configured), and
///   * whether messages exceeding `maxReceiveCount` are routed to the DLQ
///     rather than reprocessed indefinitely.
class SqsQueueConfig {
  SqsQueueConfig({
    required this.hasDeadLetterQueue,
    this.maxReceiveCount,
    this.overflowRoutedToDlq = false,
    this.screenPath,
    this.queueName,
    this.description,
  });

  /// True iff a dead-letter queue is configured for this queue.
  final bool hasDeadLetterQueue;

  /// The configured `maxReceiveCount`, when a DLQ is present. Null means no
  /// receive count was specified (which fails the 1..10 rule).
  final int? maxReceiveCount;

  /// True iff messages exceeding [maxReceiveCount] are routed to the DLQ rather
  /// than reprocessed indefinitely.
  final bool overflowRoutedToDlq;

  /// Forward-slash, package-relative path of the Screen triggering the queue.
  final String? screenPath;

  /// Optional name of the queue (for findings).
  final String? queueName;

  /// Optional human-readable note describing the queue (e.g. "order events").
  final String? description;

  /// True iff [maxReceiveCount] is within the inclusive 1..10 bound.
  bool get maxReceiveCountInRange {
    final count = maxReceiveCount;
    return count != null &&
        count >= kMinSqsMaxReceiveCount &&
        count <= kMaxSqsMaxReceiveCount;
  }

  @override
  String toString() =>
      'SqsQueueConfig(dlq=$hasDeadLetterQueue, '
      'maxReceiveCount=${maxReceiveCount ?? '<none>'}, '
      'overflowToDlq=$overflowRoutedToDlq'
      '${queueName == null ? '' : ', queue=$queueName'}'
      '${screenPath == null ? '' : ', screen=$screenPath'}'
      '${description == null ? '' : ', $description'})';
}

/// A distinct reason an [SqsQueueConfig] fails the dead-letter-queue check. A
/// failing queue can accumulate more than one violation (Req 11.7).
enum SqsViolation {
  /// No dead-letter queue is configured.
  missingDeadLetterQueue,

  /// The `maxReceiveCount` is absent or outside the inclusive 1..10 bound.
  maxReceiveCountOutOfRange,

  /// Messages exceeding `maxReceiveCount` are not routed to the DLQ.
  overflowNotRoutedToDlq,
}

/// The outcome of checking a single [SqsQueueConfig] against the
/// dead-letter-queue rules (Req 11.7 / Property 33): PASS iff zero violations.
class SqsQueueResult {
  SqsQueueResult({required this.config, required this.violations});

  /// The queue configuration that was checked.
  final SqsQueueConfig config;

  /// The violations found, in detection order. Empty iff the queue passes.
  final List<SqsViolation> violations;

  /// True iff the queue satisfies every dead-letter-queue rule.
  bool get passed => violations.isEmpty;

  /// True iff the queue violates at least one rule.
  bool get failed => !passed;

  @override
  String toString() =>
      'SqsQueueResult(${passed ? 'pass' : 'fail'}, '
      'violations=${violations.map((v) => v.name).toList()})';
}

/// Pure classifier deciding SQS dead-letter-queue configuration compliance
/// (Req 11.7 / Property 33).
///
/// A queue PASSES **if and only if** all of the following hold:
///   * a dead-letter queue is configured, and
///   * its `maxReceiveCount` is between 1 and 10 inclusive, and
///   * messages exceeding `maxReceiveCount` are routed to the DLQ rather than
///     reprocessed indefinitely.
class SqsQueueClassifier {
  const SqsQueueClassifier();

  /// Compute the ordered list of violations for a single [config]. Empty iff
  /// the queue is compliant.
  List<SqsViolation> violationsFor(SqsQueueConfig config) {
    final violations = <SqsViolation>[];

    if (!config.hasDeadLetterQueue) {
      violations.add(SqsViolation.missingDeadLetterQueue);
    }
    if (!config.maxReceiveCountInRange) {
      violations.add(SqsViolation.maxReceiveCountOutOfRange);
    }
    if (!config.overflowRoutedToDlq) {
      violations.add(SqsViolation.overflowNotRoutedToDlq);
    }

    return violations;
  }

  /// Check a single [config] and report its violations.
  SqsQueueResult check(SqsQueueConfig config) =>
      SqsQueueResult(config: config, violations: violationsFor(config));

  /// Check every [configs] entry. The Screen passes the SQS check only when
  /// every queue passes.
  List<SqsQueueResult> checkAll(Iterable<SqsQueueConfig> configs) => [
    for (final c in configs) check(c),
  ];

  /// True iff [config] satisfies every dead-letter-queue rule.
  bool isCompliant(SqsQueueConfig config) => check(config).passed;

  /// True iff every queue in [configs] is compliant.
  bool allCompliant(Iterable<SqsQueueConfig> configs) =>
      checkAll(configs).every((r) => r.passed);
}

// ---------------------------------------------------------------------------
// REST → Lambda route-mapping compliance (Req 11.8 / Property 34)
// ---------------------------------------------------------------------------

/// A single API Gateway route entry: the method+path key it is defined for and
/// whether it is backed by a Lambda handler (Req 11.8 / Property 34).
class ApiGatewayRoute {
  ApiGatewayRoute({
    required this.method,
    required this.path,
    required this.backedByLambda,
  });

  /// The HTTP method of the route (e.g. "GET", "POST"). Compared case-insensitively.
  final String method;

  /// The route path (e.g. "/orders/{id}"). Compared exactly.
  final String path;

  /// True iff the route is backed by a Lambda handler. A defined-but-unbacked
  /// route does not satisfy a REST call targeting it.
  final bool backedByLambda;

  /// The normalized lookup key for this route ("METHOD path").
  String get key => routeKey(method, path);

  /// Build the normalized lookup key for a [method] + [path] pair.
  static String routeKey(String method, String path) =>
      '${method.toUpperCase()} $path';

  @override
  String toString() => 'ApiGatewayRoute($key, backedByLambda=$backedByLambda)';
}

/// A single REST call site issued by a Screen, identified by the method+path it
/// targets (Req 11.8 / Property 34).
class RestCall {
  RestCall({
    required this.method,
    required this.path,
    this.screenPath,
    this.description,
  });

  /// The HTTP method of the call (e.g. "GET", "POST"). Compared case-insensitively.
  final String method;

  /// The route path the call targets (e.g. "/orders/{id}").
  final String path;

  /// Forward-slash, package-relative path of the Screen issuing the call.
  final String? screenPath;

  /// Optional human-readable note describing the call (e.g. "fetch order").
  final String? description;

  /// The normalized lookup key for this call ("METHOD path").
  String get key => ApiGatewayRoute.routeKey(method, path);

  @override
  String toString() =>
      'RestCall($key'
      '${screenPath == null ? '' : ', screen=$screenPath'}'
      '${description == null ? '' : ', $description'})';
}

/// A distinct reason a [RestCall] fails the route-mapping check (Req 11.8).
enum RestRouteViolation {
  /// The call targets a route not defined in the API Gateway route table.
  undefinedRoute,

  /// The call targets a defined route that is not backed by a Lambda handler.
  unbackedRoute,
}

/// A finding recorded for a single REST call that does not map to a defined,
/// Lambda-backed route. Identifies the call and the reason (Req 11.8).
class RestRouteFinding {
  RestRouteFinding({required this.call, required this.violation});

  /// The non-compliant call this finding describes.
  final RestCall call;

  /// Whether the route is undefined or merely unbacked.
  final RestRouteViolation violation;

  /// The Screen the offending call belongs to (may be null if unknown).
  String? get screenPath => call.screenPath;

  @override
  String toString() =>
      'RestRouteFinding(${call.key}, ${violation.name}, '
      'screen=${screenPath ?? '<unknown>'})';
}

/// The outcome of mapping a Screen's REST calls against an API Gateway route
/// table (Req 11.8 / Property 34): PASS when every call maps to a defined,
/// Lambda-backed route, FAIL with one finding per offending call otherwise.
class RestRouteResult {
  RestRouteResult({required this.findings});

  /// One finding per call that targets an undefined or unbacked route. Empty
  /// iff the check passes.
  final List<RestRouteFinding> findings;

  /// True iff every REST call maps to a defined, Lambda-backed route.
  bool get passed => findings.isEmpty;

  /// True iff at least one call targets an undefined or unbacked route.
  bool get failed => !passed;

  @override
  String toString() =>
      'RestRouteResult(${passed ? 'pass' : 'fail'}, '
      '${findings.length} finding(s))';
}

/// Pure classifier deciding REST→Lambda route-mapping compliance (Req 11.8 /
/// Property 34).
///
/// The check PASSES **if and only if** every REST call maps to a defined API
/// Gateway route that is backed by a Lambda handler. Any call targeting an
/// undefined route or a defined-but-unbacked route yields a [RestRouteFinding].
class RestRouteClassifier {
  const RestRouteClassifier();

  /// Map every [calls] entry against the [routes] table, collecting a finding
  /// for each call that does not resolve to a defined, Lambda-backed route.
  RestRouteResult classify(
    Iterable<RestCall> calls,
    Iterable<ApiGatewayRoute> routes,
  ) {
    final routesByKey = <String, ApiGatewayRoute>{
      for (final route in routes) route.key: route,
    };

    final findings = <RestRouteFinding>[];
    for (final call in calls) {
      final route = routesByKey[call.key];
      if (route == null) {
        findings.add(
          RestRouteFinding(
            call: call,
            violation: RestRouteViolation.undefinedRoute,
          ),
        );
      } else if (!route.backedByLambda) {
        findings.add(
          RestRouteFinding(
            call: call,
            violation: RestRouteViolation.unbackedRoute,
          ),
        );
      }
    }

    return RestRouteResult(findings: findings);
  }

  /// True iff every call in [calls] maps to a defined, Lambda-backed route in
  /// [routes].
  bool allMapped(Iterable<RestCall> calls, Iterable<ApiGatewayRoute> routes) =>
      classify(calls, routes).passed;
}
