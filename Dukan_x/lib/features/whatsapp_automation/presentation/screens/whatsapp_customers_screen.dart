// ============================================================================
// WhatsApp Customers Screen — Customer list with consent management
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../data/models/whatsapp_customer_model.dart';
import '../providers/whatsapp_customers_provider.dart';
import '../widgets/consent_badge.dart';

/// WhatsApp Customers Screen — customer list with consent badge, add, toggle consent.
class WhatsAppCustomersScreen extends ConsumerWidget {
  const WhatsAppCustomersScreen({super.key});

  /// Validates E.164 phone number format: + followed by 8-15 digits.
  static bool isValidE164(String phone) {
    return RegExp(r'^\+\d{8,15}$').hasMatch(phone.trim());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(whatsappCustomersProvider);

    return Scaffold(
      backgroundColor: FuturisticColors.background,
      appBar: AppBar(
        title: Text(
          'WhatsApp Customers',
          style: AppTypography.headlineSmall.copyWith(
            color: FuturisticColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: FuturisticColors.textPrimary),
        actions: [
          IconButton(
            onPressed: () => _showAddDialog(context, ref),
            icon: Icon(Icons.person_add, color: FuturisticColors.primary),
            tooltip: 'Add Customer',
          ),
        ],
      ),
      body: BoundedBox(maxWidth: 800, child: _buildBody(context, ref, state)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    WhatsAppCustomersState state,
  ) {
    if (state.isDisabled) {
      return Center(
        child: Text(
          'Customers feature is not available.',
          style: TextStyle(color: FuturisticColors.textMuted),
        ),
      );
    }

    if (state.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: FuturisticColors.primary),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: FuturisticColors.error),
            const SizedBox(height: 8),
            Text(state.error!, style: TextStyle(color: FuturisticColors.error)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  ref.read(whatsappCustomersProvider.notifier).loadCustomers(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: FuturisticColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'No WhatsApp customers yet.',
              style: TextStyle(color: FuturisticColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 12, tablet: 16, desktop: 20),
      ),
      itemCount: state.customers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final customer = state.customers[index];
        return _CustomerCard(
          customer: customer,
          onConsentToggle: () => _showConsentDialog(context, ref, customer),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final phoneCtrl = TextEditingController();
    String? phoneError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add WhatsApp Customer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(
                  labelText: 'WhatsApp Number *',
                  hintText: '+91XXXXXXXXXX',
                  errorText: phoneError,
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                onChanged: (v) {
                  if (phoneError != null) {
                    setDialogState(() => phoneError = null);
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Enter number in E.164 format: + followed by 8-15 digits.',
                style: TextStyle(
                  color: FuturisticColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final phone = phoneCtrl.text.trim();
                if (!isValidE164(phone)) {
                  setDialogState(() {
                    phoneError = 'Invalid E.164 format (e.g. +919876543210)';
                  });
                  return;
                }
                Navigator.pop(ctx);
                ref
                    .read(whatsappCustomersProvider.notifier)
                    .createCustomer(whatsappNumber: phone);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showConsentDialog(
    BuildContext context,
    WidgetRef ref,
    WhatsAppCustomer customer,
  ) {
    final auditNoteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Consent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current: ${customer.consentState.value}',
              style: TextStyle(color: FuturisticColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: auditNoteCtrl,
              decoration: const InputDecoration(
                labelText: 'Audit Note *',
                hintText: 'Reason for consent change (required)',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Text(
              'A note is required for the audit trail.',
              style: TextStyle(color: FuturisticColors.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (auditNoteCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              ref
                  .read(whatsappCustomersProvider.notifier)
                  .setConsent(
                    customer.id,
                    ConsentState.optedIn,
                    auditNote: auditNoteCtrl.text.trim(),
                  );
            },
            child: Text(
              'Opt In',
              style: TextStyle(color: FuturisticColors.success),
            ),
          ),
          TextButton(
            onPressed: () {
              if (auditNoteCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              ref
                  .read(whatsappCustomersProvider.notifier)
                  .setConsent(
                    customer.id,
                    ConsentState.optedOut,
                    auditNote: auditNoteCtrl.text.trim(),
                  );
            },
            child: Text(
              'Opt Out',
              style: TextStyle(color: FuturisticColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Customer Card ─────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  final WhatsAppCustomer customer;
  final VoidCallback onConsentToggle;

  const _CustomerCard({required this.customer, required this.onConsentToggle});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 12.0,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.person, color: Color(0xFF25D366), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.whatsappNumber,
                  style: TextStyle(
                    color: FuturisticColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Locale: ${customer.locale} · ${customer.eligible ? 'Eligible' : 'Not eligible'}',
                  style: TextStyle(
                    color: FuturisticColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ConsentBadge(consentState: customer.consentState),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.swap_horiz,
              size: 18,
              color: FuturisticColors.primary,
            ),
            onPressed: onConsentToggle,
            tooltip: 'Change Consent',
          ),
        ],
      ),
    );
  }
}
