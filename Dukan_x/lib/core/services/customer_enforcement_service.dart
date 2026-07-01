// ============================================================================
// CUSTOMER ENFORCEMENT SERVICE
// ============================================================================
// Enforces credit limits and customer blocking for billing operations.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import '../repository/customers_repository.dart';

/// Result of credit limit check
enum EnforcementAction {
  /// Allow the transaction
  allow,

  /// Warn but allow the transaction
  warn,

  /// Block the transaction
  block,
}

/// Result of enforcement check
class EnforcementResult {
  final EnforcementAction action;
  final String? message;
  final double creditLimit;
  final double currentOutstanding;
  final double proposedAmount;
  final double projectedOutstanding;

  const EnforcementResult({
    required this.action,
    this.message,
    required this.creditLimit,
    required this.currentOutstanding,
    required this.proposedAmount,
    required this.projectedOutstanding,
  });

  bool get isAllowed => action == EnforcementAction.allow;
  bool get isWarning => action == EnforcementAction.warn;
  bool get isBlocked => action == EnforcementAction.block;

  /// Amount by which credit limit is/will be exceeded
  double get overLimitAmount => projectedOutstanding > creditLimit
      ? projectedOutstanding - creditLimit
      : 0;
}

/// Customer Enforcement Service - Credit Limit & Block Enforcement
///
/// Provides business logic for:
/// - Credit limit checks before billing
/// - Customer block status enforcement
/// - Warning thresholds
class CustomerEnforcementService {
  final CustomersRepository _customersRepository;

  /// Warning threshold: warn when outstanding reaches this % of credit limit
  static const double warningThreshold = 0.8; // 80%

  CustomerEnforcementService(this._customersRepository);

  /// Check if a proposed transaction should be allowed based on credit limits
  ///
  /// Returns [EnforcementResult] with action and details:
  /// - [EnforcementAction.allow]: Transaction is within limits
  /// - [EnforcementAction.warn]: Transaction approaches limit (>80%)
  /// - [EnforcementAction.block]: Transaction would exceed limit
  ///
  /// Note: If customer has creditLimit = 0, it means unlimited credit
  Future<EnforcementResult> checkCreditLimit({
    required String customerId,
    required double proposedAmount,
  }) async {
    final result = await _customersRepository.getById(customerId);

    if (!result.isSuccess || result.data == null) {
      // Customer not found - allow (fallback for cash sales, etc.)
      return EnforcementResult(
        action: EnforcementAction.allow,
        creditLimit: 0,
        currentOutstanding: 0,
        proposedAmount: proposedAmount,
        projectedOutstanding: proposedAmount,
      );
    }

    final customer = result.data!;

    // Check if customer is blocked
    if (customer.isBlocked) {
      return EnforcementResult(
        action: EnforcementAction.block,
        message:
            customer.blockReason ?? 'Customer is blocked from new transactions',
        creditLimit: customer.creditLimit,
        currentOutstanding: customer.totalDues,
        proposedAmount: proposedAmount,
        projectedOutstanding: customer.totalDues + proposedAmount,
      );
    }

    // If credit limit is 0, it means unlimited
    if (customer.creditLimit <= 0) {
      return EnforcementResult(
        action: EnforcementAction.allow,
        creditLimit: 0,
        currentOutstanding: customer.totalDues,
        proposedAmount: proposedAmount,
        projectedOutstanding: customer.totalDues + proposedAmount,
      );
    }

    final projectedOutstanding = customer.totalDues + proposedAmount;

    // Check if transaction would exceed credit limit
    if (projectedOutstanding > customer.creditLimit) {
      return EnforcementResult(
        action: EnforcementAction.block,
        message:
            'Credit limit of ₹${customer.creditLimit.toStringAsFixed(0)} would be exceeded. '
            'Current outstanding: ₹${customer.totalDues.toStringAsFixed(0)}. '
            'Available credit: ₹${(customer.creditLimit - customer.totalDues).toStringAsFixed(0)}.',
        creditLimit: customer.creditLimit,
        currentOutstanding: customer.totalDues,
        proposedAmount: proposedAmount,
        projectedOutstanding: projectedOutstanding,
      );
    }

    // Check if transaction approaches warning threshold
    final usageRatio = projectedOutstanding / customer.creditLimit;
    if (usageRatio >= warningThreshold) {
      return EnforcementResult(
        action: EnforcementAction.warn,
        message:
            'Customer approaching credit limit. '
            '${(usageRatio * 100).toStringAsFixed(0)}% of limit will be used after this transaction.',
        creditLimit: customer.creditLimit,
        currentOutstanding: customer.totalDues,
        proposedAmount: proposedAmount,
        projectedOutstanding: projectedOutstanding,
      );
    }

    // All checks passed
    return EnforcementResult(
      action: EnforcementAction.allow,
      creditLimit: customer.creditLimit,
      currentOutstanding: customer.totalDues,
      proposedAmount: proposedAmount,
      projectedOutstanding: projectedOutstanding,
    );
  }

  /// Check if customer is blocked from transactions
  Future<bool> isCustomerBlocked(String customerId) async {
    final result = await _customersRepository.getById(customerId);
    if (!result.isSuccess || result.data == null) {
      return false;
    }
    return result.data!.isBlocked;
  }

  /// Get available credit for a customer
  ///
  /// Returns null if customer has unlimited credit (creditLimit = 0)
  Future<double?> getAvailableCredit(String customerId) async {
    final result = await _customersRepository.getById(customerId);
    if (!result.isSuccess || result.data == null) {
      return null;
    }

    final customer = result.data!;
    if (customer.creditLimit <= 0) {
      return null; // Unlimited
    }

    return customer.creditLimit - customer.totalDues;
  }

  /// Block a customer with a reason
  Future<bool> blockCustomer({
    required String customerId,
    required String userId,
    required String reason,
  }) async {
    final result = await _customersRepository.getById(customerId);
    if (!result.isSuccess || result.data == null) {
      return false;
    }

    final customer = result.data!;
    final updateResult = await _customersRepository.updateCustomer(
      customer.copyWith(isBlocked: true, blockReason: reason),
      userId: userId,
    );

    return updateResult.isSuccess;
  }

  /// Unblock a customer
  Future<bool> unblockCustomer({
    required String customerId,
    required String userId,
  }) async {
    final result = await _customersRepository.getById(customerId);
    if (!result.isSuccess || result.data == null) {
      return false;
    }

    final customer = result.data!;
    final updateResult = await _customersRepository.updateCustomer(
      customer.copyWith(isBlocked: false, blockReason: null),
      userId: userId,
    );

    return updateResult.isSuccess;
  }

  /// Update credit limit for a customer
  Future<bool> updateCreditLimit({
    required String customerId,
    required String userId,
    required double newLimit,
  }) async {
    final result = await _customersRepository.getById(customerId);
    if (!result.isSuccess || result.data == null) {
      return false;
    }

    final customer = result.data!;
    final updateResult = await _customersRepository.updateCustomer(
      customer.copyWith(creditLimit: newLimit),
      userId: userId,
    );

    return updateResult.isSuccess;
  }
}
