// Cart item model for POS app

class CartItem {
  final String menuItemId;
  final String itemName;
  final double price;
  final int qty;
  final String? variationName;
  final List<String> addons;
  final String? specialInstructions;

  const CartItem({
    required this.menuItemId,
    required this.itemName,
    required this.price,
    required this.qty,
    this.variationName,
    this.addons = const [],
    this.specialInstructions,
  });

  CartItem copyWith({
    String? menuItemId,
    String? itemName,
    double? price,
    int? qty,
    String? variationName,
    List<String>? addons,
    String? specialInstructions,
  }) {
    return CartItem(
      menuItemId: menuItemId ?? this.menuItemId,
      itemName: itemName ?? this.itemName,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      variationName: variationName ?? this.variationName,
      addons: addons ?? this.addons,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }

  Map<String, dynamic> toJson() => {
    'menuItemId': menuItemId,
    'itemName': itemName,
    'price': price,
    'qty': qty,
    'variationName': variationName,
    'addons': addons,
    'specialInstructions': specialInstructions,
  };
}
