/// Utility for generating Payment Intent Links
class PaymentUtils {
  /// Generate a standard UPI Intent Link
  static String generateUpiLink({
    required String upiId,
    required String shopName,
    required double amount,
    required String invoiceNumber,
    String? note,
  }) {
    // Basic formatting
    final cleanUpi = upiId.trim();
    // Use URL encoding for params
    final cleanName = Uri.encodeComponent(shopName.trim());
    final cleanNote = Uri.encodeComponent(note ?? 'Invoice Payment');

    // Construct UPI URL
    // tr = Transaction Ref (Invoice No)
    // tn = Transaction Note
    // am = Amount
    // pn = Payee Name
    // pa = Payee Address (VPA)
    return 'upi://pay?pa=$cleanUpi&pn=$cleanName&am=${amount.toStringAsFixed(2)}&tr=$invoiceNumber&tn=$cleanNote';
  }
}
