import 'nic_auth_model.dart'; // Reuse ErrorDetails

class IrnResponseModel {
  final String status;
  final IrnData? data;
  final ErrorDetails? error;

  IrnResponseModel({required this.status, this.data, this.error});

  bool get isSuccess => status == '1';

  factory IrnResponseModel.fromJson(Map<String, dynamic> json) {
    return IrnResponseModel(
      status: json['Status'] as String,
      data: json['Data'] != null ? IrnData.fromJson(json['Data']) : null,
      error: json['ErrorDetails'] != null
          ? ErrorDetails.fromJson(json['ErrorDetails'])
          : null,
    );
  }
}

class IrnData {
  final String irn;
  final String ackNo;
  final String ackDt;
  final String signedInvoice;
  final String signedQrCode;
  final String? status;
  final String? ewbNo;
  final String? ewbDt;
  final String? ewbValidTill;
  final String? remarks;

  IrnData({
    required this.irn,
    required this.ackNo,
    required this.ackDt,
    required this.signedInvoice,
    required this.signedQrCode,
    this.status,
    this.ewbNo,
    this.ewbDt,
    this.ewbValidTill,
    this.remarks,
  });

  factory IrnData.fromJson(Map<String, dynamic> json) {
    return IrnData(
      irn: json['Irn'] as String,
      ackNo: json['AckNo'].toString(),
      ackDt: json['AckDt'] as String,
      signedInvoice: json['SignedInvoice'] as String,
      signedQrCode: json['SignedQRCode'] as String,
      status: json['Status'] as String?,
      ewbNo: json['EwbNo']?.toString(), // Could be int or string
      ewbDt: json['EwbDt'] as String?,
      ewbValidTill: json['EwbValidTill'] as String?,
      remarks: json['Remarks'] as String?,
    );
  }
}
