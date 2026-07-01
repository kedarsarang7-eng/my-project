/// Double-Entry Accounting Module for DukanX
///
/// Provides Tally-style accounting features:
/// - Chart of Accounts (Ledger management)
/// - Automatic journal entry generation
/// - Trial Balance
/// - Profit & Loss Statement
/// - Balance Sheet
/// - General Ledger reports
library;

export 'models/models.dart';
export 'services/services.dart';
export 'repositories/accounting_repository.dart'; // Ensure repository is exported
export 'repositories/repositories.dart';
export 'screens/screens.dart';
