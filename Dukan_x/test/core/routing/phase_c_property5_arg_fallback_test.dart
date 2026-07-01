// ============================================================================
// PHASE C — Task 6.3 (OPTIONAL PROPERTY TEST)
// Feature: imperative-navigation-gorouter-migration
// Property 5: Argument fallback safety
// **Validates: Requirements 5.3, 5.4**
// ============================================================================
//
// Property 5 (design.md — Correctness Properties):
//   "For any argument-bearing migrated route and any value supplied as `extra`
//    (null, a wrong-typed value, or a valid value), the builder performs its
//    `is`-type-check before use and returns a non-crashing widget: a valid
//    `extra` yields the intended screen, while an invalid or missing `extra`
//    yields the same safe fallback screen or sentinel defaults the legacy
//    builder used."
//
// WHY PURE HELPERS (design.md AD-3 + Testing Strategy):
//   The migrated builders in `lib/core/routing/legacy_routes.dart` are
//   widget-producing and need a BuildContext + guard widgets to run, so they
//   are not cheaply callable headless for 100+ iterations. The DEFENSIVE
//   PARSE each builder performs on `state.extra` BEFORE constructing its screen
//   is, however, a PURE decision over `Object?`. This suite extracts that parse
//   into small local helpers that mirror the builders CHARACTER-FOR-CHARACTER
//   (the same `is`-type-check and the same sentinel/fallback), then
//   property-tests the helpers over a generator of arbitrary `Object?` values.
//
//   Each helper below is annotated with the exact line it mirrors from
//   `legacy_routes.dart` (Task 6.2), so the model stays faithful to the
//   contract the legacy table encoded (Requirement 5.4: "fall back to the same
//   safe screen or sentinel default values that the Legacy_Route_Table used").
//
// WHAT THE PROPERTY GUARANTEES (the three facets asserted below):
//   1. TOTALITY / NO-THROW: feeding ANY generated `extra` (null, int, String,
//      bool, List, Map<String,String>, Map<String,dynamic>, Bill, Customer)
//      NEVER throws — no unconditional cast crash (Requirement 5.3).
//   2. SAFE FALLBACK: wrong-typed / missing `extra` yields the documented
//      sentinel (patientId 'unknown', editingBill null, verticalType 'grocery',
//      ownerName '', etc.) (Requirement 5.4).
//   3. VALID PASS-THROUGH: a correctly-typed `extra` yields the passed value.
//
// PBT library: dartproptest ^0.2.1 (the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide). The variadic `forAll((a) => boolExpr, [genA],
//   numRuns: N)` runs `numRuns` generated cases and returns whether the
//   predicate held for all of them.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/core/routing/phase_c_property5_arg_fallback_test.dart --reporter expanded
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/repository/customers_repository.dart' show Customer;
import 'package:dukanx/models/bill.dart' show Bill;
import 'package:flutter_test/flutter_test.dart';

// ============================================================================
// FALLBACK HELPERS — each mirrors a migrated builder's defensive parse of
// `state.extra` CHARACTER-FOR-CHARACTER (legacy_routes.dart, Task 6.2).
// A returned `null` models "the builder takes its safe fallback branch"
// (error scaffold / LoginPage / SettingsScreen); a non-null value models the
// extracted, passed-through argument.
// ============================================================================

// --- Map<String,String> family (clinic + clothing) -------------------------
// Mirrors: final safeArgs = args is Map<String,String> ? args : {};
//          ConsultationScreen(patientId: safeArgs['patientId'] ?? 'unknown', ...)
String consultationPatientId(Object? extra) =>
    (extra is Map<String, String>
        ? extra
        : const <String, String>{})['patientId'] ??
    'unknown';

// Mirrors: patientName: safeArgs['patientName'] ?? 'Unknown Patient'
String consultationPatientName(Object? extra) =>
    (extra is Map<String, String>
        ? extra
        : const <String, String>{})['patientName'] ??
    'Unknown Patient';

// Mirrors '/clinic/history': PatientHistoryScreen(patientId: safeArgs['patientId'] ?? 'unknown')
String historyPatientId(Object? extra) =>
    (extra is Map<String, String>
        ? extra
        : const <String, String>{})['patientId'] ??
    'unknown';

// Mirrors '/clinic/labs': LabOrderScreen(patientId .. ?? 'unknown', patientName .. ?? 'Unknown Patient')
String labsPatientId(Object? extra) =>
    (extra is Map<String, String>
        ? extra
        : const <String, String>{})['patientId'] ??
    'unknown';
String labsPatientName(Object? extra) =>
    (extra is Map<String, String>
        ? extra
        : const <String, String>{})['patientName'] ??
    'Unknown Patient';

// Mirrors '/clothing/variants': VariantManagementScreen(productId: safeArgs['productId'] ?? 'unknown')
String clothingProductId(Object? extra) =>
    (extra is Map<String, String>
        ? extra
        : const <String, String>{})['productId'] ??
    'unknown';

// --- Map (raw) -> Map<String,dynamic> family (hardware + purchase) ----------
// Mirrors '/hardware/operations':
//   final map = args is Map ? Map<String,dynamic>.from(args) : const {};
//   initialTab: (map['initialTab'] as num?)?.toInt() ?? 0
int hardwareInitialTab(Object? extra) {
  final map = extra is Map
      ? Map<String, dynamic>.from(extra)
      : const <String, dynamic>{};
  return (map['initialTab'] as num?)?.toInt() ?? 0;
}

// Mirrors: initialDepositStatus: map['depositStatus']?.toString()
String? hardwareDepositStatus(Object? extra) {
  final map = extra is Map
      ? Map<String, dynamic>.from(extra)
      : const <String, dynamic>{};
  return map['depositStatus']?.toString();
}

// Mirrors '/purchase/*':
//   final args = state.extra is Map ? Map<String,dynamic>.from(state.extra as Map) : const {};
//   final verticalType = args['verticalType'] as String? ?? 'grocery';
String purchaseVerticalType(Object? extra) {
  final args = extra is Map
      ? Map<String, dynamic>.from(extra)
      : const <String, dynamic>{};
  return args['verticalType'] as String? ?? 'grocery';
}

// --- Optional object family (Bill) ------------------------------------------
// Mirrors '/advanced_bill_creation': args is Bill ? AdvancedBillCreationScreen(editingBill: args)
//                                               : AdvancedBillCreationScreen()  (editingBill null)
Bill? advancedBillEditing(Object? extra) => extra is Bill ? extra : null;

// --- Customer family --------------------------------------------------------
// Mirrors '/customer_app': args is Customer ? CustomerDashboardScreen(customerId: args.id)
//                                            : const LoginPage()  (modelled as null)
String? customerAppId(Object? extra) => extra is Customer ? extra.id : null;

// --- Non-empty String family (customer_portal + notifications) --------------
// Mirrors '/customer_portal': args is String && args.isNotEmpty
//   ? CustomerDashboardScreen(customerId: args) : error scaffold (null)
String? customerPortalId(Object? extra) =>
    (extra is String && extra.isNotEmpty) ? extra : null;

// Mirrors '/notifications': args is String && args.isNotEmpty
//   ? CustomerNotificationsScreen(customerId: args) : error scaffold (null)
String? notificationsCustomerId(Object? extra) =>
    (extra is String && extra.isNotEmpty) ? extra : null;

// --- Any String family (cloud_sync_settings) — note: NO isNotEmpty check ----
// Mirrors '/cloud_sync_settings': args is String
//   ? CloudSyncSettingsScreen(ownerId: args) : SettingsScreen()  (null)
String? cloudSyncOwnerId(Object? extra) => extra is String ? extra : null;

// --- Map<String,String> with required key (customer_report) -----------------
// Mirrors '/customer_report':
//   final safeArgs = args is Map<String,String> ? args : null;
//   if (safeArgs != null && safeArgs.containsKey('customerId')) { use } else { error }
String? customerReportCustomerId(Object? extra) {
  final safeArgs = extra is Map<String, String> ? extra : null;
  if (safeArgs != null && safeArgs.containsKey('customerId')) {
    return safeArgs['customerId'];
  }
  return null;
}

// --- Map<String,String> with sentinel '' defaults (editable_invoice) --------
// Mirrors '/editable_invoice':
//   final safeArgs = args is Map<String,String> ? args : null;
//   EditableInvoiceScreen(ownerName: safeArgs?['ownerName'] ?? '', shopName: .. ?? '', ...)
String editableInvoiceOwnerName(Object? extra) {
  final safeArgs = extra is Map<String, String> ? extra : null;
  return safeArgs?['ownerName'] ?? '';
}

String editableInvoiceShopName(Object? extra) {
  final safeArgs = extra is Map<String, String> ? extra : null;
  return safeArgs?['shopName'] ?? '';
}

void main() {
  // At least 100 iterations are required by the spec; 200 matches the
  // dartproptest default and the convention used across the sibling property
  // suites in this folder.
  const int kNumRuns = 200;

  // A single correctly-typed Customer used in the "valid pass-through" branch
  // of the generator. Its `id` is the value the customer_app builder extracts.
  final Customer sampleCustomer = Customer(
    id: 'cust_sample_1',
    odId: 'od_sample_1',
    name: 'Sample Customer',
    createdAt: DateTime(2020, 1, 1),
    updatedAt: DateTime(2020, 1, 1),
  );

  // --- Generator over arbitrary `Object?` `extra` values --------------------
  // Mixes EVERY shape the migrated builders can receive at runtime:
  //   null, int, String (incl. empty), bool, List, Map<String,String>,
  //   Map<String,dynamic>, and the two correct object types (Bill, Customer).
  // Map shapes carry a key-subset selector so each helper sees its key both
  // present (pass-through) and absent (sentinel fallback).
  final Generator<Object?> extraGen =
      Gen.tuple(<Generator<dynamic>>[
        Gen.interval(0, 9), // shape selector
        Gen.interval(-500, 500), // numeric payload
        Gen.printableAsciiString(
          minLength: 0,
          maxLength: 8,
        ), // string a (may be empty)
        Gen.printableAsciiString(
          minLength: 0,
          maxLength: 8,
        ), // string b (may be empty)
        Gen.interval(0, 255), // key-subset bitmask for maps
      ]).map((List<dynamic> parts) {
        final int shape = parts[0] as int;
        final int n = parts[1] as int;
        final String a = parts[2] as String;
        final String b = parts[3] as String;
        final int keys = parts[4] as int;

        switch (shape) {
          case 0:
            return null; // missing argument
          case 1:
            return n; // wrong type: int
          case 2:
            return a; // String (possibly empty) — exercises isNotEmpty branch
          case 3:
            return n.isEven; // wrong type: bool
          case 4:
            return <dynamic>[a, n, b]; // wrong type: List
          case 5:
            {
              // Map<String,String> with a generated subset of the keys that the
              // clinic / clothing / customer_report / editable_invoice helpers read.
              final Map<String, String> m = <String, String>{};
              if (keys & 1 != 0) m['patientId'] = a;
              if (keys & 2 != 0) m['patientName'] = b;
              if (keys & 4 != 0) m['productId'] = a;
              if (keys & 8 != 0) m['customerId'] = a;
              if (keys & 16 != 0) m['customerName'] = b;
              if (keys & 32 != 0) m['ownerName'] = a;
              if (keys & 64 != 0) m['shopName'] = b;
              return m;
            }
          case 6:
            {
              // Map<String,dynamic> — NOT a Map<String,String> (so the clinic
              // family safely falls back) but IS a raw Map (so the hardware /
              // purchase family parses it). Sub-values use the correct types so
              // the documented `as num?` / `as String?` reads never crash.
              final Map<String, dynamic> m = <String, dynamic>{};
              if (keys & 1 != 0) m['initialTab'] = n; // int (correct sub-type)
              if (keys & 2 != 0) m['depositStatus'] = a; // String
              if (keys & 4 != 0) m['verticalType'] = b; // String
              return m;
            }
          case 7:
            return Bill.empty(); // correct type for advanced_bill_creation
          case 8:
            return sampleCustomer; // correct type for customer_app
          default:
            return <String, String>{}; // empty Map<String,String>
        }
      });

  group('Feature: imperative-navigation-gorouter-migration, Property 5: '
      'Argument fallback safety — Req 5.3, 5.4', () {
    // ----------------------------------------------------------------------
    // Property 5a — TOTALITY / NO-THROW (Requirement 5.3).
    // Feeding ANY generated `extra` to EVERY fallback helper never throws an
    // unconditional-cast crash. Each helper is invoked inside the same run.
    // ----------------------------------------------------------------------
    test('Property 5a: every fallback helper is total over arbitrary `extra` — '
        'no unconditional-cast crash for null/wrong-typed/valid input', () {
      final bool held = forAll(
        (Object? extra) {
          // Invoke every helper; any throw fails the property.
          consultationPatientId(extra);
          consultationPatientName(extra);
          historyPatientId(extra);
          labsPatientId(extra);
          labsPatientName(extra);
          clothingProductId(extra);
          hardwareInitialTab(extra);
          hardwareDepositStatus(extra);
          purchaseVerticalType(extra);
          advancedBillEditing(extra);
          customerAppId(extra);
          customerPortalId(extra);
          notificationsCustomerId(extra);
          cloudSyncOwnerId(extra);
          customerReportCustomerId(extra);
          editableInvoiceOwnerName(extra);
          editableInvoiceShopName(extra);
          return true; // reached only if nothing threw
        },
        [extraGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ----------------------------------------------------------------------
    // Property 5b — Map<String,String> family: clinic + clothing.
    // Valid pass-through when the key is present; sentinel default otherwise.
    // ----------------------------------------------------------------------
    test('Property 5b: clinic/clothing Map<String,String> helpers pass valid '
        'values through and fall back to documented sentinels otherwise', () {
      final bool held = forAll(
        (Object? extra) {
          final bool isStrMap = extra is Map<String, String>;

          // patientId: value when present, else 'unknown'.
          final String expectPatientId =
              isStrMap && (extra)['patientId'] != null
              ? (extra as Map<String, String>)['patientId']!
              : 'unknown';
          if (consultationPatientId(extra) != expectPatientId) return false;
          if (historyPatientId(extra) != expectPatientId) return false;
          if (labsPatientId(extra) != expectPatientId) return false;

          // patientName: value when present, else 'Unknown Patient'.
          final String expectPatientName =
              isStrMap && (extra)['patientName'] != null
              ? (extra as Map<String, String>)['patientName']!
              : 'Unknown Patient';
          if (consultationPatientName(extra) != expectPatientName) {
            return false;
          }
          if (labsPatientName(extra) != expectPatientName) return false;

          // productId: value when present, else 'unknown'.
          final String expectProductId =
              isStrMap && (extra)['productId'] != null
              ? (extra as Map<String, String>)['productId']!
              : 'unknown';
          if (clothingProductId(extra) != expectProductId) return false;

          return true;
        },
        [extraGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ----------------------------------------------------------------------
    // Property 5c — raw-Map family: hardware + purchase.
    // ----------------------------------------------------------------------
    test(
      'Property 5c: hardware/purchase raw-Map helpers extract typed values '
      'and fall back to 0 / null / \'grocery\' for non-Map or absent keys',
      () {
        final bool held = forAll(
          (Object? extra) {
            final Map<String, dynamic> m = extra is Map
                ? Map<String, dynamic>.from(extra)
                : const <String, dynamic>{};

            final int expectTab = (m['initialTab'] as num?)?.toInt() ?? 0;
            if (hardwareInitialTab(extra) != expectTab) return false;

            final String? expectDeposit = m['depositStatus']?.toString();
            if (hardwareDepositStatus(extra) != expectDeposit) return false;

            final String expectVertical =
                m['verticalType'] as String? ?? 'grocery';
            if (purchaseVerticalType(extra) != expectVertical) return false;

            return true;
          },
          [extraGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // ----------------------------------------------------------------------
    // Property 5d — optional Bill (advanced_bill_creation).
    // Identical instance for a Bill; null fallback for everything else.
    // ----------------------------------------------------------------------
    test(
      'Property 5d: advancedBillEditing returns the Bill iff extra is a Bill, '
      'else null (create-mode fallback)',
      () {
        final bool held = forAll(
          (Object? extra) {
            final Bill? result = advancedBillEditing(extra);
            if (extra is Bill) {
              return identical(result, extra);
            }
            return result == null;
          },
          [extraGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // ----------------------------------------------------------------------
    // Property 5e — Customer (customer_app).
    // Extracts `.id` for a Customer; null fallback (LoginPage) otherwise.
    // ----------------------------------------------------------------------
    test(
      'Property 5e: customerAppId returns Customer.id iff extra is a Customer, '
      'else null (LoginPage fallback)',
      () {
        final bool held = forAll(
          (Object? extra) {
            final String? result = customerAppId(extra);
            if (extra is Customer) {
              return result == extra.id;
            }
            return result == null;
          },
          [extraGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // ----------------------------------------------------------------------
    // Property 5f — non-empty String family (customer_portal + notifications).
    // Empty string MUST fall back (the builders require isNotEmpty).
    // ----------------------------------------------------------------------
    test('Property 5f: customer_portal/notifications accept a non-empty String '
        'and fall back to null for empty/wrong-typed/null extra', () {
      final bool held = forAll(
        (Object? extra) {
          final String? expected = (extra is String && extra.isNotEmpty)
              ? extra
              : null;
          if (customerPortalId(extra) != expected) return false;
          if (notificationsCustomerId(extra) != expected) return false;
          return true;
        },
        [extraGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ----------------------------------------------------------------------
    // Property 5g — any-String family (cloud_sync_settings).
    // Distinct from 5f: an EMPTY string is VALID (no isNotEmpty check).
    // ----------------------------------------------------------------------
    test(
      'Property 5g: cloud_sync_settings accepts ANY String (incl. empty) and '
      'falls back to null (SettingsScreen) for non-String extra',
      () {
        final bool held = forAll(
          (Object? extra) {
            final String? expected = extra is String ? extra : null;
            return cloudSyncOwnerId(extra) == expected;
          },
          [extraGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // ----------------------------------------------------------------------
    // Property 5h — customer_report Map<String,String> requiring 'customerId'.
    // ----------------------------------------------------------------------
    test('Property 5h: customer_report extracts customerId iff extra is a '
        'Map<String,String> containing it, else null (error scaffold)', () {
      final bool held = forAll(
        (Object? extra) {
          final String? expected =
              (extra is Map<String, String> && extra.containsKey('customerId'))
              ? extra['customerId']
              : null;
          return customerReportCustomerId(extra) == expected;
        },
        [extraGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ----------------------------------------------------------------------
    // Property 5i — editable_invoice sentinel '' defaults.
    // ----------------------------------------------------------------------
    test('Property 5i: editable_invoice fields pass through Map<String,String> '
        "values and default to the '' sentinel otherwise", () {
      final bool held = forAll(
        (Object? extra) {
          final Map<String, String>? safe = extra is Map<String, String>
              ? extra
              : null;

          final String expectOwner = safe?['ownerName'] ?? '';
          if (editableInvoiceOwnerName(extra) != expectOwner) return false;

          final String expectShop = safe?['shopName'] ?? '';
          if (editableInvoiceShopName(extra) != expectShop) return false;

          return true;
        },
        [extraGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}
