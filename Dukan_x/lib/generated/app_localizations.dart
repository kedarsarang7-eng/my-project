import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_pa.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
    Locale('gu'),
    Locale('hi'),
    Locale('kn'),
    Locale('ml'),
    Locale('mr'),
    Locale('pa'),
    Locale('ta'),
    Locale('te'),
    Locale('ur'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Billing App'**
  String get appTitle;

  /// Greeting message for user
  ///
  /// In en, this message translates to:
  /// **'Hello User'**
  String get helloUser;

  /// Title for owner login screen
  ///
  /// In en, this message translates to:
  /// **'Owner Login'**
  String get loginTitle;

  /// Subtitle for login screen
  ///
  /// In en, this message translates to:
  /// **'Sign in with your email and password.'**
  String get loginSubtitle;

  /// Label for email input field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Label for password input field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Text for login button
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// Title for dashboard screen
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// Label for bills tab
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get billTab;

  /// Label for stock tab
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stockTab;

  /// Label for reports tab
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTab;

  /// Label for settings tab
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTab;

  /// Label for shop ID field
  ///
  /// In en, this message translates to:
  /// **'Shop ID'**
  String get shopIdLabel;

  /// Error message when shop ID is not provided
  ///
  /// In en, this message translates to:
  /// **'Shop ID is required'**
  String get shopIdRequired;

  /// Error message when email is not provided
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// Error message when password is not provided
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// Text for forgot password link
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// Text for back to start button
  ///
  /// In en, this message translates to:
  /// **'Back to start'**
  String get backToStart;

  /// Label for total bills count
  ///
  /// In en, this message translates to:
  /// **'Total Bills'**
  String get total_bills;

  /// Label for pending dues amount
  ///
  /// In en, this message translates to:
  /// **'Pending Dues'**
  String get pending_dues;

  /// Label for total paid amount
  ///
  /// In en, this message translates to:
  /// **'Total Paid'**
  String get total_paid;

  /// Label for customers section
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// Label for settings section
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Welcome back message
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcome_back;

  /// Message when there are no bills
  ///
  /// In en, this message translates to:
  /// **'No Bills'**
  String get no_bills;

  /// Message shown when bills are assigned
  ///
  /// In en, this message translates to:
  /// **'Bills assigned message'**
  String get bills_assigned_message;

  /// Label for a single bill
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get bill_label;

  /// Label for amount field
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount_label;

  /// Label for remaining amount
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining_label;

  /// Pay button text
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get pay;

  /// Text indicating payment is complete
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid_text;

  /// Title for bill details screen
  ///
  /// In en, this message translates to:
  /// **'Bill Details'**
  String get bill_details;

  /// Status text for paid bills
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// Label for payment status
  ///
  /// In en, this message translates to:
  /// **'Payment Status'**
  String get payment_status;

  /// Label for items in a bill
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get itemsHeader;

  /// Close button text
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Title for owner dashboard
  ///
  /// In en, this message translates to:
  /// **'Owner Dashboard'**
  String get owner_dashboard;

  /// Message when owner sign-in is required
  ///
  /// In en, this message translates to:
  /// **'Owner Sign-in Required'**
  String get owner_signin_required;

  /// Title for owner login
  ///
  /// In en, this message translates to:
  /// **'Owner Login'**
  String get owner_login;

  /// Title for today's summary section
  ///
  /// In en, this message translates to:
  /// **'Today\'s Summary'**
  String get todays_summary;

  /// Label for total customers count
  ///
  /// In en, this message translates to:
  /// **'Total Customers'**
  String get total_customers;

  /// Label for total dues amount
  ///
  /// In en, this message translates to:
  /// **'Total Dues'**
  String get total_dues;

  /// Label for daily sales amount
  ///
  /// In en, this message translates to:
  /// **'Daily Sales'**
  String get daily_sales;

  /// Label for top customer
  ///
  /// In en, this message translates to:
  /// **'Top Customer'**
  String get top_customer;

  /// Label for home tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Button text to add customer
  ///
  /// In en, this message translates to:
  /// **'Add Customer'**
  String get add_customer;

  /// Label for bills section
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get bills;

  /// Button text to add vegetable
  ///
  /// In en, this message translates to:
  /// **'Add Vegetable'**
  String get add_vegetable;

  /// Label for khatabook feature
  ///
  /// In en, this message translates to:
  /// **'Khatabook'**
  String get khatabook;

  /// Label for finance section
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get finance;

  /// Button text to edit customer
  ///
  /// In en, this message translates to:
  /// **'Edit Customer'**
  String get edit_customer;

  /// Button text to manage profiles
  ///
  /// In en, this message translates to:
  /// **'Manage Profiles'**
  String get manage_profiles;

  /// Title for quick actions section
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quick_actions;

  /// Button text to register new customer
  ///
  /// In en, this message translates to:
  /// **'Register New Customer'**
  String get register_new_customer;

  /// Button text to make a bill
  ///
  /// In en, this message translates to:
  /// **'Make Bill'**
  String get make_bill;

  /// Subtitle for create bill action
  ///
  /// In en, this message translates to:
  /// **'Create Bill'**
  String get create_bill_subtitle;

  /// Subtitle for view customers action
  ///
  /// In en, this message translates to:
  /// **'View Customers'**
  String get view_customers_subtitle;

  /// Subtitle for create advanced bill action
  ///
  /// In en, this message translates to:
  /// **'Create Advanced Bill'**
  String get create_bill_advanced_subtitle;

  /// Subtitle for view bills action
  ///
  /// In en, this message translates to:
  /// **'View Bills'**
  String get view_bills_subtitle;

  /// Button text to manage vegetables
  ///
  /// In en, this message translates to:
  /// **'Manage Vegetables'**
  String get manage_vegetables;

  /// Subtitle for manage vegetables action
  ///
  /// In en, this message translates to:
  /// **'Manage Vegetables'**
  String get manage_vegetables_subtitle;

  /// Title for owner information section
  ///
  /// In en, this message translates to:
  /// **'Owner Info'**
  String get owner_info;

  /// Label for phone number field
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phone_number;

  /// Placeholder for customer search
  ///
  /// In en, this message translates to:
  /// **'Search Customers'**
  String get search_customers;

  /// Message when there are no customers
  ///
  /// In en, this message translates to:
  /// **'No Customers'**
  String get no_customers;

  /// Status text for pending items
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// Title for add customer form
  ///
  /// In en, this message translates to:
  /// **'Add Customer Form'**
  String get add_customer_form_title;

  /// Instructions for add customer form
  ///
  /// In en, this message translates to:
  /// **'Fill in the details below'**
  String get add_customer_form_steps;

  /// Message when search finds no customers
  ///
  /// In en, this message translates to:
  /// **'No customers found'**
  String get no_customers_found;

  /// Title for vegetables brought section
  ///
  /// In en, this message translates to:
  /// **'Vegetables Brought'**
  String get vegetables_brought;

  /// Message when there are no vegetables
  ///
  /// In en, this message translates to:
  /// **'No vegetables'**
  String get no_vegetables;

  /// Button text to edit profile
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get edit_profile;

  /// Edit button text
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Title for customer account section
  ///
  /// In en, this message translates to:
  /// **'Customer Account'**
  String get customer_account;

  /// Label for profile section
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Title for account security section
  ///
  /// In en, this message translates to:
  /// **'Account & Security'**
  String get accountSecurity;

  /// Title for language and appearance settings
  ///
  /// In en, this message translates to:
  /// **'Language & Appearance'**
  String get languageAppearance;

  /// Title for dashboard switch option
  ///
  /// In en, this message translates to:
  /// **'Dashboard Switch'**
  String get dashboardSwitch;

  /// Title for backup and sync section
  ///
  /// In en, this message translates to:
  /// **'Backup & Sync'**
  String get backupSync;

  /// Logout button text
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Button text to edit name
  ///
  /// In en, this message translates to:
  /// **'Edit Name'**
  String get editName;

  /// Button text to change profile photo
  ///
  /// In en, this message translates to:
  /// **'Change Profile Photo'**
  String get changePhoto;

  /// Save button text
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Button text to reset password
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// Confirmation message for logout
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get confirmLogout;

  /// Label for owner dashboard option
  ///
  /// In en, this message translates to:
  /// **'Owner Dashboard'**
  String get ownerDashboard;

  /// Label for customer dashboard option
  ///
  /// In en, this message translates to:
  /// **'Customer Dashboard'**
  String get customerDashboard;

  /// Title for permission error
  ///
  /// In en, this message translates to:
  /// **'Permission Error'**
  String get permissionError;

  /// Error message for customer access restriction
  ///
  /// In en, this message translates to:
  /// **'Customer users cannot access Owner Dashboard.'**
  String get customerAccessError;

  /// Label for language setting
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Label for theme setting
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Label for dark mode toggle
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Button text to scan bill
  ///
  /// In en, this message translates to:
  /// **'Scan Bill'**
  String get scan_bill;

  /// Subtitle for scan bill feature
  ///
  /// In en, this message translates to:
  /// **'Auto-create bill'**
  String get auto_create_bill;

  /// Button text for voice billing
  ///
  /// In en, this message translates to:
  /// **'Voice Bill'**
  String get voice_bill;

  /// Subtitle for voice bill feature
  ///
  /// In en, this message translates to:
  /// **'Speak to add'**
  String get speak_to_add;

  /// Title for recent transactions section
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recent_transactions;

  /// Button text to add transaction
  ///
  /// In en, this message translates to:
  /// **'Add Txn'**
  String get add_txn;

  /// Button text for vendor invoice
  ///
  /// In en, this message translates to:
  /// **'Vendor Invoice'**
  String get vendor_invoice;

  /// Button text for more options
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// Button text to see all items
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get see_all;

  /// Message when there are no recent transactions
  ///
  /// In en, this message translates to:
  /// **'No recent transactions'**
  String get no_recent_transactions;

  /// Button text to add new sale
  ///
  /// In en, this message translates to:
  /// **'Add New Sale'**
  String get add_new_sale;

  /// Label for insights tab
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// Label for items tab
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// Label for AI assistant feature
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get ai_assistant;

  /// Label for menu tab
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// Label for low stock indicator
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get low_stock;

  /// Morning greeting message
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get good_morning;

  /// Afternoon greeting message
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get good_afternoon;

  /// Evening greeting message
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get good_evening;

  /// Label for items count suffix
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get items_label;

  /// Skip button text
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboarding_skip;

  /// Title for business type selection screen
  ///
  /// In en, this message translates to:
  /// **'Choose Your Business Type'**
  String get onboarding_business_title;

  /// Subtitle for business type selection screen
  ///
  /// In en, this message translates to:
  /// **'This helps us customize your experience'**
  String get onboarding_business_subtitle;

  /// Label indicating an item is selected
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get onboarding_selected;

  /// Continue button text
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboarding_continue;

  /// Title for language selection screen
  ///
  /// In en, this message translates to:
  /// **'Select Your Preferred Language'**
  String get onboarding_language_title;

  /// Subtitle for language selection screen
  ///
  /// In en, this message translates to:
  /// **'You can change this anytime later'**
  String get onboarding_language_subtitle;

  /// Next button text
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboarding_next;

  /// Title for congratulations screen
  ///
  /// In en, this message translates to:
  /// **'All Set!'**
  String get onboarding_congratulations_title;

  /// Subtitle for congratulations screen
  ///
  /// In en, this message translates to:
  /// **'Your shop is ready'**
  String get onboarding_congratulations_subtitle;

  /// Button text to enter dashboard
  ///
  /// In en, this message translates to:
  /// **'Let\'s Go!'**
  String get onboarding_lets_go;

  /// Status message while loading translations
  ///
  /// In en, this message translates to:
  /// **'Setting up your language...'**
  String get language_setup_loading;

  /// Status message while applying language
  ///
  /// In en, this message translates to:
  /// **'Applying preferences...'**
  String get language_setup_applying;

  /// Status message while preparing app
  ///
  /// In en, this message translates to:
  /// **'Preparing your experience...'**
  String get language_setup_preparing;

  /// Status message when setup is complete
  ///
  /// In en, this message translates to:
  /// **'Ready!'**
  String get language_setup_complete;

  /// Error message when setup fails
  ///
  /// In en, this message translates to:
  /// **'Failed to setup language'**
  String get language_setup_error;

  /// Retry button text
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get language_setup_retry;

  /// Helper text on language selection screen
  ///
  /// In en, this message translates to:
  /// **'You can change this later in Settings'**
  String get language_confirm_message;

  /// Validation error when a required field is empty
  ///
  /// In en, this message translates to:
  /// **'{fieldName} is required'**
  String validationRequired(String fieldName);

  /// Validation error when field is too short
  ///
  /// In en, this message translates to:
  /// **'{fieldName} must be at least {min} characters'**
  String validationMinLength(String fieldName, int min);

  /// Validation error when field is too long
  ///
  /// In en, this message translates to:
  /// **'{fieldName} must be at most {max} characters'**
  String validationMaxLength(String fieldName, int max);

  /// Validation error for invalid email
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get validationInvalidEmail;

  /// Validation error for invalid phone number
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get validationInvalidPhone;

  /// Validation error for invalid GSTIN
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid GSTIN'**
  String get validationInvalidGstin;

  /// Validation error for invalid PAN number
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid PAN'**
  String get validationInvalidPan;

  /// Validation error when number is not positive
  ///
  /// In en, this message translates to:
  /// **'{fieldName} must be a positive number'**
  String validationPositiveNumber(String fieldName);

  /// Validation error when amount is zero or negative
  ///
  /// In en, this message translates to:
  /// **'Amount must be greater than zero'**
  String get validationAmountZero;

  /// Validation error when date is not in the future
  ///
  /// In en, this message translates to:
  /// **'{fieldName} must be a future date'**
  String validationFutureDate(String fieldName);

  /// Validation error when date is not in the past
  ///
  /// In en, this message translates to:
  /// **'{fieldName} must be a past date'**
  String validationPastDate(String fieldName);

  /// Validation error for weak password
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters with an uppercase letter and a number'**
  String get validationPasswordWeak;

  /// Validation error when two fields do not match
  ///
  /// In en, this message translates to:
  /// **'{field1} and {field2} do not match'**
  String validationMismatch(String field1, String field2);

  /// Display name for grocery business type
  ///
  /// In en, this message translates to:
  /// **'Grocery'**
  String get businessTypeGrocery;

  /// Display name for pharmacy business type
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get businessTypePharmacy;

  /// Display name for restaurant business type
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get businessTypeRestaurant;

  /// Display name for clothing business type
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get businessTypeClothing;

  /// Display name for electronics business type
  ///
  /// In en, this message translates to:
  /// **'Electronics'**
  String get businessTypeElectronics;

  /// Display name for mobile shop business type
  ///
  /// In en, this message translates to:
  /// **'Mobile Shop'**
  String get businessTypeMobileShop;

  /// Display name for computer shop business type
  ///
  /// In en, this message translates to:
  /// **'Computer Shop'**
  String get businessTypeComputerShop;

  /// Display name for hardware business type
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get businessTypeHardware;

  /// Display name for service business type
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get businessTypeService;

  /// Display name for wholesale business type
  ///
  /// In en, this message translates to:
  /// **'Wholesale'**
  String get businessTypeWholesale;

  /// Display name for petrol pump business type
  ///
  /// In en, this message translates to:
  /// **'Petrol Pump'**
  String get businessTypePetrolPump;

  /// Display name for vegetables broker business type
  ///
  /// In en, this message translates to:
  /// **'Vegetables Broker'**
  String get businessTypeVegetablesBroker;

  /// Display name for clinic business type
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get businessTypeClinic;

  /// Display name for book store business type
  ///
  /// In en, this message translates to:
  /// **'Book Store'**
  String get businessTypeBookStore;

  /// Display name for jewellery business type
  ///
  /// In en, this message translates to:
  /// **'Jewellery'**
  String get businessTypeJewellery;

  /// Display name for auto parts business type
  ///
  /// In en, this message translates to:
  /// **'Auto Parts'**
  String get businessTypeAutoParts;

  /// Display name for decoration and catering business type
  ///
  /// In en, this message translates to:
  /// **'Decoration & Catering'**
  String get businessTypeDecorationCatering;

  /// Display name for school ERP business type
  ///
  /// In en, this message translates to:
  /// **'School ERP'**
  String get businessTypeSchoolErp;

  /// Display name for other business type
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get businessTypeOther;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'bn',
    'en',
    'gu',
    'hi',
    'kn',
    'ml',
    'mr',
    'pa',
    'ta',
    'te',
    'ur',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
    case 'ml':
      return AppLocalizationsMl();
    case 'mr':
      return AppLocalizationsMr();
    case 'pa':
      return AppLocalizationsPa();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
