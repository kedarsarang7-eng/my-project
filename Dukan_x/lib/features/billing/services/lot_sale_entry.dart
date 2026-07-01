import 'commission_input.dart';

/// Represents a single lot's sale data within a multi-lot broker bill.
///
/// Each lot is attributed to exactly one owning farmer. On bill save,
/// one `CommissionLedger` entry is created per lot, attributed to the
/// owning farmer of that lot.
///
/// (Requirements 7.1, 7.2, 7.3, 7.4)
class LotSaleEntry {
  /// Unique identifier for the lot (RID pattern).
  final String lotId;

  /// The farmer who owns this lot. Must not be null/empty.
  /// (Requirement 7.1)
  final String? owningFarmerId;

  /// Sale amount for this lot in integer paise.
  final int saleAmountPaise;

  /// The captured commission for this lot — either flat paise or percentage + result.
  final CommissionInput commission;

  /// Labor charges in integer paise (0 if not entered).
  final int laborChargesPaise;

  /// Hamali charges in integer paise (0 if not entered).
  final int hamaliChargesPaise;

  /// Weighing charges in integer paise (0 if not entered).
  final int weighingChargesPaise;

  /// Market fee in integer paise (0 if not entered).
  final int marketFeePaise;

  const LotSaleEntry({
    required this.lotId,
    required this.owningFarmerId,
    required this.saleAmountPaise,
    required this.commission,
    this.laborChargesPaise = 0,
    this.hamaliChargesPaise = 0,
    this.weighingChargesPaise = 0,
    this.marketFeePaise = 0,
  });
}
