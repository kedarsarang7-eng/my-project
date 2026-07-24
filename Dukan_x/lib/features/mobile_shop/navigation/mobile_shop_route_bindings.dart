/// MobileShop Route Bindings — GoRouter Route Definitions (Dart)
///
/// Returns all [GoRoute] definitions for the mobileShop vertical.
/// Each route applies the same [MobilePolicyGuardWidget] as the sidebar,
/// ensuring that sidebar, quick actions, deep links, named routes, and
/// content-host dispatch all enforce the identical business/capability/
/// permission policy.
///
/// Fixes AF-07 (IMEI Lookup no-op), AF-24–AF-26 (blocked device screens),
/// and AF-34 (unguarded content-host).
///
/// Requirements: 2.3–2.4, 2.9, 5.1–5.11, 5.8, 8.3–8.7, 9.1–9.8, 12.4
/// Audit: AF-07, AF-24–AF-26, AF-34
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/mobile_policy_guard.dart';
import '../auth/tenant_context_resolver.dart';
import '../billing/mobile_sale_consistency_orchestrator.dart';
import '../config/feature_policy_config.dart';
import '../permissions/mobile_shop_permissions.dart';
import '../repository/mobile_shop_local_repository.dart';
import '../screens/commerce/mobile_commerce_screens.dart';
import '../screens/mobile_shop_screens.dart';
import 'mobile_shop_route_catalog.dart';

// Screen imports — existing production screens reused from their canonical
// locations. No placeholders; each route maps to a real, functional screen.
import '../../statements/presentation/screens/imei_tracking_statement_screen.dart';
import '../../computer_shop/presentation/screens/serial_history_screen.dart';
import '../../computer_shop/presentation/screens/warranty_screen.dart'
    as legacy;
import '../../service/presentation/screens/service_job_list_screen.dart';
import '../../service/presentation/screens/exchange_list_screen.dart';
import '../../service/presentation/screens/second_hand_intake_screen.dart';

/// Returns all [GoRoute] definitions for the mobileShop vertical.
///
/// Each route applies [MobilePolicyGuardWidget] with the same
/// [TenantContextResolver] used by the sidebar builder, ensuring one
/// unified policy across all entry points.
///
/// [repository] is the tenant-bound local repository for live data access.
///
/// Usage in app_router.dart:
/// ```dart
/// ShellRoute(
///   builder: shellBuilder,
///   routes: [
///     ..._shellChildRoutes(),
///     ...buildMobileShopRoutes(resolver, repository),
///   ],
/// )
/// ```
List<GoRoute> buildMobileShopRoutes(
  TenantContextResolver resolver, {
  MobileShopLocalRepository? repository,
  MobileSaleConsistencyOrchestrator? orchestrator,
}) {
  return [
    // ─── Inventory & Devices ───────────────────────────────────────────────

    // IMEI Tracking — main device inventory view
    GoRoute(
      path: '/mobile-shop/imei',
      name: MobileShopRouteCatalog.imeiTracking.id,
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.imeiView,
            builder: (ctx, tenantCtx) => const ImeiTrackingStatementScreen(),
          ),
    ),

    // Serial / IMEI History — connected device history showing all lifecycle
    // events for an IMEI across its lifetime.
    GoRoute(
      path: '/mobile-shop/imei/history',
      name: MobileShopRouteCatalog.serialImeiHistory.id,
      builder: (BuildContext context, GoRouterState state) {
        final serial = state.uri.queryParameters['serial'] ?? '';
        return MobilePolicyGuardWidget(
          resolver: resolver,
          requiredPermission: MobileShopPermissions.imeiView,
          builder: (ctx, tenantCtx) {
            // Use dedicated DeviceHistoryScreen when repository available
            if (repository != null && serial.isNotEmpty) {
              return DeviceHistoryScreen(
                resolver: resolver,
                repository: repository,
                imei: serial,
              );
            }
            return SerialHistoryScreen(serialNumber: serial);
          },
        );
      },
    ),

    // IMEI Lookup — functional search (fixes AF-07: no longer a no-op)
    GoRoute(
      path: '/mobile-shop/imei/lookup',
      name: MobileShopRouteCatalog.imeiLookup.id,
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.imeiView,
            builder: (ctx, tenantCtx) => const ImeiTrackingStatementScreen(),
          ),
    ),

    // Unit Detail — comprehensive current state, associations, action buttons
    GoRoute(
      path: '/mobile-shop/imei/:imei',
      builder: (BuildContext context, GoRouterState state) {
        final imei = state.pathParameters['imei'] ?? '';
        return MobilePolicyGuardWidget(
          resolver: resolver,
          requiredPermission: MobileShopPermissions.imeiView,
          builder: (ctx, tenantCtx) {
            if (repository != null) {
              return UnitDetailScreen(
                resolver: resolver,
                repository: repository,
                imei: imei,
              );
            }
            return const ImeiTrackingStatementScreen();
          },
        );
      },
    ),

    // Second-Hand Intake — used-device buyback
    GoRoute(
      path: '/mobile-shop/second-hand',
      name: MobileShopRouteCatalog.secondHandIntake.id,
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.secondHandManage,
            builder: (ctx, tenantCtx) => const SecondHandIntakeScreen(),
          ),
    ),

    // Reservations — conflict-aware device reservation management
    GoRoute(
      path: '/mobile-shop/reservations',
      name: MobileShopRouteCatalog.reservations.id,
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.imeiManage,
            builder: (ctx, tenantCtx) {
              if (repository != null) {
                return ReservationScreen(
                  tenantContext: tenantCtx,
                  repository: repository,
                );
              }
              return const _FeatureGatedPlaceholder(
                title: 'Reservations',
                message: 'Reservation management requires local repository.',
              );
            },
          ),
    ),

    // Demo Units — demo device lifecycle management
    GoRoute(
      path: '/mobile-shop/demo',
      name: MobileShopRouteCatalog.demoUnits.id,
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.imeiManage,
            builder: (ctx, tenantCtx) {
              if (repository != null) {
                return DemoManagementScreen(
                  tenantContext: tenantCtx,
                  repository: repository,
                );
              }
              return const _FeatureGatedPlaceholder(
                title: 'Demo Units',
                message: 'Demo management requires local repository.',
              );
            },
          ),
    ),

    // Device Returns — IMEI-aware return confirmation
    GoRoute(
      path: '/mobile-shop/returns',
      name: MobileShopRouteCatalog.deviceReturns.id,
      builder: (BuildContext context, GoRouterState state) {
        final imei = state.uri.queryParameters['imei'];
        return MobilePolicyGuardWidget(
          resolver: resolver,
          requiredPermission: MobileShopPermissions.imeiManage,
          builder: (ctx, tenantCtx) {
            if (repository != null && orchestrator != null) {
              return ReturnConfirmationScreen(
                tenantContext: tenantCtx,
                repository: repository,
                orchestrator: orchestrator,
                prefilledImei: imei,
              );
            }
            return const _FeatureGatedPlaceholder(
              title: 'Device Returns',
              message: 'Return processing requires local repository.',
            );
          },
        );
      },
    ),

    // ─── Service & Repair ──────────────────────────────────────────────────

    // Service Jobs — uses dedicated ServiceJobScreen with status filters,
    // tenant context, expected versions, and typed states.
    GoRoute(
      path: '/mobile-shop/service-jobs',
      name: MobileShopRouteCatalog.serviceJobs.id,
      builder: (BuildContext context, GoRouterState state) {
        final statusFilter = state.uri.queryParameters['status'];
        return MobilePolicyGuardWidget(
          resolver: resolver,
          requiredPermission: MobileShopPermissions.serviceView,
          builder: (ctx, tenantCtx) {
            if (repository != null) {
              return ServiceJobScreen(
                resolver: resolver,
                repository: repository,
                initialStatusFilter: statusFilter,
              );
            }
            return const ServiceJobListScreen();
          },
        );
      },
    ),

    // Service Job Detail route
    GoRoute(
      path: '/mobile-shop/service-jobs/:jobId',
      builder: (BuildContext context, GoRouterState state) {
        // Job detail is part of the service job screen flow
        return MobilePolicyGuardWidget(
          resolver: resolver,
          requiredPermission: MobileShopPermissions.serviceView,
          builder: (ctx, tenantCtx) => const ServiceJobListScreen(),
        );
      },
    ),

    // Exchanges — uses dedicated ExchangeScreen with both-side display,
    // financial adjustments, and lifecycle transition visibility.
    GoRoute(
      path: '/mobile-shop/exchanges',
      name: MobileShopRouteCatalog.exchanges.id,
      builder: (BuildContext context, GoRouterState state) {
        final statusFilter = state.uri.queryParameters['status'];
        return MobilePolicyGuardWidget(
          resolver: resolver,
          requiredPermission: MobileShopPermissions.exchangeView,
          builder: (ctx, tenantCtx) {
            if (repository != null) {
              return ExchangeScreen(
                resolver: resolver,
                repository: repository,
                initialStatusFilter: statusFilter,
              );
            }
            return const ExchangeListScreen();
          },
        );
      },
    ),

    // ─── Warranty ──────────────────────────────────────────────────────────

    // Warranty Management — uses dedicated WarrantyManagementScreen with
    // month-end behavior, claims, evidence, and typed states.
    GoRoute(
      path: '/mobile-shop/warranty',
      name: MobileShopRouteCatalog.warrantyManagement.id,
      builder: (BuildContext context, GoRouterState state) {
        final statusFilter = state.uri.queryParameters['status'];
        return MobilePolicyGuardWidget(
          resolver: resolver,
          requiredPermission: MobileShopPermissions.warrantyView,
          builder: (ctx, tenantCtx) {
            if (repository != null) {
              return WarrantyManagementScreen(
                resolver: resolver,
                repository: repository,
                initialStatusFilter: statusFilter,
              );
            }
            return const legacy.WarrantyScreen();
          },
        );
      },
    ),

    // ─── Finance ───────────────────────────────────────────────────────────

    // Finance Plans / EMI — provider-neutral finance form
    GoRoute(
      path: '/mobile-shop/finance',
      name: MobileShopRouteCatalog.financePlansEmi.id,
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.financeView,
            builder: (ctx, tenantCtx) => FinancePlanScreen(
              service: _buildCommerceService(resolver),
              resolver: resolver,
              prefillInvoiceId: state.uri.queryParameters['invoiceId'],
              prefillImei: state.uri.queryParameters['imei'],
            ),
          ),
    ),

    // SIM / Recharge — provider-neutral recharge form
    GoRoute(
      path: '/mobile-shop/sim-recharge',
      name: MobileShopRouteCatalog.simRecharge.id,
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            builder: (ctx, tenantCtx) => SimRechargeScreen(
              service: _buildCommerceService(resolver),
              resolver: resolver,
            ),
          ),
    ),

    // ─── Reports ───────────────────────────────────────────────────────────

    // Mobile Reports Hub — entry point listing all report types
    GoRoute(
      path: '/mobile-shop/reports',
      name: MobileShopRouteCatalog.mobileReports.id,
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.reportsView,
            builder: (ctx, tenantCtx) {
              if (repository != null) {
                return MobileReportsHubScreen(
                  resolver: resolver,
                  repository: repository,
                );
              }
              return const _FeatureGatedPlaceholder(
                title: 'Mobile Reports',
                message: 'Reports require local repository.',
              );
            },
          ),
    ),

    // IMEI History Report
    GoRoute(
      path: '/mobile-shop/reports/imei-history',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.reportsView,
            builder: (ctx, tenantCtx) {
              if (repository == null) {
                return const _FeatureGatedPlaceholder(
                  title: 'IMEI History',
                  message: 'Report requires local repository.',
                );
              }
              return ImeiHistoryReportScreen(
                resolver: resolver,
                repository: repository,
                initialFilter: ReportFilterParams.fromQueryParameters(
                  state.uri.queryParameters,
                ),
              );
            },
          ),
    ),

    // Brand/Model Sales Report
    GoRoute(
      path: '/mobile-shop/reports/brand-model-sales',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.reportsView,
            builder: (ctx, tenantCtx) {
              if (repository == null) {
                return const _FeatureGatedPlaceholder(
                  title: 'Brand/Model Sales',
                  message: 'Report requires local repository.',
                );
              }
              return BrandModelSalesReportScreen(
                resolver: resolver,
                repository: repository,
                initialFilter: ReportFilterParams.fromQueryParameters(
                  state.uri.queryParameters,
                ),
              );
            },
          ),
    ),

    // Unit Margin Report
    GoRoute(
      path: '/mobile-shop/reports/unit-margin',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.reportsView,
            builder: (ctx, tenantCtx) {
              if (repository == null) {
                return const _FeatureGatedPlaceholder(
                  title: 'Unit Margin',
                  message: 'Report requires local repository.',
                );
              }
              return UnitMarginReportScreen(
                resolver: resolver,
                repository: repository,
                initialFilter: ReportFilterParams.fromQueryParameters(
                  state.uri.queryParameters,
                ),
              );
            },
          ),
    ),

    // Repair Revenue/Status Report
    GoRoute(
      path: '/mobile-shop/reports/repair-revenue',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.reportsView,
            builder: (ctx, tenantCtx) {
              if (repository == null) {
                return const _FeatureGatedPlaceholder(
                  title: 'Repair Revenue',
                  message: 'Report requires local repository.',
                );
              }
              return RepairRevenueReportScreen(
                resolver: resolver,
                repository: repository,
                initialFilter: ReportFilterParams.fromQueryParameters(
                  state.uri.queryParameters,
                ),
              );
            },
          ),
    ),

    // Exchange Margin Report
    GoRoute(
      path: '/mobile-shop/reports/exchange-margin',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.reportsView,
            builder: (ctx, tenantCtx) {
              if (repository == null) {
                return const _FeatureGatedPlaceholder(
                  title: 'Exchange Margin',
                  message: 'Report requires local repository.',
                );
              }
              return ExchangeMarginReportScreen(
                resolver: resolver,
                repository: repository,
                initialFilter: ReportFilterParams.fromQueryParameters(
                  state.uri.queryParameters,
                ),
              );
            },
          ),
    ),

    // Warranty Report
    GoRoute(
      path: '/mobile-shop/reports/warranty',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.reportsView,
            builder: (ctx, tenantCtx) {
              if (repository == null) {
                return const _FeatureGatedPlaceholder(
                  title: 'Warranty Report',
                  message: 'Report requires local repository.',
                );
              }
              return WarrantyReportScreen(
                resolver: resolver,
                repository: repository,
                initialFilter: ReportFilterParams.fromQueryParameters(
                  state.uri.queryParameters,
                ),
              );
            },
          ),
    ),

    // Used-Stock Aging Report
    GoRoute(
      path: '/mobile-shop/reports/used-stock-aging',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.reportsView,
            builder: (ctx, tenantCtx) {
              if (repository == null) {
                return const _FeatureGatedPlaceholder(
                  title: 'Used-Stock Aging',
                  message: 'Report requires local repository.',
                );
              }
              return UsedStockAgingReportScreen(
                resolver: resolver,
                repository: repository,
                initialFilter: ReportFilterParams.fromQueryParameters(
                  state.uri.queryParameters,
                ),
              );
            },
          ),
    ),

    // Demo Report
    GoRoute(
      path: '/mobile-shop/reports/demo',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.reportsView,
            builder: (ctx, tenantCtx) {
              if (repository == null) {
                return const _FeatureGatedPlaceholder(
                  title: 'Demo Units',
                  message: 'Report requires local repository.',
                );
              }
              return DemoReportScreen(
                resolver: resolver,
                repository: repository,
                initialFilter: ReportFilterParams.fromQueryParameters(
                  state.uri.queryParameters,
                ),
              );
            },
          ),
    ),

    // Return Report
    GoRoute(
      path: '/mobile-shop/reports/returns',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.reportsView,
            builder: (ctx, tenantCtx) {
              if (repository == null) {
                return const _FeatureGatedPlaceholder(
                  title: 'Returns Analysis',
                  message: 'Report requires local repository.',
                );
              }
              return ReturnReportScreen(
                resolver: resolver,
                repository: repository,
                initialFilter: ReportFilterParams.fromQueryParameters(
                  state.uri.queryParameters,
                ),
              );
            },
          ),
    ),

    // Sync Report
    GoRoute(
      path: '/mobile-shop/reports/sync',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.reportsView,
            builder: (ctx, tenantCtx) {
              if (repository == null) {
                return const _FeatureGatedPlaceholder(
                  title: 'Sync Status',
                  message: 'Report requires local repository.',
                );
              }
              return SyncReportScreen(
                resolver: resolver,
                repository: repository,
                initialFilter: ReportFilterParams.fromQueryParameters(
                  state.uri.queryParameters,
                ),
              );
            },
          ),
    ),

    // Reconciliation Exceptions Report
    GoRoute(
      path: '/mobile-shop/reports/reconciliation',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.reportsView,
            builder: (ctx, tenantCtx) {
              if (repository == null) {
                return const _FeatureGatedPlaceholder(
                  title: 'Reconciliation Exceptions',
                  message: 'Report requires local repository.',
                );
              }
              return ReconciliationExceptionsReportScreen(
                resolver: resolver,
                repository: repository,
                initialFilter: ReportFilterParams.fromQueryParameters(
                  state.uri.queryParameters,
                ),
              );
            },
          ),
    ),

    // Conflicts Report (KPI card target for "Unresolved Conflicts")
    GoRoute(
      path: '/mobile-shop/conflicts',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.reportsView,
            builder: (ctx, tenantCtx) {
              if (repository == null) {
                return const _FeatureGatedPlaceholder(
                  title: 'Conflicts',
                  message: 'Report requires local repository.',
                );
              }
              return ReconciliationExceptionsReportScreen(
                resolver: resolver,
                repository: repository,
                initialFilter: ReportFilterParams.fromQueryParameters(
                  state.uri.queryParameters,
                ),
              );
            },
          ),
    ),

    // Reconciliation Report (KPI card target for "Reconciliation Issues")
    GoRoute(
      path: '/mobile-shop/reconciliation',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.reportsView,
            builder: (ctx, tenantCtx) {
              if (repository == null) {
                return const _FeatureGatedPlaceholder(
                  title: 'Reconciliation',
                  message: 'Report requires local repository.',
                );
              }
              return ReconciliationExceptionsReportScreen(
                resolver: resolver,
                repository: repository,
                initialFilter: ReportFilterParams.fromQueryParameters(
                  state.uri.queryParameters,
                ),
              );
            },
          ),
    ),

    // Inventory Report (KPI card target for lifecycle stock KPIs)
    GoRoute(
      path: '/mobile-shop/inventory',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.imeiView,
            builder: (ctx, tenantCtx) {
              if (repository == null) {
                return const _FeatureGatedPlaceholder(
                  title: 'Inventory',
                  message: 'Report requires local repository.',
                );
              }
              return ImeiHistoryReportScreen(
                resolver: resolver,
                repository: repository,
                initialFilter: ReportFilterParams.fromQueryParameters(
                  state.uri.queryParameters,
                ),
              );
            },
          ),
    ),

    // Warranties Report (KPI card target for warranty KPIs)
    GoRoute(
      path: '/mobile-shop/warranties',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.warrantyView,
            builder: (ctx, tenantCtx) {
              if (repository == null) {
                return const _FeatureGatedPlaceholder(
                  title: 'Warranties',
                  message: 'Report requires local repository.',
                );
              }
              return WarrantyReportScreen(
                resolver: resolver,
                repository: repository,
                initialFilter: ReportFilterParams.fromQueryParameters(
                  state.uri.queryParameters,
                ),
              );
            },
          ),
    ),

    // ─── Settings ──────────────────────────────────────────────────────────

    // OCR Intake — policy-gated document capture
    GoRoute(
      path: '/mobile-shop/ocr',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.imeiManage,
            builder: (ctx, tenantCtx) => OcrIntakeScreen(
              service: _buildCommerceService(resolver),
              resolver: resolver,
            ),
          ),
    ),

    // Bundle Sale — handset + accessories with separate lines
    GoRoute(
      path: '/mobile-shop/bundle',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.imeiView,
            builder: (ctx, tenantCtx) => BundleSaleScreen(
              service: _buildCommerceService(resolver),
              resolver: resolver,
              prefillCustomerId: state.uri.queryParameters['customerId'],
              prefillInvoiceId: state.uri.queryParameters['invoiceId'],
            ),
          ),
    ),

    // Price Adjustment — approval workflow with margin impact
    GoRoute(
      path: '/mobile-shop/price-adjustment',
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.settingsManage,
            builder: (ctx, tenantCtx) => PriceAdjustmentScreen(
              service: _buildCommerceService(resolver),
              resolver: resolver,
              prefillImei: state.uri.queryParameters['imei'],
              prefillUnitId: state.uri.queryParameters['unitId'],
            ),
          ),
    ),

    // Mobile Shop Settings
    GoRoute(
      path: '/mobile-shop/settings',
      name: MobileShopRouteCatalog.mobileShopSettings.id,
      builder: (BuildContext context, GoRouterState state) =>
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.settingsView,
            builder: (ctx, tenantCtx) => const _FeatureGatedPlaceholder(
              title: 'Mobile Shop Settings',
              message: 'Mobile Shop settings are under development.',
            ),
          ),
    ),
  ];
}

// ─── Feature-Gated Placeholder ─────────────────────────────────────────────

/// A temporary placeholder for feature-gated routes that have provider-neutral
/// ports but no selected provider yet (finance, SIM/recharge, reports, settings).
///
/// This is NOT a "no-op" or denial — it's an explicit "coming soon" state that
/// is only reachable after passing the full policy guard. The route is functional
/// (guarded, navigable, responsive) — only the domain content is deferred.
class _FeatureGatedPlaceholder extends StatelessWidget {
  final String title;
  final String message;

  const _FeatureGatedPlaceholder({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction_outlined,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Commerce Service Factory ──────────────────────────────────────────────

/// Builds a [MobileCommerceService] instance from the given [resolver].
///
/// In production, this would be provided via dependency injection (Riverpod/
/// GetIt). For now, a factory placeholder is used; the actual orchestrator
/// and API dependencies are wired through the DI container at app startup.
MobileCommerceService _buildCommerceService(TenantContextResolver resolver) {
  // NOTE: In production wiring, the orchestrator, API, and sync coordinator
  // are resolved from the DI container. This factory is a temporary bridge
  // until full DI integration in the app startup.
  //
  // The actual instantiation:
  //   return MobileCommerceServiceImpl(
  //     orchestrator: getIt<MobileSaleConsistencyOrchestrator>(),
  //   );
  //
  // For now, we return a _StubCommerceService that gates by policy
  // and returns pending/offline-preserved states.
  return _StubCommerceService();
}

/// Stub implementation for route wiring before full DI integration.
///
/// Gates by feature policy and returns appropriate pending/offline states.
/// This will be replaced by [MobileCommerceServiceImpl] once the DI
/// container resolves the orchestrator/API dependencies.
class _StubCommerceService implements MobileCommerceService {
  @override
  bool isFeatureEnabled(String featureId) {
    final feature = kFeaturePolicyConfig.getFeature(featureId);
    return feature?.enabledByDefault ?? false;
  }

  @override
  Future<CommerceOutcome> submitFinancePlan(
    TenantContext context,
    FinancePlanRequest request,
  ) async {
    if (!isFeatureEnabled('FINANCE_PLANS')) {
      return const CommerceOutcome(
        state: CommerceOutcomeState.featureDisabled,
        operationId: '',
        errorMessage: 'Finance plans are not enabled',
      );
    }
    return CommerceOutcome(
      state: CommerceOutcomeState.pending,
      operationId: generateOperationId(),
    );
  }

  @override
  Future<CommerceOutcome> submitRecharge(
    TenantContext context,
    RechargeRequest request,
  ) async {
    if (!isFeatureEnabled('SIM_RECHARGE')) {
      return const CommerceOutcome(
        state: CommerceOutcomeState.featureDisabled,
        operationId: '',
        errorMessage: 'SIM/Recharge is not enabled',
      );
    }
    return CommerceOutcome(
      state: CommerceOutcomeState.pending,
      operationId: generateOperationId(),
    );
  }

  @override
  Future<CommerceOutcome> submitOcrScan(
    TenantContext context,
    OcrScanRequest request,
  ) async {
    if (!isFeatureEnabled('OCR_INTAKE')) {
      return const CommerceOutcome(
        state: CommerceOutcomeState.featureDisabled,
        operationId: '',
        errorMessage: 'OCR intake is not enabled',
      );
    }
    return CommerceOutcome(
      state: CommerceOutcomeState.pending,
      operationId: generateOperationId(),
    );
  }

  @override
  Future<CommerceOutcome> submitBundleSale(
    TenantContext context,
    BundleSaleRequest request,
  ) async {
    if (!isFeatureEnabled('BUNDLES')) {
      return const CommerceOutcome(
        state: CommerceOutcomeState.featureDisabled,
        operationId: '',
        errorMessage: 'Bundles are not enabled',
      );
    }
    return CommerceOutcome(
      state: CommerceOutcomeState.pending,
      operationId: generateOperationId(),
    );
  }

  @override
  Future<CommerceOutcome> submitPriceAdjustment(
    TenantContext context,
    PriceAdjustmentRequest request,
  ) async {
    if (!isFeatureEnabled('PRICE_PROTECTION')) {
      return const CommerceOutcome(
        state: CommerceOutcomeState.featureDisabled,
        operationId: '',
        errorMessage: 'Price protection is not enabled',
      );
    }
    return CommerceOutcome(
      state: CommerceOutcomeState.pending,
      operationId: generateOperationId(),
    );
  }

  @override
  Future<CommerceOutcome> checkOperationStatus(
    TenantContext context,
    String operationId,
  ) async {
    return CommerceOutcome(
      state: CommerceOutcomeState.pending,
      operationId: operationId,
    );
  }
}
