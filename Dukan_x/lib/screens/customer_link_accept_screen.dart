// ============================================================================
// CUSTOMER LINK ACCEPT SCREEN — UNS migrated (task 14.5, T-CUS-4)
// ============================================================================
// Lets a customer enter the 6-digit link code their shop owner shared,
// verifies it through `ConnectionService.verifyLinkRequest`, and on success
// emits the canonical Phase 2 `users.customer_shop.link_accepted` event
// (Notification_Event_Registry §9.2) through the Shared_SDK so the customer
// and admin both receive the canonical confirmation.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'package:notifications_sdk/notifications_sdk.dart' as uns;

import '../core/di/service_locator.dart';
import '../core/notifications/uns_providers.dart';
import '../core/theme/futuristic_colors.dart';
import '../services/connection_service.dart';

/// Path-style identifier used as `source_module` on every UNS emit raised
/// from this screen. Matches Phase 2 §9.2.
const String _kSourceModule =
    'Dukan_x/lib/screens/customer_link_accept_screen.dart';

class CustomerLinkAcceptScreen extends ConsumerStatefulWidget {
  const CustomerLinkAcceptScreen({super.key});

  @override
  ConsumerState<CustomerLinkAcceptScreen> createState() =>
      _CustomerLinkAcceptScreenState();
}

class _CustomerLinkAcceptScreenState
    extends ConsumerState<CustomerLinkAcceptScreen> {
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController codeCtrl = TextEditingController();

  bool isLoading = false;
  bool isLinked = false;

  Future<void> _acceptLink() async {
    final phone = phoneCtrl.text.trim();
    final code = codeCtrl.text.trim();

    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid 10-digit phone')),
      );
      return;
    }

    if (code.isEmpty || code.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter 6-digit link code')));
      return;
    }

    setState(() => isLoading = true);
    try {
      final success = await sl<ConnectionService>().verifyLinkRequest(
        phone,
        code,
      );

      if (success) {
        // UNS emit (task 14.5, T-CUS-4) — `users.customer_shop.link_accepted`.
        // Failures are logged but do NOT block the success flow; the
        // Firestore link row has already been written.
        await _emitCustomerShopLinkAccepted(phone: phone, code: code);

        setState(() {
          isLinked = true;
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile linked successfully!'),
            duration: Duration(seconds: 2),
          ),
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            phoneCtrl.clear();
            codeCtrl.clear();
            setState(() => isLinked = false);
          }
        });
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Invalid code or expired')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  /// Emit the canonical `users.customer_shop.link_accepted` event through
  /// the Shared_SDK. Recipients (`customer`, `admin`) and per-role channels
  /// are resolved server-side from Phase 2 §9.2.
  Future<void> _emitCustomerShopLinkAccepted({
    required String phone,
    required String code,
  }) async {
    final sdk = ref.read(notificationsSdkProvider).value;
    if (sdk == null) return;

    final user = FirebaseAuth.instance.currentUser;
    final customerId = user?.uid ?? phone;
    // The 6-digit code is what binds this acceptance to a specific shop;
    // we use `phone:code` as the dedup target id when the shop_id is not
    // recoverable on the client side. Phase 2 §9.2 keys on
    // (event_name, customer_id, shop_id) — we substitute the deterministic
    // `code` discriminator so retries within the dedup window collapse
    // even when the client cannot resolve the shop owner_id locally.
    final shopAnchor = code;

    try {
      final payload = <String, dynamic>{
        'customer_id': customerId,
        'customer_phone': phone,
        // Code is treated as a shared secret; do NOT include the raw code
        // in the payload — only the suffix is recorded for triage.
        'link_code_suffix': code.length >= 2
            ? code.substring(code.length - 2)
            : code,
        'link_source': 'six_digit_code',
      };

      final dedupKey =
          'users.customer_shop.link_accepted:$customerId:$shopAnchor';

      final event = sdk.buildEvent(
        eventName: 'users.customer_shop.link_accepted',
        category: uns.EventCategory.users,
        subCategory: 'shop_link',
        priority: uns.EventPriority.normal,
        actorId: customerId,
        targetId: shopAnchor,
        recipients: const <uns.Recipient>[],
        payload: payload,
        channels: const <uns.NotificationChannel>[
          uns.NotificationChannel.inApp,
          uns.NotificationChannel.push,
        ],
        sourceModule: _kSourceModule,
        sourceApp: uns.SourceApp.dukanxDesktop,
        dedupKey: dedupKey,
        dedupScopeFields: const <String>['customer_id', 'shop_id'],
      );

      await sdk.emit(event);
    } catch (e, stack) {
      debugPrint(
        '[CustomerLinkAcceptScreen] UNS emit '
        '"users.customer_shop.link_accepted" failed: $e\n$stack',
      );
    }
  }

  @override
  void dispose() {
    phoneCtrl.dispose();
    codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Your Profile'),
        backgroundColor: Colors.purple,
      ),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Accept Link from Business Owner',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask your business owner for a 6-digit code and enter it below along with your phone number to link your profile.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // Phone input
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                hintText: '10-digit mobile',
                prefixIcon: const Icon(Icons.phone, color: Colors.purple),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.purple.shade50,
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),

            // Code input
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: '6-digit code',
                prefixIcon: const Icon(Icons.vpn_key, color: Colors.purple),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.purple.shade50,
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),

            // Accept button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : _acceptLink,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Accept Link',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            if (isLinked) ...[
              const SizedBox(height: 24),
              Card(
                color: FuturisticColors.paidBackground,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: FuturisticColors.success,
                        size: 32,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile Linked!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: FuturisticColors.success,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'You will now receive bills and reminders automatically',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Info card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ℹ️ About Linking:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Linking connects your phone number to your owner\'s business',
                    style: TextStyle(fontSize: 11),
                  ),
                  Text(
                    '• All bills created for your phone will appear in your portal',
                    style: TextStyle(fontSize: 11),
                  ),
                  Text(
                    '• You can view pending dues, purchase history, and make payments',
                    style: TextStyle(fontSize: 11),
                  ),
                  Text(
                    '• Codes expire after 30 minutes',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
