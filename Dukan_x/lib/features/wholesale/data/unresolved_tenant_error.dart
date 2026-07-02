/// Error thrown when a tenant-scoped operation is attempted but the active
/// Tenant_Id cannot be resolved from the authenticated session.
///
/// This is an immediate, non-I/O failure — when thrown, no read, write, or
/// network call has been performed, and persisted data remains unchanged.
///
/// Requirement 1.7: If the Tenant_Id is missing or cannot be resolved, reject
/// the operation, perform no read or write, leave persisted data unchanged,
/// and return an error indicating an unresolved tenant.
class UnresolvedTenantError extends Error {
  /// Optional context describing which operation failed.
  final String? operation;

  UnresolvedTenantError([this.operation]);

  @override
  String toString() {
    final op = operation != null ? ' during "$operation"' : '';
    return 'UnresolvedTenantError: '
        'Tenant_Id could not be resolved from the authenticated session$op. '
        'No I/O was performed.';
  }
}
