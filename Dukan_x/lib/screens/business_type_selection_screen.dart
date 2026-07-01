import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import '../providers/app_state_providers.dart';
import '../models/business_type.dart';

class BusinessTypeSelectionScreen extends ConsumerWidget {
  final bool isSettingsMode;

  const BusinessTypeSelectionScreen({super.key, this.isSettingsMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeStateProvider);
    final businessState = ref.watch(businessTypeProvider);
    final palette = theme.palette;
    final isDark = theme.isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Select Business Type',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        ),
      ),
      body: ResponsiveContainer(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                'Choose the category that best fits your business to customize your billing experience.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
            ),
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                crossAxisCount: responsiveValue<int>(
                  context,
                  mobile: 2,
                  tablet: 3,
                  desktop: 4,
                ),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1, // Wider/Shorter cards
                children: BusinessType.values.map((type) {
                  final isSelected = businessState.type == type;
                  return _buildCompactCard(
                    type,
                    isSelected,
                    context,
                    isDark,
                    palette,
                    ref,
                  );
                }).toList(),
              ),
            ),
            if (!isSettingsMode)
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.pushReplacement(RoutePaths.authGate);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.leafGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard(
    BusinessType type,
    bool isSelected,
    BuildContext context,
    bool isDark,
    AppColorPalette palette,
    WidgetRef ref,
  ) {
    IconData icon;
    String label;
    String description;

    // specific icons
    switch (type) {
      case BusinessType.grocery:
        icon = Icons.storefront_rounded;
        label = "Grocery / General";
        description = "Standard MRP billing";
        break;
      case BusinessType.pharmacy:
        icon = Icons.local_pharmacy_rounded;
        label = "Pharmacy";
        description = "Expiry & Batch tracking";
        break;
      case BusinessType.restaurant:
        icon = Icons.restaurant_rounded;
        label = "Restaurant";
        description = "KOT & Table mgmt";
        break;
      case BusinessType.clothing:
        icon = Icons.checkroom_rounded;
        label = "Clothing";
        description = "Size & Color variants";
        break;
      case BusinessType.electronics:
        icon = Icons.phone_android_rounded;
        label = "Electronics";
        description = "IMEI & Serial No";
        break;
      case BusinessType.hardware:
        icon = Icons.handyman_rounded;
        label = "Hardware";
        description = "Dimensions & Units";
        break;
      case BusinessType.clinic:
        icon = Icons.local_hospital_rounded;
        label = "Doctor / Clinic";
        description = "Management System";
        break;
      case BusinessType.service:
        icon = Icons.design_services_rounded;
        label = "Services";
        description = "Labor & Repairs";
        break;
      case BusinessType.wholesale:
        icon = Icons.inventory_2_rounded;
        label = "Wholesale";
        description = "Bulk & Cartons";
        break;
      case BusinessType.petrolPump:
        icon = Icons.local_gas_station_rounded;
        label = "Petrol Pump";
        description = "Fuel & Shift Mgmt";
        break;
      case BusinessType.vegetablesBroker:
        icon = Icons.agriculture_rounded;
        label = "Mandi / Broker";
        description = "Commission & Crates";
        break;
      case BusinessType.mobileShop:
        icon = Icons.smartphone_rounded;
        label = "Mobile Shop";
        description = "Phones & Repairs";
        break;
      case BusinessType.computerShop:
        icon = Icons.computer_rounded;
        label = "Computer Shop";
        description = "Laptops & Acces.";
        break;
      case BusinessType.bookStore:
        icon = Icons.menu_book_rounded;
        label = "Book Store";
        description = "Books & Stationery";
        break;
      case BusinessType.jewellery:
        icon = Icons.diamond_rounded;
        label = "Jewellery Shop";
        description = "Gold, Silver & Purity";
        break;
      case BusinessType.autoParts:
        icon = Icons.build_rounded;
        label = "Auto Parts Shop";
        description = "Vehicle models & Parts";
        break;
      case BusinessType.decorationCatering:
        icon = Icons.celebration_rounded;
        label = "Catering / Decor";
        description = "Events & Catering";
        break;
      case BusinessType.schoolErp:
        icon = Icons.school_rounded;
        label = "School ERP";
        description = "Students & Fees";
        break;
      // Handle 'other' enum case explicitly or default
      case BusinessType.other:
        icon = Icons.business_center_rounded;
        label = "Other";
        description = "Custom Business";
        break;
    }

    final activeColor = palette.leafGreen;

    // Enhanced gradient backgrounds
    final cardBg = isDark
        ? (isSelected ? activeColor.withOpacity(0.18) : const Color(0xFF1E293B))
        : (isSelected ? activeColor.withOpacity(0.1) : Colors.white);

    final borderColor = isSelected
        ? activeColor
        : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200);

    return GestureDetector(
      onTap: () =>
          ref.read(businessTypeProvider.notifier).setBusinessType(type),
      child: AnimatedScale(
        scale: isSelected ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            // Gradient overlay for selected cards
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            activeColor.withOpacity(0.2),
                            activeColor.withOpacity(0.08),
                          ]
                        : [Colors.white, activeColor.withOpacity(0.12)],
                  )
                : null,
            color: isSelected ? null : cardBg,
            borderRadius: BorderRadius.circular(isSelected ? 20 : 16),
            border: Border.all(color: borderColor, width: isSelected ? 2.5 : 1),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: activeColor.withOpacity(isDark ? 0.35 : 0.25),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                )
              else if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              // Secondary glow for selected
              if (isSelected)
                BoxShadow(
                  color: activeColor.withOpacity(0.12),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 12),
                ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated icon with scale and color transition
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1.0, end: isSelected ? 1.15 : 1.0),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Icon(
                            icon,
                            size: 28,
                            color: isSelected
                                ? activeColor
                                : (isDark ? Colors.white70 : Colors.grey[600]),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    // Animated text styling
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        fontSize: isSelected ? 14.5 : 14,
                        color: isSelected
                            ? (isDark
                                  ? Colors.white
                                  : activeColor.withOpacity(0.9))
                            : (isDark ? Colors.white : const Color(0xFF1E293B)),
                      ),
                      child: Text(label, textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 4),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w500
                            : FontWeight.normal,
                        color: isSelected
                            ? (isDark ? Colors.white70 : Colors.grey[700])
                            : (isDark ? Colors.white54 : Colors.grey[500]),
                        height: 1.2,
                      ),
                      child: Text(
                        description,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Animated checkmark badge
              Positioned(
                top: 8,
                right: 8,
                child: AnimatedScale(
                  scale: isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.elasticOut,
                  child: AnimatedOpacity(
                    opacity: isSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
