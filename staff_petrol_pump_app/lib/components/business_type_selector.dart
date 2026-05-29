import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/petrol_pump/providers/license_provider.dart';

/// Business Type Selector for Multi-Business Licenses
/// Allows users to switch between available business types
class BusinessTypeSelector extends ConsumerWidget {
  const BusinessTypeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licenseState = ref.watch(licenseStateProvider);
    final license = licenseState.profile;

    if (license == null || !license.isMultiBusiness) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Business Modules',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: license.availableBusinessTypes.map((businessType) {
              return _BusinessTypeChip(
                businessType: businessType,
                isActive: license.businessType == businessType,
                onTap: () => _switchBusinessType(ref, businessType),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'License: ${license.plan.toUpperCase()} • ${license.availableBusinessTypes.length} modules',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _switchBusinessType(WidgetRef ref, String businessType) {
    // This would typically update the user's active business type
    // For now, we'll just show a snackbar
    ScaffoldMessenger.of(ref.context).showSnackBar(
      SnackBar(
        content: Text('Switched to $businessType module'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _BusinessTypeChip extends StatelessWidget {
  final String businessType;
  final bool isActive;
  final VoidCallback onTap;

  const _BusinessTypeChip({
    required this.businessType,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade600 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.blue.shade600 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getBusinessTypeIcon(businessType),
              size: 16,
              color: isActive ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              _getBusinessTypeLabel(businessType),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getBusinessTypeIcon(String businessType) {
    switch (businessType) {
      case 'petrol_pump':
        return Icons.local_gas_station;
      case 'pharmacy':
        return Icons.medication;
      case 'restaurant':
        return Icons.restaurant;
      case 'clinic':
        return Icons.local_hospital;
      case 'grocery':
        return Icons.shopping_cart;
      case 'retail':
        return Icons.store;
      default:
        return Icons.business;
    }
  }

  String _getBusinessTypeLabel(String businessType) {
    switch (businessType) {
      case 'petrol_pump':
        return 'Fuel POS';
      case 'pharmacy':
        return 'Pharmacy';
      case 'restaurant':
        return 'Restaurant';
      case 'clinic':
        return 'Clinic';
      case 'grocery':
        return 'Grocery';
      case 'retail':
        return 'Retail';
      default:
        return businessType.split('_').map((word) => 
          word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }
}
