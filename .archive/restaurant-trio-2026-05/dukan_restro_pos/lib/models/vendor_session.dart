// Vendor session model for POS app

class VendorSession {
  final String vendorId;
  final String staffName;
  final DateTime loginAt;

  const VendorSession({
    required this.vendorId,
    required this.staffName,
    required this.loginAt,
  });
}
