import 'package:flutter/foundation.dart';
import '../models/customer_item_request.dart';

/// Local Cart Service
/// Manages the temporary state of a customer's request cart.
/// Enforces Vendor Lock: Cart clears if vendor context changes.
class LocalCartService extends ChangeNotifier {
  String? _currentVendorId;
  final List<CustomerItemRequestItem> _items = [];

  String? get currentVendorId => _currentVendorId;
  List<CustomerItemRequestItem> get items => List.unmodifiable(_items);

  /// Initialize cart for a specific vendor.
  /// If vendor changes, existing cart is wiped (Data Isolation).
  void initializeForVendor(String vendorId) {
    if (_currentVendorId != vendorId) {
      if (_items.isNotEmpty) {
        // Log warning or notify user theoretically, but for now we auto-reset
        debugPrint(
          'LocalCartService: Vendor changed from $_currentVendorId to $vendorId. Clearing cart.',
        );
      }
      _items.clear();
      _currentVendorId = vendorId;
      notifyListeners();
    }
  }

  /// Add or Update item in cart
  void addItem(CustomerItemRequestItem item) {
    if (_currentVendorId == null) {
      throw Exception('Cart not initialized for any vendor');
    }

    final index = _items.indexWhere(
      (element) => element.productId == item.productId,
    );
    if (index >= 0) {
      // Update existing
      _items[index] = item;
    } else {
      // Add new
      _items.add(item);
    }
    notifyListeners();
  }

  /// Remove item from cart
  void removeItem(String productId) {
    _items.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  /// Update item quantity
  void updateQuantity(String productId, double quantity) {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(requestedQty: quantity);
      }
      notifyListeners();
    }
  }

  /// Clear cart manually
  void clear() {
    _items.clear();
    notifyListeners();
  }

  /// Get total count
  int get itemCount => _items.length;
}
