import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/di/service_locator.dart';
import '../core/theme/futuristic_colors.dart';
import '../services/connection_service.dart';
import '../core/session/session_manager.dart';
import '../widgets/ui/quick_action_toolbar.dart';
import '../widgets/ui/futuristic_button.dart';

class ShopSelectionScreen extends ConsumerStatefulWidget {
  const ShopSelectionScreen({super.key});

  @override
  ConsumerState<ShopSelectionScreen> createState() =>
      _ShopSelectionScreenState();
}

class _ShopSelectionScreenState extends ConsumerState<ShopSelectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopIdController = TextEditingController();

  bool _isLoading = false;
  List<Map<String, dynamic>> _linkedShops = [];
  String? _customerId;

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  @override
  void dispose() {
    _shopIdController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerData() async {
    setState(() => _isLoading = true);
    _customerId = sl<SessionManager>().userId;

    try {
      if (_customerId != null) {
        final connections = await sl<ConnectionService>()
            .getAcceptedConnections();
        setState(() {
          _linkedShops = connections;
        });
      }
    } catch (e) {
      debugPrint('Error loading customer data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _linkShop() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final shopIdOrName = _shopIdController.text.trim();
      final shops = await sl<ConnectionService>().searchShops(shopIdOrName);

      if (shops.isEmpty) {
        throw Exception('Shop not found. Please check the Shop ID or Name.');
      }

      final shopData = shops.first;
      final shopId = shopData['id'] as String;

      if (_linkedShops.any((shop) => shop['id'] == shopId)) {
        throw Exception('This shop is already linked to your account.');
      }

      await sl<ConnectionService>().linkShop(shopId);

      _shopIdController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request sent! Wait for approval.')),
        );
      }
      await _loadCustomerData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: FuturisticColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unlinkShop(String shopId, String shopName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Shop?'),
        content: Text('Remove "$shopName" from your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Unlink',
              style: TextStyle(color: FuturisticColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await sl<ConnectionService>().unlinkShop(shopId);
      await _loadCustomerData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return Scaffold(
      backgroundColor: FuturisticColors.background,
      body: ResponsiveContainer(
        child: Column(
          children: [
            QuickActionToolbar(
              title: 'My Connected Shops',
              actions: [
                IconButton(
                  onPressed: _loadCustomerData,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAddShopSection(isMobile),
                          const SizedBox(height: 32),
                          const Text(
                            "LINKED SHOPS",
                            style: TextStyle(
                              color: FuturisticColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _linkedShops.isEmpty
                                ? _buildEmptyState()
                                : GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 300,
                                          mainAxisSpacing: 16,
                                          crossAxisSpacing: 16,
                                          childAspectRatio: 1.5,
                                        ),
                                    itemCount: _linkedShops.length,
                                    itemBuilder: (context, index) {
                                      return _buildShopCard(_linkedShops[index]);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddShopSection(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FuturisticColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FuturisticColors.border),
      ),
      child: Form(
        key: _formKey,
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Link a New Shop',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: FuturisticColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter the Shop ID provided by the store owner to connect.',
                    style: TextStyle(color: FuturisticColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _shopIdController,
                    style: const TextStyle(color: FuturisticColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Enter Shop ID / Name',
                      prefixIcon: Icon(
                        Icons.store,
                        color: FuturisticColors.primary,
                      ),
                      filled: true,
                      fillColor: FuturisticColors.background,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  FuturisticButton.primary(
                    label: 'Connect',
                    icon: Icons.link,
                    onPressed: _linkShop,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Link a New Shop',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: FuturisticColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Enter the Shop ID provided by the store owner to connect.',
                          style: TextStyle(color: FuturisticColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 300,
                    child: TextFormField(
                      controller: _shopIdController,
                      style: const TextStyle(color: FuturisticColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Enter Shop ID / Name',
                        prefixIcon: Icon(
                          Icons.store,
                          color: FuturisticColors.primary,
                        ),
                        filled: true,
                        fillColor: FuturisticColors.background,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  FuturisticButton.primary(
                    label: 'Connect',
                    icon: Icons.link,
                    onPressed: _linkShop,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shop) {
    return Container(
      decoration: BoxDecoration(
        color: FuturisticColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FuturisticColors.border),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Navigate to shop detail or view bills
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: FuturisticColors.primary.withOpacity(
                        0.1,
                      ),
                      child: const Icon(
                        Icons.store,
                        color: FuturisticColors.primary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.link_off,
                        size: 20,
                        color: FuturisticColors.error,
                      ),
                      tooltip: 'Unlink',
                      onPressed: () =>
                          _unlinkShop(shop['id'], shop['shopName'] ?? ''),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  shop['shopName'] ?? 'Unknown Shop',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: FuturisticColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  shop['phone'] ?? 'No Phone',
                  style: const TextStyle(color: FuturisticColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.storefront,
            size: 64,
            color: FuturisticColors.textSecondary,
          ),
          SizedBox(height: 16),
          Text(
            'No Shops Linked',
            style: TextStyle(
              fontSize: 18,
              color: FuturisticColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
