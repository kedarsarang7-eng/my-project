class ChefKotItem {
  final String id;
  final String name;
  final int qty;
  final String status;
  final int ageMinutes;

  const ChefKotItem({
    required this.id,
    required this.name,
    required this.qty,
    required this.status,
    required this.ageMinutes,
  });

  ChefKotItem copyWith({String? status}) {
    return ChefKotItem(
      id: id,
      name: name,
      qty: qty,
      status: status ?? this.status,
      ageMinutes: ageMinutes,
    );
  }
}

class ChefKot {
  final String id;
  final String tableLabel;
  final bool priority;
  final DateTime createdAt;
  final List<ChefKotItem> items;

  const ChefKot({
    required this.id,
    required this.tableLabel,
    required this.priority,
    required this.createdAt,
    required this.items,
  });

  bool get isCompleted =>
      items.isNotEmpty &&
      items.every((i) => i.status == 'served' || i.status == 'cancelled');

  int get ageMinutes => DateTime.now().difference(createdAt).inMinutes;
}
