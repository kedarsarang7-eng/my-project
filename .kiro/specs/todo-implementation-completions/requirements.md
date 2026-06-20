# Requirements Document

## Introduction

This specification covers the implementation of all TODO/FIXME items across the monorepo's three Flutter applications (Dukan_x, staff_petrol_pump_app, dukan_customer_app). These are incomplete features that have placeholder code, mock data, or commented-out logic that must be completed to bring the system to production readiness. The work spans push notifications, database schema migrations, authentication flows, navigation, localization, and inter-app communication.

## Glossary

- **Dukan_x**: Main POS desktop Flutter application supporting 19 business verticals
- **Staff_App**: The staff_petrol_pump_app Flutter mobile application for petrol pump staff
- **Customer_App**: The dukan_customer_app Flutter mobile application for in-store customers
- **SNS**: AWS Simple Notification Service, used for push notifications
- **Drift**: Flutter SQLite ORM with code generation and real-time stream queries
- **Cognito**: AWS Cognito, the authentication service used across the backend
- **JWT**: JSON Web Token, used for session authentication claims
- **ARB**: Application Resource Bundle, Flutter's localization file format
- **GST**: Goods and Services Tax (India); IGST for inter-state, CGST+SGST for intra-state
- **DailyStats**: Backend model representing aggregated daily business metrics
- **GoRouter**: Declarative routing package used in Staff_App
- **TokenStorage**: Secure local storage abstraction for persisting auth tokens
- **NavigationController**: Riverpod-based navigation state manager in Dukan_x

## Requirements

### Requirement 1: AWS SNS Push Notification Integration

**User Story:** As a store owner using Dukan_x, I want to receive push notifications via AWS SNS, so that I am alerted about important business events (low stock, payments received, order updates) even when the app is in the background.

#### Acceptance Criteria

1. WHEN the application initializes on a native platform, THE NotificationController SHALL register the device with AWS SNS and obtain a platform endpoint ARN
2. WHEN a user subscribes to a topic, THE NotificationController SHALL create an SNS subscription for the device endpoint to the specified topic ARN
3. WHEN a user unsubscribes from a topic, THE NotificationController SHALL remove the SNS subscription for the device endpoint from the specified topic ARN
4. IF the SNS registration fails due to network error, THEN THE NotificationController SHALL log the failure and retry on next app launch
5. WHEN a push notification is received, THE NotificationController SHALL display it using the local notification system

### Requirement 2: Drift Schema Migration — Customer Entity

**User Story:** As a developer, I want the CustomerEntity Drift schema to include a loyaltyPoints field, so that loyalty points can be stored locally for offline access and search.

#### Acceptance Criteria

1. WHEN a Drift schema migration runs, THE CustomerEntity table SHALL include an integer column named loyaltyPoints with a default value of zero
2. WHEN a customer record is converted to a map via _customerToMap, THE Offline_Search_Service SHALL include the loyaltyPoints field in the output map
3. WHEN upgrading from the previous schema version, THE migration SHALL add the loyaltyPoints column without data loss to existing rows

### Requirement 3: Drift Schema Migration — Product Entity

**User Story:** As a developer, I want the ProductEntity Drift schema to include isbn, author, and publisher fields, so that book store products can be fully searchable offline.

#### Acceptance Criteria

1. WHEN a Drift schema migration runs, THE ProductEntity table SHALL include nullable text columns named isbn, author, and publisher
2. WHEN a product record is converted to a map via _productToMap, THE Offline_Search_Service SHALL include isbn, author, and publisher fields in the output map
3. WHEN upgrading from the previous schema version, THE migration SHALL add the three columns without data loss to existing rows

### Requirement 4: Real-Time Customer Bills Stream

**User Story:** As a store owner viewing customer statements, I want the bill list to update in real-time, so that newly created bills appear without manual refresh.

#### Acceptance Criteria

1. WHEN watchCustomerBills is called, THE StatementsService SHALL return a Drift watch stream that emits updated bill lists whenever underlying data changes
2. WHILE the stream is active, THE StatementsService SHALL emit a new list each time a bill matching the customer and date range is inserted, updated, or deleted
3. WHEN the stream subscription is cancelled, THE StatementsService SHALL release all associated database watchers

### Requirement 5: Bill Model isInterState Field

**User Story:** As a store owner doing inter-state sales, I want the Bill model to carry an isInterState flag, so that the print service can correctly compute IGST versus CGST+SGST.

#### Acceptance Criteria

1. THE Bill model SHALL include a boolean field named isInterState with a default value of false
2. WHEN a bill is created for an inter-state transaction, THE Bill model SHALL store isInterState as true
3. WHEN the bill print service renders GST breakdowns, THE BillPrintService SHALL use the Bill's isInterState field instead of a hardcoded extension

### Requirement 6: Navigation Controller Re-enable

**User Story:** As a developer, I want to re-enable the navigation history clearing on session lock, so that sensitive screen state is not retained after a security timeout.

#### Acceptance Criteria

1. WHEN the session timeout manager locks the session, THE SessionTimeoutManager SHALL call navigationControllerProvider.notifier.clearHistory()
2. IF the NavigationController provider is not available, THEN THE SessionTimeoutManager SHALL log the error and continue the lock operation without crashing

### Requirement 7: ARB Localization for Business Types

**User Story:** As a user of the app in Hindi or Marathi, I want business type names translated, so that I see localized labels throughout the UI.

#### Acceptance Criteria

1. THE BusinessTypeL10n SHALL resolve display names from AppLocalizations ARB keys instead of returning hardcoded English strings
2. WHEN a supported locale is active, THE BusinessTypeL10n SHALL return the translated business type name for that locale
3. WHEN a locale is not supported, THE BusinessTypeL10n SHALL fall back to the English ARB value

### Requirement 8: Analytics Dashboard Backend Fields

**User Story:** As a store owner viewing the analytics dashboard, I want to see today's collections, today's bill count, monthly bill count, and customer count, so that I have a complete view of business performance.

#### Acceptance Criteria

1. THE DailyStats model SHALL include fields: todayCollections (double), todayBillCount (int), monthlyBillCount (int), and customerCount (int)
2. WHEN the analytics dashboard subscribes to daily stats, THE AnalyticsDashboard SHALL display actual values from the DailyStats model instead of null placeholders
3. WHEN the backend response does not include one of the new fields, THE DailyStats model SHALL default that field to zero

### Requirement 9: Auth Token Validation and Refresh (Staff App)

**User Story:** As a petrol pump staff member using biometric login, I want my stored tokens validated and refreshed automatically, so that I am not forced to re-enter credentials unless truly expired.

#### Acceptance Criteria

1. WHEN loginWithBiometrics is called, THE AuthRemoteDataSource SHALL decode the stored access token and check its expiration claim
2. IF the access token is expired but refresh token is valid, THEN THE AuthRemoteDataSource SHALL use the Cognito refresh flow to obtain new tokens
3. IF both tokens are expired, THEN THE AuthRemoteDataSource SHALL throw an authentication exception requiring credential login
4. WHEN tokens are successfully refreshed, THE AuthRemoteDataSource SHALL store the new tokens via TokenStorage and return the decoded user

### Requirement 10: Token Expiration Check (Staff App)

**User Story:** As a petrol pump staff member, I want the isLoggedIn check to verify token expiration, so that the app does not treat expired sessions as active.

#### Acceptance Criteria

1. WHEN isLoggedIn is called, THE AuthRemoteDataSource SHALL decode the stored JWT access token and verify the exp claim against current time
2. IF the token's exp claim is in the past, THEN THE AuthRemoteDataSource SHALL return false

### Requirement 11: Get Current User from Token (Staff App)

**User Story:** As a petrol pump staff member, I want getCurrentUser to return my profile from the stored token, so that the app can display my identity without a network call.

#### Acceptance Criteria

1. WHEN getCurrentUser is called with a valid stored token, THE AuthRemoteDataSource SHALL decode the ID token and construct a StaffUserModel from its claims
2. IF no valid token is stored, THEN THE AuthRemoteDataSource SHALL return null

### Requirement 12: Force Password Change Wiring (Staff App)

**User Story:** As a new petrol pump staff member, I want the force-password-change screen to actually change my password, so that I can complete onboarding.

#### Acceptance Criteria

1. WHEN the user submits a new password on the force-password-change screen, THE ForcePasswordChangeScreen SHALL call AuthNotifier.completeNewPassword with staffId, temporaryPassword, and newPassword
2. WHEN the password change succeeds, THE ForcePasswordChangeScreen SHALL navigate the user to the home screen
3. IF the password change fails, THEN THE ForcePasswordChangeScreen SHALL display the error message to the user

### Requirement 13: Biometric Authentication (Staff App)

**User Story:** As a petrol pump staff member, I want to log in via fingerprint or face recognition, so that I can start my shift quickly without typing credentials.

#### Acceptance Criteria

1. WHEN the biometric button is pressed, THE BiometricButton SHALL check device biometric availability using local_auth
2. IF biometrics are available, THEN THE BiometricButton SHALL authenticate the user via the local_auth plugin
3. WHEN biometric authentication succeeds, THE BiometricButton SHALL call loginWithBiometrics on the auth datasource
4. IF biometrics are not available on the device, THEN THE BiometricButton SHALL display a message indicating biometric login is not supported

### Requirement 14: Payment Amount Pre-fill on Retry (Staff App)

**User Story:** As a petrol pump staff member retrying a failed payment, I want the amount pre-filled, so that I do not have to re-enter it.

#### Acceptance Criteria

1. WHEN the retry button is pressed on the payment failed screen, THE PaymentFailedScreen SHALL navigate to /qr/entry with the previous amount as a query parameter
2. WHEN the QR entry screen receives an amount query parameter, THE QrEntryScreen SHALL pre-fill the amount input field with that value

### Requirement 15: Print Receipt (Staff App)

**User Story:** As a petrol pump staff member, I want to print a receipt after a successful payment, so that I can hand it to the customer.

#### Acceptance Criteria

1. WHEN the print receipt button is pressed, THE PaymentSuccessScreen SHALL generate a PDF receipt containing transaction amount, date/time, and payment reference
2. WHEN the PDF is generated, THE PaymentSuccessScreen SHALL send the document to the system printer via the printing package
3. IF printing fails, THEN THE PaymentSuccessScreen SHALL display an error message to the user

### Requirement 16: Sidebar Navigation Routes (Staff App)

**User Story:** As a petrol pump staff member, I want sidebar navigation items (Sales, Inventory, Customers, Settings) to route correctly, so that I can access all sections of the app.

#### Acceptance Criteria

1. WHEN the Sales navigation item is pressed, THE SidebarNavWidget SHALL navigate to the /sales route
2. WHEN the Inventory navigation item is pressed, THE SidebarNavWidget SHALL navigate to the /inventory route
3. WHEN the Customers navigation item is pressed, THE SidebarNavWidget SHALL navigate to the /customers route
4. WHEN the Settings navigation item is pressed, THE SidebarNavWidget SHALL navigate to the /settings route

### Requirement 17: Sidebar Logout (Staff App)

**User Story:** As a petrol pump staff member, I want to log out from the sidebar, so that I can end my session securely.

#### Acceptance Criteria

1. WHEN the logout option is selected, THE SidebarNavWidget SHALL call the auth datasource logout method
2. WHEN logout succeeds, THE SidebarNavWidget SHALL clear local auth state and navigate to the login screen
3. IF logout fails, THEN THE SidebarNavWidget SHALL display an error message

### Requirement 18: Staff Call Notification (Customer App)

**User Story:** As an in-store customer who cannot find a product, I want to call a staff member via the app, so that I get assistance without leaving my location.

#### Acceptance Criteria

1. WHEN the "Call Staff" button is pressed, THE InStoreShoppingScreen SHALL send a staff assistance request to the backend API
2. WHEN the backend receives the request, THE Backend SHALL trigger a push notification to on-duty staff devices for that store
3. IF the API call fails, THEN THE InStoreShoppingScreen SHALL display an error message indicating the request could not be sent
