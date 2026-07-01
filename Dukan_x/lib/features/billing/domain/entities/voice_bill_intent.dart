import 'package:equatable/equatable.dart';
import 'bill_item.dart';

enum VoiceBillIntentType {
  createBill,
  confirmBill,
  cancelBill,
  addItems,
  removeItems,
  unknown,
}

enum VoicePaymentMode { cash, online, credit, unknown }

class VoiceBillIntent extends Equatable {
  final VoiceBillIntentType type;
  final String? customerName;
  final List<BillItem> items;
  final VoicePaymentMode paymentMode;
  final double? discount;
  final bool isGstApplicable;
  final String rawText;
  final Map<String, dynamic> metadata;

  const VoiceBillIntent({
    required this.type,
    this.customerName,
    this.items = const [],
    this.paymentMode = VoicePaymentMode.unknown,
    this.discount,
    this.isGstApplicable = false,
    required this.rawText,
    this.metadata = const {},
  });

  @override
  List<Object?> get props => [
    type,
    customerName,
    items,
    paymentMode,
    discount,
    isGstApplicable,
    rawText,
    metadata,
  ];

  VoiceBillIntent copyWith({
    VoiceBillIntentType? type,
    String? customerName,
    List<BillItem>? items,
    VoicePaymentMode? paymentMode,
    double? discount,
    bool? isGstApplicable,
    String? rawText,
    Map<String, dynamic>? metadata,
  }) {
    return VoiceBillIntent(
      type: type ?? this.type,
      customerName: customerName ?? this.customerName,
      items: items ?? this.items,
      paymentMode: paymentMode ?? this.paymentMode,
      discount: discount ?? this.discount,
      isGstApplicable: isGstApplicable ?? this.isGstApplicable,
      rawText: rawText ?? this.rawText,
      metadata: metadata ?? this.metadata,
    );
  }
}
