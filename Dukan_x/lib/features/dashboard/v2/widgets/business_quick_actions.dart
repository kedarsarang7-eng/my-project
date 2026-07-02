import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/app_screens.dart';
import '../../../../core/navigation/navigation_controller.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../models/business_type.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../core/config/business_capabilities.dart';
import '../../../barcode/widgets/wholesale_bulk_scanner_widget.dart';
import '../../../purchase/scan_bill.dart';

/// Business-specific quick actions for Dashboard V2
/// Shows relevant quick action buttons based on business type
class BusinessQuickActions extends ConsumerWidget {
  const BusinessQuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessType = ref.watch(businessTypeProvider).type;
    final capabilities = BusinessCapabilities.get(businessType);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: FuturisticColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: FuturisticColors.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Quick Actions',
                style: TextStyle(
                  color: FuturisticColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _buildActionsForBusiness(
              context,
              ref,
              businessType,
              capabilities,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionsForBusiness(
    BuildContext context,
    WidgetRef ref,
    BusinessType type,
    BusinessCapabilities caps,
  ) {
    final actions = <Widget>[];
    final nav = ref.read(navigationControllerProvider.notifier);

    // Common actions for all business types
    if (caps.accessInvoiceCreate) {
      actions.add(
        _buildActionButton(
          icon: Icons.receipt_long_outlined,
          label: 'New Sale',
          color: FuturisticColors.primary,
          onTap: () => nav.navigateTo(AppScreen.newSale),
        ),
      );
    }

    // Business-specific actions
    switch (type) {
      case BusinessType.grocery:
        actions.add(
          _buildActionButton(
            icon: Icons.add_shopping_cart_outlined,
            label: 'Quick Add Item',
            color: FuturisticColors.success,
            onTap: () => nav.navigateTo(AppScreen.stockEntry),
          ),
        );
        if (caps.supportsBarcodeScan) {
          actions.add(
            _buildActionButton(
              icon: Icons.qr_code_scanner_outlined,
              label: 'Scan Barcode',
              color: FuturisticColors.accent1,
              // Mirror the sibling "Quick Add Item" tile's navigation pattern:
              // route to the New Sale / billing screen, which hosts the working
              // barcode scan flow (_handleBarcodeScan + BarcodeScannerService,
              // reachable via the in-screen "Scan Barcode (F2)" action).
              // NOTE: the scanner is reachable on that screen but not auto-opened.
              // NavigationController.navigateTo is enum-only and carries no args,
              // so auto-opening would require non-trivial plumbing (out of scope
              // for this grocery-scoped fix).
              onTap: () => nav.navigateTo(AppScreen.newSale),
            ),
          );
        }
        actions.add(
          _buildActionButton(
            icon: Icons.warning_amber_outlined,
            label: 'Expiry Check',
            color: FuturisticColors.warning,
            onTap: () => nav.navigateTo(AppScreen.batchTracking),
          ),
        );
        // OCR "Scan Bill" → reuses the existing AWS Textract Smart Inventory
        // Import pipeline (features/purchase/scan_bill.dart). Flag-independent:
        // launches the pipeline's own entry flow directly, so grocery can reach
        // OCR purchase-entry today (closing the "exists nowhere reachable" gap)
        // regardless of the go_router migration flag. Gated by supportsTextOCR
        // (== useScanOCR), which grocery is granted.
        if (caps.supportsTextOCR) {
          actions.add(
            _buildActionButton(
              icon: Icons.document_scanner_outlined,
              label: 'Scan Bill (OCR)',
              color: FuturisticColors.accent2,
              onTap: () =>
                  ScanBillNavigator.start(context, verticalType: type.name),
            ),
          );
        }
        break;

      case BusinessType.pharmacy:
        // Pharmacy quick-action cards carry explicit, non-empty semantic
        // labels so assistive technologies announce each card's action
        // (R26.4). Other verticals are left unchanged (label defaults to null).
        actions.add(
          _buildActionButton(
            icon: Icons.description_outlined,
            label: 'New Prescription',
            color: FuturisticColors.success,
            onTap: () => nav.navigateTo(AppScreen.prescriptions),
            semanticLabel: 'New Prescription, create a new prescription',
          ),
        );
        if (caps.supportsPrescriptions) {
          actions.add(
            _buildActionButton(
              icon: Icons.medication_outlined,
              label: 'Drug Lookup',
              color: FuturisticColors.accent1,
              onTap: () => nav.navigateTo(AppScreen.medicineMaster),
              semanticLabel: 'Drug Lookup, search the medicine master',
            ),
          );
        }
        actions.add(
          _buildActionButton(
            icon: Icons.shield_outlined,
            label: 'H1 Register',
            color: FuturisticColors.error,
            onTap: () => nav.navigateTo(AppScreen.h1Register),
            semanticLabel: 'H1 Register, open the H1 schedule drug register',
          ),
        );
        break;

      case BusinessType.restaurant:
        actions.add(
          _buildActionButton(
            icon: Icons.table_restaurant_outlined,
            label: 'Table View',
            color: FuturisticColors.success,
            onTap: () => nav.navigateTo(AppScreen.restaurantTables),
          ),
        );
        if (caps.accessKOT) {
          actions.add(
            _buildActionButton(
              icon: Icons.soup_kitchen_outlined,
              label: 'Kitchen Display',
              color: FuturisticColors.accent1,
              onTap: () => nav.navigateTo(AppScreen.kitchenDisplay),
            ),
          );
        }
        actions.add(
          _buildActionButton(
            icon: Icons.restaurant_menu_outlined,
            label: 'Menu Mgmt',
            color: FuturisticColors.accent2,
            onTap: () => nav.navigateTo(AppScreen.menuManagement),
          ),
        );
        break;

      case BusinessType.clothing:
        actions.add(
          _buildActionButton(
            icon: Icons.checkroom_outlined,
            label: 'Size Check',
            color: FuturisticColors.success,
            onTap: () => nav.navigateTo(AppScreen.itemStock),
          ),
        );
        if (caps.supportsStock) {
          actions.add(
            _buildActionButton(
              icon: Icons.palette_outlined,
              label: 'Variants',
              color: FuturisticColors.accent1,
              onTap: () => context.go('/clothing/variants'),
            ),
          );
        }
        break;

      case BusinessType.electronics:
      case BusinessType.mobileShop:
      case BusinessType.computerShop:
        actions.add(
          _buildActionButton(
            icon: Icons.build_outlined,
            label: 'New Repair',
            color: FuturisticColors.success,
            // Route through the guarded /job/create path so the manageStaff
            // authority check (VendorRoleGuard) is enforced consistently with
            // the route guard stack (Property 8 / Requirement 2.21).
            onTap: () => context.push('/job/create'),
            semanticLabel: 'New Repair, create a new service repair job',
          ),
        );
        if (caps.supportsSerialNumber) {
          actions.add(
            _buildActionButton(
              icon: Icons.confirmation_number_outlined,
              label: 'IMEI Lookup',
              color: FuturisticColors.accent1,
              // Electronics has a dedicated IMEI tracking destination
              // (/electronics/imei-tracking, Phase 2 task 8.2). mobileShop and
              // computerShop keep their existing serial-history destination
              // unchanged (Preservation 3.6).
              onTap: () => context.push(
                type == BusinessType.electronics
                    ? '/electronics/imei-tracking'
                    : '/computer-shop/serial-history',
              ),
              semanticLabel: 'IMEI Lookup, search serial or IMEI tracking',
            ),
          );
        }
        if (type == BusinessType.mobileShop) {
          actions.add(
            _buildActionButton(
              icon: Icons.loop_outlined,
              label: 'Exchange',
              color: FuturisticColors.accent2,
              onTap: () => nav.navigateTo(AppScreen.exchanges),
              semanticLabel: 'Exchange, manage device exchange or trade-in',
            ),
          );
        }
        break;

      case BusinessType.hardware:
        actions.add(
          _buildActionButton(
            icon: Icons.request_quote_outlined,
            label: 'New Quote',
            color: FuturisticColors.success,
            onTap: () => nav.navigateTo(AppScreen.proformaBids),
          ),
        );
        actions.add(
          _buildActionButton(
            icon: Icons.local_shipping_outlined,
            label: 'Delivery Challan',
            color: FuturisticColors.accent1,
            onTap: () => nav.navigateTo(AppScreen.deliveryChallans),
          ),
        );
        actions.add(
          _buildActionButton(
            icon: Icons.engineering_outlined,
            label: 'Projects',
            color: FuturisticColors.accent2,
            onTap: () => nav.navigateTo(AppScreen.hardwareOperations),
          ),
        );
        break;

      case BusinessType.petrolPump:
        actions.add(
          _buildActionButton(
            icon: Icons.local_gas_station_outlined,
            label: 'Shift Start',
            color: FuturisticColors.success,
            onTap: () => nav.navigateTo(AppScreen.shiftManagement),
          ),
        );
        actions.add(
          _buildActionButton(
            icon: Icons.water_drop_outlined,
            label: 'Tank Levels',
            color: FuturisticColors.accent1,
            onTap: () => nav.navigateTo(AppScreen.tankManagement),
          ),
        );
        actions.add(
          _buildActionButton(
            icon: Icons.price_change_outlined,
            label: 'Fuel Rates',
            color: FuturisticColors.accent2,
            onTap: () => nav.navigateTo(AppScreen.fuelRates),
          ),
        );
        break;

      case BusinessType.bookStore:
        actions.add(
          _buildActionButton(
            icon: Icons.menu_book_outlined,
            label: 'Book Search',
            color: FuturisticColors.success,
            onTap: () => nav.navigateTo(AppScreen.bookCatalogue),
          ),
        );
        if (caps.supportsTextOCR) {
          actions.add(
            _buildActionButton(
              icon: Icons.document_scanner_outlined,
              label: 'ISBN Scan',
              color: FuturisticColors.accent1,
              onTap: () => nav.navigateTo(AppScreen.bookPos),
            ),
          );
        }
        actions.add(
          _buildActionButton(
            icon: Icons.assignment_return_outlined,
            label: 'Returns',
            color: FuturisticColors.accent2,
            onTap: () => nav.navigateTo(AppScreen.bookReturns),
          ),
        );
        break;

      case BusinessType.autoParts:
        actions.add(
          _buildActionButton(
            icon: Icons.search_outlined,
            label: 'Part Search',
            color: FuturisticColors.success,
            onTap: () => nav.navigateTo(AppScreen.itemStock),
          ),
        );
        actions.add(
          _buildActionButton(
            icon: Icons.minor_crash_outlined,
            label: 'Request Part',
            color: FuturisticColors.accent1,
            onTap: () => nav.navigateTo(AppScreen.purchaseOrders),
          ),
        );
        break;

      case BusinessType.wholesale:
        actions.add(
          _buildActionButton(
            icon: Icons.inventory_2_outlined,
            label: 'Bulk Entry',
            color: FuturisticColors.success,
            onTap: () => nav.navigateTo(AppScreen.stockEntry),
          ),
        );
        if (caps.supportsBarcodeScan) {
          actions.add(
            _buildActionButton(
              icon: Icons.qr_code_scanner_outlined,
              label: 'Bulk Scan',
              color: FuturisticColors.accent1,
              onTap: () => showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => WholesaleBulkScannerWidget(
                  onCancel: () => Navigator.of(context).pop(),
                  onComplete: (result) {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          );
        }
        actions.add(
          _buildActionButton(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Credit Check',
            color: FuturisticColors.accent2,
            onTap: () => nav.navigateTo(AppScreen.outstanding),
          ),
        );
        break;

      case BusinessType.decorationCatering:
        actions.add(
          _buildActionButton(
            icon: Icons.event_outlined,
            label: 'New Booking',
            color: FuturisticColors.success,
            onTap: () => nav.navigateTo(AppScreen.dcBookings),
            semanticLabel: 'New Booking, create a new event booking',
          ),
        );
        actions.add(
          _buildActionButton(
            icon: Icons.request_quote_outlined,
            label: 'New Quote',
            color: FuturisticColors.accent1,
            onTap: () => nav.navigateTo(AppScreen.dcQuotes),
            semanticLabel:
                'New Quote, create a new decoration or catering quote',
          ),
        );
        actions.add(
          _buildActionButton(
            icon: Icons.person_add_outlined,
            label: 'Add Staff',
            color: FuturisticColors.accent2,
            onTap: () => nav.navigateTo(AppScreen.dcStaff),
            semanticLabel: 'Add Staff, manage decoration and catering staff',
          ),
        );
        actions.add(
          _buildActionButton(
            icon: Icons.restaurant_menu_outlined,
            label: 'Menu/Package',
            color: FuturisticColors.primary,
            onTap: () => nav.navigateTo(AppScreen.dcCateringMenu),
            semanticLabel:
                'Menu or Package, manage catering menus and packages',
          ),
        );
        break;

      case BusinessType.vegetablesBroker:
        actions.add(
          _buildActionButton(
            icon: Icons.add_shopping_cart_outlined,
            label: 'New Lot Entry',
            color: FuturisticColors.success,
            onTap: () => _navigateMandiAction(
              context,
              ref,
              AppScreen.mandiLotEntry,
              'New Lot Entry',
            ),
          ),
        );
        actions.add(
          _buildActionButton(
            icon: Icons.agriculture_outlined,
            label: 'Farmer List',
            color: FuturisticColors.accent1,
            onTap: () => _navigateMandiAction(
              context,
              ref,
              AppScreen.mandiFarmerLedger,
              'Farmer List',
            ),
          ),
        );
        break;

      case BusinessType.jewellery:
        actions.add(
          _buildActionButton(
            icon: Icons.diamond_outlined,
            label: 'Custom Order',
            color: FuturisticColors.success,
            onTap: () => nav.navigateTo(AppScreen.jewelleryCustomOrders),
            semanticLabel: 'Custom Order, manage jewellery custom orders',
          ),
        );
        actions.add(
          _buildActionButton(
            icon: Icons.trending_up_outlined,
            label: 'Gold Rate',
            color: FuturisticColors.accent1,
            onTap: () => nav.navigateTo(AppScreen.jewelleryGoldRate),
            semanticLabel: 'Gold Rate, view and set daily gold rates',
          ),
        );
        break;

      case BusinessType.service:
        actions.add(
          _buildActionButton(
            icon: Icons.build_circle_outlined,
            label: 'New Job Sheet',
            color: FuturisticColors.success,
            onTap: () => nav.navigateTo(AppScreen.serviceJobs),
          ),
        );
        actions.add(
          _buildActionButton(
            icon: Icons.pending_actions_outlined,
            label: 'Open Jobs',
            color: FuturisticColors.accent1,
            onTap: () => nav.navigateTo(AppScreen.serviceJobs),
          ),
        );
        break;

      case BusinessType.schoolErp:
        actions.add(
          _buildActionButton(
            icon: Icons.payments_outlined,
            label: 'Collect Fee',
            color: FuturisticColors.success,
            onTap: () => context.push('/ac/fees'),
          ),
        );
        actions.add(
          _buildActionButton(
            icon: Icons.person_add_outlined,
            label: 'New Admission',
            color: FuturisticColors.accent1,
            onTap: () => context.push('/ac/students/register'),
          ),
        );
        actions.add(
          _buildActionButton(
            icon: Icons.fact_check_outlined,
            label: 'Mark Attendance',
            color: FuturisticColors.accent2,
            onTap: () => context.push('/ac/attendance'),
          ),
        );
        actions.add(
          _buildActionButton(
            icon: Icons.grade_outlined,
            label: 'Enter Marks',
            color: FuturisticColors.primary,
            onTap: () => context.push('/ac/exams'),
          ),
        );
        break;

      case BusinessType.clinic:
        actions.add(
          _buildActionButton(
            icon: Icons.person_add_outlined,
            label: 'New Patient',
            color: FuturisticColors.success,
            onTap: () => nav.navigateTo(AppScreen.addPatient),
          ),
        );
        actions.add(
          _buildActionButton(
            icon: Icons.event_note_outlined,
            label: 'Appointments',
            color: FuturisticColors.accent1,
            onTap: () => nav.navigateTo(AppScreen.appointments),
          ),
        );
        actions.add(
          _buildActionButton(
            icon: Icons.description_outlined,
            label: 'Write Rx',
            color: FuturisticColors.accent2,
            onTap: () => nav.navigateTo(AppScreen.prescriptions),
          ),
        );
        break;

      default:
        // Generic actions for 'other'
        actions.add(
          _buildActionButton(
            icon: Icons.person_add_outlined,
            label: 'Add Customer',
            color: FuturisticColors.success,
            onTap: () => nav.navigateTo(AppScreen.addCustomer),
          ),
        );
        actions.add(
          _buildActionButton(
            icon: Icons.analytics_outlined,
            label: 'Reports',
            color: FuturisticColors.accent2,
            onTap: () => nav.navigateTo(AppScreen.reportsHub),
          ),
        );
    }

    // Common ending action for all
    if (caps.accessLowStockAlert) {
      actions.add(
        _buildActionButton(
          icon: Icons.notifications_outlined,
          label: 'Alerts',
          color: FuturisticColors.warning,
          onTap: () => nav.navigateTo(AppScreen.alerts),
        ),
      );
    }

    return actions;
  }

  /// Navigates to a Mandi quick-action target screen (R12.3, R12.4, R12.5).
  ///
  /// On success, the target screen opens within 1 second via the
  /// [NavigationController]. On failure (e.g. the screen cannot be resolved),
  /// a navigation-failed error is shown and no legacy redirect occurs — the
  /// user stays on the current screen.
  void _navigateMandiAction(
    BuildContext context,
    WidgetRef ref,
    AppScreen target,
    String actionLabel,
  ) {
    try {
      final nav = ref.read(navigationControllerProvider.notifier);
      nav.navigateTo(target);
    } catch (_) {
      // Navigation failed — show error, no legacy redirect (R12.5).
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigation failed: could not open $actionLabel'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? semanticLabel,
  }) {
    final Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: FuturisticColors.textPrimary.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // When a non-empty semantic label is supplied (pharmacy quick-action
    // cards, R26.4), expose it to assistive technologies as a button.
    // Callers that omit it keep the original tree unchanged.
    if (semanticLabel != null && semanticLabel.isNotEmpty) {
      return Semantics(
        label: semanticLabel,
        button: true,
        container: true,
        child: button,
      );
    }
    return button;
  }
}
