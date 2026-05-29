// ============================================================
// Dukan Customer App - Store Discovery Screen
// Modern, professional store connection UI
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/marketplace_providers.dart';
import '../../services/marketplace_api_service.dart';
import 'store_home_screen.dart';

class StoreDiscoveryScreen extends ConsumerStatefulWidget {
  const StoreDiscoveryScreen({super.key});

  @override
  ConsumerState<StoreDiscoveryScreen> createState() => _StoreDiscoveryScreenState();
}

class _StoreDiscoveryScreenState extends ConsumerState<StoreDiscoveryScreen> {
  final _storeCodeController = TextEditingController();
  bool _isLoading = false;
  bool _showScanner = false;
  String? _errorMessage;

  @override
  void dispose() {
    _storeCodeController.dispose();
    super.dispose();
  }

  Future<void> _connectToStore(String businessId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(marketplaceApiProvider);
      
      // Get customer profile for connection
      final customerProfile = await ref.read(customerProfileProvider.future);
      
      await api.connectToStore(
        businessId,
        customerName: customerProfile.name ?? 'Customer',
        customerPhone: customerProfile.phone,
      );

      // Set current business and navigate
      ref.read(currentBusinessIdProvider.notifier).state = businessId;
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => StoreHomeScreen(businessId: businessId),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to connect to store');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onScanDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode != null && barcode.rawValue != null) {
      final code = barcode.rawValue!;
      // Expected format: DUKAN:<businessId> or just businessId
      final businessId = code.startsWith('DUKAN:') 
          ? code.substring(6) 
          : code;
      
      setState(() => _showScanner = false);
      _connectToStore(businessId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: _showScanner
            ? _buildScannerView(colorScheme)
            : _buildDiscoveryView(theme, colorScheme),
      ),
    );
  }

  Widget _buildDiscoveryView(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          
          // Logo/Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.storefront,
              size: 60,
              color: colorScheme.onPrimary,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Title
          Text(
            'Find Your Store',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          // Subtitle
          Text(
            'Scan the QR code at your local store or enter the store code to start shopping',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 48),
          
          // Scan QR Button
          ElevatedButton.icon(
            onPressed: () => setState(() => _showScanner = true),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Store QR Code'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: colorScheme.outline)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(child: Divider(color: colorScheme.outline)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Store Code Input
          TextField(
            controller: _storeCodeController,
            decoration: InputDecoration(
              labelText: 'Enter Store Code',
              hintText: 'e.g., STORE123',
              prefixIcon: const Icon(Icons.store),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            ),
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              UpperCaseTextFormatter(),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Error Message
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Connect Button
          FilledButton(
            onPressed: _isLoading
                ? null
                : () => _connectToStore(_storeCodeController.text.trim()),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Connect to Store'),
          ),
          
          const SizedBox(height: 32),
          
          // Info Card
          Card(
            elevation: 0,
            color: colorScheme.primaryContainer.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your local store needs to be registered on Dukan to appear here. Ask them for their store QR code or code.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerView(ColorScheme colorScheme) {
    return Stack(
      children: [
        MobileScanner(
          onDetect: _onScanDetect,
        ),
        
        // Close button
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            onPressed: () => setState(() => _showScanner = false),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
        
        // Scan frame overlay
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: colorScheme.primary,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        
        // Instructions
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Text(
            'Point camera at store QR code',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
              shadows: [
                Shadow(
                  color: colorScheme.surface,
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Text formatter to uppercase input
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// Provider for customer profile
final customerProfileProvider = FutureProvider((ref) async {
  // This would come from your auth/profile service
  return CustomerProfile(name: 'Customer', phone: '');
});

class CustomerProfile {
  final String? name;
  final String phone;
  
  CustomerProfile({this.name, required this.phone});
}
