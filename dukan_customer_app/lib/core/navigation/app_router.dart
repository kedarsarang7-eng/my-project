import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/customer_session_manager.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/home/presentation/screens/customer_home_screen.dart';
import '../../features/invoices/presentation/screens/invoice_list_screen.dart';
import '../../features/invoices/presentation/screens/invoice_detail_screen.dart';
import '../../features/ledger/presentation/screens/ledger_screen.dart';
import '../../features/payments/presentation/screens/record_payment_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/shops/presentation/screens/linked_shops_screen.dart';
import '../../features/marketplace/presentation/screens/store_discovery_screen.dart';
import '../../features/marketplace/presentation/screens/store_home_screen.dart';
import '../../features/marketplace/presentation/screens/cart_screen.dart';
import '../../features/marketplace/models/marketplace_models.dart' show Cart;
import '../../features/marketplace/presentation/screens/checkout_screen.dart';
import '../../features/marketplace/presentation/screens/orders_screen.dart';
import '../../features/in_store/presentation/screens/in_store_landing_screen.dart';
import '../../features/in_store/presentation/screens/store_entry_qr_scan_screen.dart';
import '../../features/in_store/presentation/screens/in_store_shopping_screen.dart';
import '../../features/in_store/presentation/screens/cart_review_screen.dart';
import '../../features/in_store/presentation/screens/in_store_payment_screen.dart';
import '../../features/in_store/models/in_store_models.dart';
import '../../features/in_store/presentation/screens/exit_qr_screen.dart';

class AppRoutes {
  static const login = '/login';
  static const otp = '/otp';
  static const home = '/home';
  static const invoices = '/invoices';
  static const invoiceDetail = '/invoices/:id';
  static const ledger = '/ledger';
  static const recordPayment = '/payment/record';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const linkedShops = '/shops';
  static const storeDiscovery = '/marketplace/discover';
  static const storeHome = '/marketplace/store/:businessId';
  static const cart = '/marketplace/cart/:businessId';
  static const checkout = '/marketplace/checkout/:businessId';
  static const marketplaceOrders = '/marketplace/orders';

  // In-Store Self Scan & Checkout
  static const inStoreLanding = '/in-store';
  static const inStoreEntryQRScan = '/in-store/entry-scan';
  static const inStoreShopping = '/in-store/shopping';
  static const inStoreCartReview = '/in-store/cart-review';
  static const inStorePayment = '/in-store/payment';
  static const inStoreExitQR = '/in-store/exit-qr';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: _AuthChangeNotifier(ref),
    redirect: (context, state) {
      final authState = ref.read(customerSessionProvider).valueOrNull;
      if (authState == null || authState.isLoading) return null;

      final isLoginRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.otp;

      if (!authState.isAuthenticated && !isLoginRoute) {
        return AppRoutes.login;
      }
      if (authState.isAuthenticated && isLoginRoute) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const LoginScreen(),
        routes: [
          GoRoute(
            path: 'otp',
            builder: (_, state) => OtpScreen(
              phone: state.extra as String? ?? '',
            ),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => child,
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, _) => const CustomerHomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.invoices,
            builder: (_, _) => const InvoiceListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => InvoiceDetailScreen(
                  invoiceId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.ledger,
            builder: (_, state) => LedgerScreen(
              vendorId: state.extra as String?,
            ),
          ),
          GoRoute(
            path: AppRoutes.recordPayment,
            builder: (_, state) => RecordPaymentScreen(
              vendorId: (state.extra as Map<String, dynamic>?)?['vendorId'],
            ),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (_, _) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, _) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, _) => const EditProfileScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.linkedShops,
            builder: (_, _) => const LinkedShopsScreen(),
          ),
          GoRoute(
            path: AppRoutes.storeDiscovery,
            builder: (_, _) => const StoreDiscoveryScreen(),
          ),
          GoRoute(
            path: AppRoutes.storeHome,
            builder: (_, state) => StoreHomeScreen(
              businessId: state.pathParameters['businessId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.cart,
            builder: (_, state) => CartScreen(
              businessId: state.pathParameters['businessId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.checkout,
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>;
              return CheckoutScreen(
                businessId: state.pathParameters['businessId']!,
                cart: extra['cart'] as Cart,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.marketplaceOrders,
            builder: (_, _) => const OrdersScreen(),
          ),

          // ── In-Store Self Scan & Checkout ─────────────────────────────
          GoRoute(
            path: AppRoutes.inStoreLanding,
            builder: (_, _) => const InStoreLandingScreen(),
          ),
          GoRoute(
            path: AppRoutes.inStoreEntryQRScan,
            builder: (_, _) => const StoreEntryQRScanScreen(),
          ),
          GoRoute(
            path: AppRoutes.inStoreShopping,
            builder: (_, _) => const InStoreShoppingScreen(),
          ),
          GoRoute(
            path: AppRoutes.inStoreCartReview,
            builder: (_, _) => const CartReviewScreen(),
          ),
          GoRoute(
            path: AppRoutes.inStorePayment,
            builder: (_, state) => InStorePaymentScreen(
              checkoutResponse: state.extra as CheckoutResponse,
            ),
          ),
          GoRoute(
            path: AppRoutes.inStoreExitQR,
            builder: (_, _) => const ExitQRScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

class _AuthChangeNotifier extends ChangeNotifier {
  final Ref _ref;
  _AuthChangeNotifier(this._ref) {
    _ref.listen(customerSessionProvider, (_, _) => notifyListeners());
  }
}
