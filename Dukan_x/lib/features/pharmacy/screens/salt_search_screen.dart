import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/di/service_locator.dart';
import 'package:dukanx/core/responsive/responsive.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class SaltSearchResult {
  final String saltName;
  final String? genericName;
  final List<BrandedAlternative> brands;

  const SaltSearchResult({
    required this.saltName,
    this.genericName,
    required this.brands,
  });

  factory SaltSearchResult.fromJson(Map<String, dynamic> j) => SaltSearchResult(
        saltName: j['saltName'] as String,
        genericName: j['genericName'] as String?,
        brands: (j['brands'] as List<dynamic>? ?? [])
            .map((e) => BrandedAlternative.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class BrandedAlternative {
  final String productId;
  final String productName;
  final String? manufacturer;
  final double? mrp;
  final double stockQuantity;
  final String? drugSchedule;
  final String? strength;

  const BrandedAlternative({
    required this.productId,
    required this.productName,
    this.manufacturer,
    this.mrp,
    required this.stockQuantity,
    this.drugSchedule,
    this.strength,
  });

  factory BrandedAlternative.fromJson(Map<String, dynamic> j) =>
      BrandedAlternative(
        productId: j['productId'] as String? ?? '',
        productName: j['productName'] as String,
        manufacturer: j['manufacturer'] as String?,
        mrp: (j['mrp'] as num?)?.toDouble(),
        stockQuantity: (j['stockQuantity'] as num?)?.toDouble() ?? 0,
        drugSchedule: j['drugSchedule'] as String?,
        strength: j['strength'] as String?,
      );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final _saltResultsProvider =
    FutureProvider.family<List<SaltSearchResult>, String>((ref, query) async {
  if (query.trim().length < 2) return [];
  final api = sl<ApiClient>();
  final res = await api.get(
    '/pharmacy/salt-search',
    queryParams: {'q': query.trim(), 'limit': '10'},
  );
  if (!res.isSuccess || res.data == null) return [];
  final items = res.data!['items'] as List<dynamic>? ?? [];
  return items
      .map((e) => SaltSearchResult.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─── Screen ───────────────────────────────────────────────────────────────────

/// Salt / Generic name search screen.
/// Allows a pharmacist to search by salt/molecule name and see all
/// branded alternatives available in the inventory.
class SaltSearchScreen extends ConsumerStatefulWidget {
  /// Optional callback: called when pharmacist selects a branded product
  /// to add to the current bill.
  final void Function(BrandedAlternative product)? onProductSelected;

  const SaltSearchScreen({super.key, this.onProductSelected});

  @override
  ConsumerState<SaltSearchScreen> createState() => _SaltSearchScreenState();
}

class _SaltSearchScreenState extends ConsumerState<SaltSearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(_saltResultsProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salt / Generic Search'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Center(
            child: BoundedBox(
              maxWidth: 800,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search by salt or generic name…',
                    prefixIcon: const Icon(Icons.science_outlined),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: BoundedBox(
          maxWidth: 800,
          child: _query.trim().length < 2
              ? const _EmptyHint()
              : resultsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (results) {
                    if (results.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off,
                                size: 56, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              'No results for "$_query"',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: results.length,
                      itemBuilder: (_, i) => _SaltResultCard(
                        result: results[i],
                        onProductSelected: widget.onProductSelected,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science_outlined, size: 64, color: Colors.teal.shade200),
          const SizedBox(height: 16),
          const Text(
            'Type a salt or generic name\nto find branded alternatives',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
          const SizedBox(height: 8),
          const Text(
            'e.g. Paracetamol, Amoxicillin, Metformin',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SaltResultCard extends StatelessWidget {
  final SaltSearchResult result;
  final void Function(BrandedAlternative)? onProductSelected;

  const _SaltResultCard({required this.result, this.onProductSelected});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade50,
          child: Icon(Icons.science, color: Colors.teal.shade700, size: 20),
        ),
        title: Text(result.saltName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: result.genericName != null
            ? Text('Generic: ${result.genericName}',
                style: const TextStyle(fontSize: 12))
            : null,
        trailing: Chip(
          label: Text('${result.brands.length} brand${result.brands.length == 1 ? '' : 's'}'),
          backgroundColor: Colors.teal.shade50,
          labelStyle: TextStyle(color: Colors.teal.shade800, fontSize: 12),
        ),
        children: result.brands.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No branded alternatives in inventory.',
                      style: TextStyle(color: Colors.grey)),
                )
              ]
            : result.brands
                .map((b) => _BrandTile(
                      brand: b,
                      onSelect: onProductSelected != null
                          ? () => onProductSelected!(b)
                          : null,
                    ))
                .toList(),
      ),
    );
  }
}

class _BrandTile extends StatelessWidget {
  final BrandedAlternative brand;
  final VoidCallback? onSelect;

  const _BrandTile({required this.brand, this.onSelect});

  @override
  Widget build(BuildContext context) {
    final inStock = brand.stockQuantity > 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(
        Icons.medication,
        color: inStock ? Colors.green : Colors.grey,
        size: 20,
      ),
      title: Text(
        brand.productName,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: inStock ? null : Colors.grey,
        ),
      ),
      subtitle: Row(
        children: [
          if (brand.strength != null)
            _Tag(brand.strength!, Colors.blue.shade50, Colors.blue.shade700),
          if (brand.drugSchedule != null &&
              brand.drugSchedule != 'none' &&
              brand.drugSchedule!.isNotEmpty) ...[
            const SizedBox(width: 4),
            _Tag('Sch ${brand.drugSchedule}', Colors.orange.shade50,
                Colors.orange.shade800),
          ],
          if (!inStock) ...[
            const SizedBox(width: 4),
            _Tag('Out of stock', Colors.red.shade50, Colors.red.shade700),
          ],
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (brand.mrp != null)
            Text('₹${brand.mrp!.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          if (brand.manufacturer != null)
            Text(brand.manufacturer!,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
      onTap: (onSelect != null && inStock) ? onSelect : null,
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Tag(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: fg)),
    );
  }
}
