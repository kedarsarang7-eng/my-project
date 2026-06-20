# Implementation Plan: TODO Implementation Completions

## Overview

Implements all 18 TODO/FIXME items across the monorepo's three Flutter apps. Tasks are ordered so that foundational work (models, schemas, utilities) comes first, then integration wiring, then UI-layer completions. Each task is self-contained and testable.

## Tasks

- [x] 1. Drift Schema Migration v42 — Add missing columns (Dukan_x)
  - [x] 1.1 Add loyaltyPoints column to Customers table in tables.dart
    - Add `IntColumn get loyaltyPoints => integer().withDefault(const Constant(0))();` to the Customers table definition
    - Add `TextColumn get isbn => text().nullable()();`, `author`, `publisher` to Products table definition
    - _Requirements: 2.1, 3.1_
  - [x] 1.2 Add migration block for schema version 42 in app_database.dart
    - Bump `schemaVersion` from 41 to 42
    - Add `if (from < 42)` block with `m.addColumn(customers, customers.loyaltyPoints)`, `m.addColumn(products, products.isbn)`, `m.addColumn(products, products.author)`, `m.addColumn(products, products.publisher)`
    - _Requirements: 2.1, 2.3, 3.1, 3.3_
  - [x] 1.3 Uncomment loyaltyPoints in _customerToMap and book fields in _productToMap
    - In `offline_search_service.dart`, uncomment `'loyaltyPoints': c.loyaltyPoints`
    - Uncomment `'isbn': p.isbn`, `'author': p.author`, `'publisher': p.publisher`
    - _Requirements: 2.2, 3.2_
  - [ ]* 1.4 Write property tests for _customerToMap and _productToMap
    - **Property 5: Customer Map Contains loyaltyPoints**
    - **Validates: Requirements 2.2**
    - **Property 6: Product Map Contains Book Fields**
    - **Validates: Requirements 3.2**
  - [x] 1.5 Run Drift code generation
    - Execute `dart run build_runner build --delete-conflicting-outputs` in the Dukan_x project
    - Verify generated `app_database.g.dart` and `tables.g.dart` compile without errors
    - _Requirements: 2.1, 3.1_

- [x] 2. DailyStats Model Enhancement (Dukan_x)
  - [x] 2.1 Add new fields to DailyStats model
    - Add `todayCollections` (double), `todayBillCount` (int), `monthlyBillCount` (int), `customerCount` (int) to DailyStats class
    - Update `DailyStats.empty()` factory to include the new fields with default 0
    - Add `factory DailyStats.fromJson(Map<String, dynamic> json)` with fallback to 0 for missing keys
    - _Requirements: 8.1, 8.3_
  - [ ]* 2.2 Write property test for DailyStats.fromJson parsing
    - **Property 3: DailyStats Parsing Resilience**
    - **Validates: Requirements 8.1, 8.3**
  - [x] 2.3 Update analytics_dashboard_screen.dart to use actual DailyStats fields
    - Replace `'todayCollections': stats.paidThisMonth` with `stats.todayCollections`
    - Replace null placeholders with `stats.todayBillCount`, `stats.monthlyBillCount`, `stats.customerCount`
    - _Requirements: 8.2_

- [x] 3. Bill Model isInterState Field (Dukan_x)
  - [x] 3.1 Add isInterState field to Bill class
    - Add `bool isInterState;` field with default `false` in constructor
    - Add to `fromJson()` / `toJson()` methods: `'isInterState': isInterState`
    - _Requirements: 5.1, 5.2_
  - [x] 3.2 Remove _BillGstExt extension and use model field in BillPrintService
    - Delete the `extension _BillGstExt on Bill` block in `bill_print_service.dart`
    - The print service already references `bill.isInterState` — verify it compiles with the model field
    - _Requirements: 5.3_
  - [ ]* 3.3 Write property test for Bill isInterState serialization round-trip
    - **Property 4: Bill isInterState Serialization Round-Trip**
    - **Validates: Requirements 5.1, 5.2**

- [x] 4. Real-Time Customer Bills Stream (Dukan_x)
  - [x] 4.1 Add watchCustomerBillsForStatement to repository layer
    - Create a Drift `.watch()` query in the repository that returns `Stream<List<Bill>>` filtering by customerId, startDate, endDate
    - _Requirements: 4.1, 4.2_
  - [x] 4.2 Update StatementsService.watchCustomerBills to use the stream
    - Replace the one-shot fetch + single yield with `yield*` on the repository watch stream
    - Remove the `// TODO` comment
    - _Requirements: 4.1, 4.2, 4.3_

- [x] 5. Checkpoint — Dukan_x Model & Schema Tasks
  - Ensure all tests pass, ask the user if questions arise.
  - Run `dart run build_runner build` to regenerate Drift code
  - Run `flutter analyze` in Dukan_x to verify no compile errors

- [x] 6. Navigation Controller Re-enable & ARB Localization (Dukan_x)
  - [x] 6.1 Re-enable clearHistory in SessionTimeoutManager
    - Uncomment `ref.read(navigationControllerProvider.notifier).clearHistory()`
    - Wrap in try-catch: catch any `ProviderException` or `StateError`, log with `developer.log`, continue
    - _Requirements: 6.1, 6.2_
  - [x] 6.2 Add ARB keys for all 19 business types
    - Add keys `businessTypeGrocery`, `businessTypePharmacy`, ... `businessTypeOther` to `app_en.arb`, `app_hi.arb`, `app_mr.arb`
    - Values in Hindi/Marathi can be taken from the existing `_localizedDesc` patterns in the file
    - _Requirements: 7.1, 7.2, 7.3_
  - [x] 6.3 Update BusinessTypeL10n.name() to use AppLocalizations
    - Replace hardcoded strings with `AppLocalizations.of(context)!.businessTypeGrocery` etc.
    - Add null-check fallback: if `AppLocalizations.of(context)` is null, return English default
    - Run `flutter gen-l10n` to regenerate localization code
    - _Requirements: 7.1, 7.2, 7.3_

- [x] 7. AWS SNS Push Notification Integration (Dukan_x)
  - [x] 7.1 Create AwsSnsService class
    - Create `lib/core/services/aws_sns_service.dart`
    - Implement `registerDevice(String platformToken, String userId)` → POST to backend `/notifications/register`
    - Implement `subscribe(String endpointArn, String topicArn)` → POST to backend `/notifications/subscribe`
    - Implement `unsubscribe(String endpointArn, String topicArn)` → POST to backend `/notifications/unsubscribe`
    - _Requirements: 1.1, 1.2, 1.3_
  - [x] 7.2 Update NotificationController to use AwsSnsService
    - Inject `AwsSnsService` into `NotificationController`
    - Implement `getToken()`: get platform token, call `registerDevice()`, store endpoint ARN
    - Implement `subscribeToTopic()`: call `AwsSnsService.subscribe()` with stored endpoint ARN
    - Implement `unsubscribeFromTopic()`: call `AwsSnsService.unsubscribe()`
    - Add retry-on-failure logic: store a flag in SharedPreferences, retry in next `init()`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
  - [ ]* 7.3 Write unit tests for AwsSnsService (mock HTTP)
    - Test register, subscribe, unsubscribe API calls
    - Test error handling and retry flag
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 8. Checkpoint — Dukan_x Complete
  - Ensure all tests pass, ask the user if questions arise.
  - Run `flutter analyze` in Dukan_x

- [x] 9. JWT Utility & Token Validation (Staff App)
  - [x] 9.1 Create JWT decode utility
    - Create `staff_petrol_pump_app/lib/core/auth/jwt_utils.dart`
    - Implement `Map<String, dynamic> decodeJwtPayload(String token)` — split on `.`, base64url decode segment 1, jsonDecode
    - Implement `bool isTokenExpired(String token)` — extract `exp`, compare to current time
    - _Requirements: 9.1, 10.1, 10.2_
  - [ ]* 9.2 Write property tests for JWT utilities
    - **Property 1: JWT Decode Round-Trip**
    - **Validates: Requirements 9.1, 10.1, 11.1**
    - **Property 2: Token Expiration Detection**
    - **Validates: Requirements 10.1, 10.2**
  - [x] 9.3 Implement loginWithBiometrics token validation and refresh
    - In `auth_remote_datasource.dart`, replace mock return with:
      - Decode access token, check expiration
      - If expired: attempt refresh via `CognitoUser.getSession()` with stored refresh token
      - If refresh succeeds: store new tokens, decode ID token, return StaffUserModel
      - If refresh fails: throw exception
    - _Requirements: 9.1, 9.2, 9.3, 9.4_
  - [x] 9.4 Implement isLoggedIn with token expiration check
    - Decode stored access token, check exp claim
    - Return false if expired or malformed
    - _Requirements: 10.1, 10.2_
  - [x] 9.5 Implement getCurrentUser from stored ID token
    - Decode ID token claims, construct StaffUserModel from `sub`, `name`, `custom:role`, `custom:station_id`
    - Return null if no valid token stored
    - _Requirements: 11.1, 11.2_

- [x] 10. Force Password Change & Biometric Wiring (Staff App)
  - [x] 10.1 Add completeNewPassword to AuthNotifier
    - Create or update AuthNotifier (Riverpod StateNotifier/AsyncNotifier) with `completeNewPassword(staffId, tempPassword, newPassword)` method
    - Delegate to `AuthRemoteDataSource.completeNewPassword()`
    - _Requirements: 12.1_
  - [x] 10.2 Wire ForcePasswordChangeScreen to AuthNotifier
    - Replace `await Future.delayed(...)` with `ref.read(authNotifierProvider.notifier).completeNewPassword(...)`
    - On success: navigate to home. On error: display message.
    - _Requirements: 12.1, 12.2, 12.3_
  - [x] 10.3 Implement BiometricButton with local_auth
    - Add `local_auth` to pubspec.yaml if not present
    - In `biometric_button.dart`: check `canCheckBiometrics`, call `authenticate()`, then `loginWithBiometrics()`
    - Handle `PlatformException` for unsupported devices
    - _Requirements: 13.1, 13.2, 13.3, 13.4_

- [x] 11. Checkpoint — Staff App Auth Complete
  - Ensure all tests pass, ask the user if questions arise.
  - Run `flutter analyze` in staff_petrol_pump_app

- [x] 12. Staff App UI Completions (Navigation, Payment, Print)
  - [x] 12.1 Implement sidebar navigation routes
    - Replace empty `onTap` callbacks with `context.go('/sales')`, `context.go('/inventory')`, `context.go('/customers')`, `context.go('/settings')`
    - Add placeholder GoRoute entries in `fuelpos_router.dart` for any missing routes (sales, inventory, customers, settings)
    - _Requirements: 16.1, 16.2, 16.3, 16.4_
  - [x] 12.2 Implement sidebar logout
    - In the `onSelected` callback for 'logout': call `AuthRemoteDataSourceImpl().logout()`, then `context.go('/login')`
    - Show error snackbar if logout throws
    - _Requirements: 17.1, 17.2, 17.3_
  - [x] 12.3 Implement payment amount pre-fill on retry
    - In `_onRetry()`: change `context.go('/qr/entry')` to `context.go('/qr/entry?amount=$previousAmount')`
    - In `AmountEntryScreen`: read `GoRouterState.of(context).uri.queryParameters['amount']` and set as initial value of amount text controller
    - _Requirements: 14.1, 14.2_
  - [x] 12.4 Implement print receipt
    - In `_onPrintReceipt()`: generate a PDF using `pw.Document()` with transaction details (amount, date, reference, station)
    - Call `Printing.layoutPdf(onLayout: (format) => doc.save())` to send to printer
    - Wrap in try-catch; show error snackbar on failure
    - _Requirements: 15.1, 15.2, 15.3_

- [x] 13. Staff Call Notification (Customer App)
  - [x] 13.1 Create staff call API service in dukan_customer_app
    - Create or update an API service class with method: `Future<void> callStaff(String storeId, String reason)`
    - POST to `/stores/{storeId}/staff-call` with body `{"reason": "product_not_found"}`
    - _Requirements: 18.1, 18.2_
  - [x] 13.2 Wire InStoreShoppingScreen "Call Staff" button to API
    - In the `onPressed` callback: call the staff call API service
    - On success: show confirmation dialog/snackbar ("Staff has been notified")
    - On failure: show error message ("Could not reach staff, please try again")
    - _Requirements: 18.1, 18.3_

- [x] 14. Final Checkpoint — All Apps
  - Ensure all tests pass, ask the user if questions arise.
  - Run `flutter analyze` in all three projects
  - Verify Drift code generation is up to date in Dukan_x

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation across the three projects
- Property tests validate universal correctness properties (JWT decode, model parsing, entity mapping)
- The 18 TODO items map to 14 task groups for logical ordering
- Drift code generation (`build_runner`) must run after schema changes (Task 1.5, Checkpoint 5)

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["1.3"] },
    { "id": 3, "tasks": ["1.5", "2.1", "3.1"] },
    { "id": 4, "tasks": ["2.3", "3.2", "4.1"] },
    { "id": 5, "tasks": ["4.2", "5"] },
    { "id": 6, "tasks": ["6.1", "6.2", "7.1", "9.1"] },
    { "id": 7, "tasks": ["6.3", "7.2", "9.3", "9.4", "9.5"] },
    { "id": 8, "tasks": ["8", "10.1"] },
    { "id": 9, "tasks": ["10.2", "10.3"] },
    { "id": 10, "tasks": ["11"] },
    { "id": 11, "tasks": ["12.1", "12.2", "12.3", "12.4", "13.1"] },
    { "id": 12, "tasks": ["13.2"] },
    { "id": 13, "tasks": ["14"] }
  ]
}
```
