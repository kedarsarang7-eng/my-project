// POS menu models

class PosMenuItem {
  final String id;
  final String name;
  final double price;
  final String category;
  final bool isVeg;
  final bool isAvailable;
  final String description;
  final String? imageUrl;
  final List<String> variations;
  final List<String> addons;

  const PosMenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.isVeg,
    this.isAvailable = true,
    this.description = '',
    this.imageUrl,
    this.variations = const [],
    this.addons = const [],
  });

  factory PosMenuItem.fromJson(Map<String, dynamic> json) {
    return PosMenuItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      isVeg: json['isVeg'] ?? true,
      isAvailable: json['isAvailable'] ?? true,
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'],
      variations: List<String>.from(json['variations'] ?? []),
      addons: List<String>.from(json['addons'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'category': category,
    'isVeg': isVeg,
    'isAvailable': isAvailable,
    'description': description,
    'imageUrl': imageUrl,
    'variations': variations,
    'addons': addons,
  };
}

class PosCategory {
  final String id;
  final String name;
  final List<PosMenuItem> items;

  const PosCategory({
    required this.id,
    required this.name,
    required this.items,
  });

  factory PosCategory.fromJson(Map<String, dynamic> json) {
    return PosCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      items: (json['items'] as List? ?? [])
          .map((e) => PosMenuItem.fromJson(e))
          .toList(),
    );
  }
}
