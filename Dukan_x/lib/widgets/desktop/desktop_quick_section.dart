import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/futuristic_colors.dart';
import '../../providers/app_state_providers.dart';
import '../../core/isolation/business_capability.dart';
import '../../core/isolation/feature_resolver.dart';
import '../../features/onboarding/onboarding_models.dart';
import '../../models/business_type.dart';

// Screens for navigation
import '../../features/billing/presentation/screens/bill_creation_screen_v2.dart';
import '../../features/settings/presentation/screens/main_settings_screen.dart';
import '../../features/inventory/presentation/widgets/add_edit_product_sheet.dart';
import '../../features/customers/presentation/screens/add_customer_screen.dart';

import '../../features/staff/presentation/screens/staff_list_screen.dart';
import '../../features/restaurant/presentation/screens/table_management_screen.dart';
import '../../features/service/presentation/screens/create_service_job_screen.dart';
import '../../features/service/presentation/screens/service_job_list_screen.dart';

class DesktopQuickSection extends ConsumerWidget {
  const DesktopQuickSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessTypeState = ref.watch(businessTypeProvider);
    final businessType = businessTypeState.type;
    final typeName = businessType.name;
    final config = BusinessTypeConfig.getConfig(businessType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1E2235))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: config.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(config.emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      config.name,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Actions List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. COMMONS (Always visible)
              _buildSectionLabel('ESSENTIALS'),
              _buildQuickAction(
                context,
                icon: Icons.add_circle_outline,
                label: 'New Invoice',
                color: FuturisticColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BillCreationScreenV2(),
                  ),
                ),
              ),
              _buildQuickAction(
                context,
                icon: Icons.person_add_outlined,
                label: 'Add Customer',
                color: FuturisticColors.secondary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
                ),
              ),

              // 2. INVENTORY (Gated)
              if (FeatureResolver.canAccess(
                typeName,
                BusinessCapability.useStockManagement,
              )) ...[
                const SizedBox(height: 16),
                _buildSectionLabel('INVENTORY'),
                _buildQuickAction(
                  context,
                  icon: Icons.inventory_2_outlined,
                  label: 'Add Product',
                  color: Colors.orange,
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const AddEditProductSheet(),
                  ),
                ),
              ],

              // 3. RESTAURANT EXCLUSIVES
              // 3. RESTAURANT EXCLUSIVES
              if (businessType == BusinessType.restaurant) ...[
                const SizedBox(height: 16),
                _buildSectionLabel('KITCHEN & TABLES'),
                _buildQuickAction(
                  context,
                  icon: Icons.table_restaurant_rounded,
                  label: 'Table View',
                  color: Colors.pink,
                  onTap: () {
                    final vendorId = ref.read(authStateProvider).ownerId ?? '';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TableManagementScreen(vendorId: vendorId),
                      ),
                    );
                  },
                ),
                _buildQuickAction(
                  context,
                  icon: Icons.soup_kitchen_outlined,
                  label: 'KOT Display',
                  color: Colors.redAccent,
                  onTap: () {
                    // Navigate to KOT
                  },
                ),
              ],

              // 4. PHARMACY EXCLUSIVES
              if (businessType == BusinessType.pharmacy) ...[
                const SizedBox(height: 16),
                _buildSectionLabel('PHARMACY'),
                _buildQuickAction(
                  context,
                  icon: Icons.medication_outlined,
                  label: 'Expiring Soon',
                  color: Colors.red,
                  onTap: () {
                    // Navigate to expiry report
                  },
                ),
                _buildQuickAction(
                  context,
                  icon: Icons.local_hospital_outlined,
                  label: 'Doctor Registry',
                  color: Colors.teal,
                  onTap: () {
                    // Navigate to doctor list
                  },
                ),
              ],

              // 5. SERVICES (Repair/Salon)
              if (businessType == BusinessType.service ||
                  businessType == BusinessType.mobileShop ||
                  businessType == BusinessType.computerShop) ...[
                const SizedBox(height: 16),
                _buildSectionLabel('SERVICE & REPAIR'),
                _buildQuickAction(
                  context,
                  icon: Icons.build_circle_outlined,
                  label: 'New Job Sheet',
                  color: Colors.blueAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateServiceJobScreen(),
                      ),
                    );
                  },
                ),
                _buildQuickAction(
                  context,
                  icon: Icons.task_alt_outlined,
                  label: 'Job Status',
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ServiceJobListScreen(),
                      ),
                    );
                  },
                ),
              ],

              // 6. STAFF (Restaurant / Service primarily, but useful for all)
              if (businessType == BusinessType.restaurant ||
                  businessType == BusinessType.service) ...[
                const SizedBox(height: 16),
                _buildSectionLabel('MANAGEMENT'),
                _buildQuickAction(
                  context,
                  icon: Icons.badge_outlined,
                  label: 'Staff Attendance',
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StaffListScreen()),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              // Settings Link
              _buildQuickAction(
                context,
                icon: Icons.settings_outlined,
                label: 'Business Settings',
                color: Colors.grey,
                isMinimal: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isMinimal = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.white.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isMinimal
                  ? Colors.transparent
                  : const Color(0xFF1E293B).withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: isMinimal
                  ? Border.all(color: Colors.white.withOpacity(0.1))
                  : Border.all(color: color.withOpacity(0.1)),
              boxShadow: isMinimal
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color:
                          Colors.white, // Always white for dark theme desktop
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (!isMinimal)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
