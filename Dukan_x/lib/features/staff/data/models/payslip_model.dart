/// Payslip model for Universal Staff Management module.
///
/// Maps to the backend Payslip entity (SK: PAYSLIP#{period}#{employeeId}).
/// Money stored as integer paise on the wire, converted to rupees in the model.
class PayslipModel {
  final String id;
  final String businessId;
  final String payrollRunId;
  final String employeeId;
  final String period;
  final double gross;
  final double net;
  final Map<String, double> deductions;
  final Map<String, double> earnings;
  final DateTime createdAt;

  const PayslipModel({
    required this.id,
    required this.businessId,
    required this.payrollRunId,
    required this.employeeId,
    required this.period,
    required this.gross,
    required this.net,
    this.deductions = const {},
    this.earnings = const {},
    required this.createdAt,
  });

  factory PayslipModel.fromJson(Map<String, dynamic> json) {
    double paiseToRupees(num? v) => (v ?? 0) / 100.0;

    Map<String, double> parseAmountMap(dynamic raw) {
      if (raw is! Map) return {};
      return raw.map(
        (key, value) => MapEntry(key.toString(), paiseToRupees(value as num?)),
      );
    }

    return PayslipModel(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      payrollRunId: json['payrollRunId'] as String? ?? '',
      employeeId: json['employeeId'] as String? ?? '',
      period: json['period'] as String? ?? '',
      gross: paiseToRupees(json['grossPaise'] as num?),
      net: paiseToRupees(json['netPaise'] as num?),
      deductions: parseAmountMap(json['deductions']),
      earnings: parseAmountMap(json['earnings']),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    int rupeesToPaise(double v) => (v * 100).round();

    Map<String, int> toAmountMap(Map<String, double> m) =>
        m.map((key, value) => MapEntry(key, rupeesToPaise(value)));

    return {
      'id': id,
      'businessId': businessId,
      'payrollRunId': payrollRunId,
      'employeeId': employeeId,
      'period': period,
      'grossPaise': rupeesToPaise(gross),
      'netPaise': rupeesToPaise(net),
      'deductions': toAmountMap(deductions),
      'earnings': toAmountMap(earnings),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
