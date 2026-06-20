// ============================================================================
// In-Store Shopping Screen — Main cart + scan interface
// ============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/in_store_models.dart';
import '../../providers/in_store_providers.dart';
import '../../services/in_store_api_service.dart';
import '../../../../../core/navigation/app_router.dart';

class InStoreShoppingScreen extends ConsumerStatefulWidget {
  const InStoreShoppingScreen({super.key});

  @override
  ConsumerState<InStoreShoppingScreen> createState() =>
      _InStoreShoppingScreenState();
}

class _InStoreShoppingScreenState extends ConsumerState<InStoreShoppingScreen> {
  bool _scannerOpen = false;
  bool _scanProcessing = false;
  final MobileScannerController _scanController = MobileScannerController();

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_scanProcessing) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    setState(() => _scanProcessing = true);
    await _scanController.stop();

    ref.read(scanStateProvider.notifier).state = ScanState.loading;

    final session = ref.read(activeSessionProvider).valueOrNull;
    if (session == null) {
      setState(() {
        _scanProcessing = false;
        _scannerOpen = false;
      });
      return;
    }

    try {
      final product = await ref
          .read(inStoreApiServiceProvider)
          .getProductByBarcode(barcode, session.storeId);

      if (!product.stockAvailable) {
        ref.read(scanStateProvider.notifier).state = ScanState.outOfStock;
        _showScanResult(outOfStock: true, productName: product.name);
        return;
      }

      await ref
          .read(activeSessionProvider.notifier)
          .addOrIncrementItem(product);
      ref.read(scanStateProvider.notifier).state = ScanState.success;
      ref.read(lastScannedProductProvider.notifier).state = product;
      _showScanResult(product: product);
    } on InStoreApiException catch (e) {
      if (e.isNotFound) {
        ref.read(scanStateProvider.notifier).state = ScanState.notFound;
        _showProductNotFound();
      } else {
        ref.read(scanStateProvider.notifier).state = ScanState.error;
        _showError(e.message);
      }
    } catch (_) {
      ref.read(scanStateProvider.notifier).state = ScanState.error;
      _showError('Scan failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _scanProcessing = false);
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && _scannerOpen) _scanController.start();
        });
      }
    }
  }

  void _showScanResult({
    ScannedProduct? product,
    bool outOfStock = false,
    String? productName,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    if (outOfStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${productName ?? 'Item'} is out of stock'),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (product != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${product.name} added',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showProductNotFound() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Product Not Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This item is not in the store catalog. Ask a staff member for help.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                final session = ref.read(activeSessionProvider).valueOrNull;
                if (session == null) {
                  Navigator.pop(context);
                  return;
                }
                try {
                  await ref
                      .read(inStoreApiServiceProvider)
                      .callStaff(session.storeId, 'product_not_found');
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Staff has been notified'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (_) {
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Could not reach staff, please try again',
                      ),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.support_agent),
              label: const Text('Call Staff'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue Shopping'),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeSessionProvider);
    final cartItems = ref.watch(cartItemsProvider);
    final summary = ref.watch(cartSummaryProvider);
    final itemCount = ref.watch(cartItemCountProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => context.go(AppRoutes.inStoreLanding),
          );
          return const SizedBox.shrink();
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.storeName.isNotEmpty
                      ? session.storeName
                      : 'In-Store Shopping',
                ),
                if (itemCount > 0)
                  Text(
                    '$itemCount item${itemCount == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      summary?.totalDisplay ?? '₹0.00',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              // Cart list
              cartItems.isEmpty
                  ? _EmptyCartView(
                      onScan: () => setState(() {
                        _scannerOpen = true;
                        _scanController.start();
                      }),
                    )
                  : _CartList(
                      cartItems: cartItems,
                      onQuantityChanged: (item, qty) => ref
                          .read(activeSessionProvider.notifier)
                          .updateQuantity(item.productId, qty),
                      onRemove: (item) => ref
                          .read(activeSessionProvider.notifier)
                          .removeItem(item.productId),
                    ),

              // Inline scanner overlay
              if (_scannerOpen)
                _ScannerOverlay(
                  controller: _scanController,
                  onDetect: _onBarcodeDetected,
                  onClose: () {
                    _scanController.stop();
                    setState(() => _scannerOpen = false);
                  },
                  isProcessing: _scanProcessing,
                ),
            ],
          ),
          floatingActionButton: _scannerOpen
              ? null
              : FloatingActionButton.extended(
                  onPressed: () {
                    setState(() {
                      _scannerOpen = true;
                      _scanController.start();
                    });
                  },
                  backgroundColor: const Color(0xFF2E7D32),
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  label: const Text(
                    'Scan',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
          bottomNavigationBar: cartItems.isNotEmpty && !_scannerOpen
              ? _ReviewPayBar(
                  summary: summary,
                  onTap: () => context.push(AppRoutes.inStoreCartReview),
                )
              : null,
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Session error: $e'),
              TextButton(
                onPressed: () => context.go(AppRoutes.inStoreLanding),
                child: const Text('Start Over'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty cart ────────────────────────────────────────────────────────────────

class _EmptyCartView extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyCartView({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'Your cart is empty',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the scan button to add items',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan First Item'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cart list ─────────────────────────────────────────────────────────────────

class _CartList extends StatelessWidget {
  final List<CartItem> cartItems;
  final void Function(CartItem, int) onQuantityChanged;
  final void Function(CartItem) onRemove;

  const _CartList({
    required this.cartItems,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: cartItems.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final item = cartItems[index];
        return _CartItemCard(
          item: item,
          onQtyChanged: (qty) => onQuantityChanged(item, qty),
          onRemove: () => onRemove(item),
        );
      },
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final void Function(int) onQtyChanged;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.item,
    required this.onQtyChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final total = item.sellingPrice * item.quantity / 100;
    final hasDiscount = item.discountPercent > 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _PlaceholderImage(),
                    )
                  : _PlaceholderImage(),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.brand != null)
                    Text(
                      item.brand!,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹${(item.sellingPrice / 100).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(width: 6),
                        Text(
                          '₹${(item.mrp / 100).toStringAsFixed(2)}',
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${item.discountPercent.toInt()}% off',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Quantity stepper + total
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                _QuantityStepper(
                  quantity: item.quantity,
                  onChanged: onQtyChanged,
                  onRemove: onRemove,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey.shade200,
      child: Icon(Icons.inventory_2_outlined, color: Colors.grey.shade400),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final void Function(int) onChanged;
  final VoidCallback onRemove;

  const _QuantityStepper({
    required this.quantity,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            if (quantity == 1) {
              onRemove();
            } else {
              onChanged(quantity - 1);
            }
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: quantity == 1 ? Colors.red.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: quantity == 1
                    ? Colors.red.shade300
                    : Colors.grey.shade300,
              ),
            ),
            child: Icon(
              quantity == 1 ? Icons.delete_outline : Icons.remove,
              size: 16,
              color: quantity == 1 ? Colors.red : Colors.grey.shade700,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        GestureDetector(
          onTap: () => onChanged(quantity + 1),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add, size: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ── Review & Pay bottom bar ───────────────────────────────────────────────────

class _ReviewPayBar extends StatelessWidget {
  final CartSummary? summary;
  final VoidCallback onTap;

  const _ReviewPayBar({this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${summary?.itemCount ?? 0} item${(summary?.itemCount ?? 0) == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 15),
            ),
            const Text(
              'Review & Pay',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              summary?.totalDisplay ?? '₹0.00',
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Inline Scanner Overlay ────────────────────────────────────────────────────

class _ScannerOverlay extends StatelessWidget {
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final VoidCallback onClose;
  final bool isProcessing;

  const _ScannerOverlay({
    required this.controller,
    required this.onDetect,
    required this.onClose,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          MobileScanner(controller: controller, onDetect: onDetect),
          // Semi-transparent frame hint
          Center(
            child: Container(
              width: 240,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF4CAF50), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
                shape: const CircleBorder(),
              ),
            ),
          ),
          if (isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: const Text(
              'Point at product barcode',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
