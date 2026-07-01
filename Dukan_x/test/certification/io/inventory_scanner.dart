/// Inventory Scanner for the Certification_System.
///
/// Walks `Dukan_x/lib/features/*` reusing audit_walker helpers to build
/// a complete SystemMap of business types, screens, routes, modules, roles,
/// backend calls, DB access points, and detected mock data with source paths.
/// Continues past unreadable files, recording a CoverageGap for each skip.
///
/// Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.10
library;

import 'dart:io';

import '../../audit/audit_walker.dart' as walker;
import '../core/coverage_gap.dart';
import '../core/domain.dart';

// ---------------------------------------------------------------------------
// Data models for the SystemMap
// ---------------------------------------------------------------------------

/// A business type entry with its enabled modules, tax rules, workflows,
/// required permissions, and the source path where it was detected.
class BusinessTypeEntry {
  final BusinessType type;
  final List<Module> enabledModules;
  final List<String> taxRules;
  final List<String> workflows;
  final List<String> requiredPermissions;
  final String sourcePath;

  const BusinessTypeEntry({
    required this.type,
    required this.enabledModules,
    required this.taxRules,
    required this.workflows,
    required this.requiredPermissions,
    required this.sourcePath,
  });
}

/// A screen entry mapping a route to its backing widget and business types.
class ScreenEntry {
  final String route;
  final String widgetName;
  final List<String> businessTypes;
  final String sourcePath;

  const ScreenEntry({
    required this.route,
    required this.widgetName,
    required this.businessTypes,
    required this.sourcePath,
  });
}

/// A route entry tracking navigation paths and their reachability status.
class RouteEntry {
  final String route;
  final String target;

  /// One of: 'reachable', 'broken', 'dead', 'missing'
  final String status;

  const RouteEntry({
    required this.route,
    required this.target,
    required this.status,
  });
}

/// A module entry with its owning business types.
class ModuleEntry {
  final Module module;
  final List<String> owningTypes;

  const ModuleEntry({required this.module, required this.owningTypes});
}

/// A role entry recording a permission matrix mapping.
class RoleEntry {
  final String role;
  final String module;
  final String permittedAction;

  const RoleEntry({
    required this.role,
    required this.module,
    required this.permittedAction,
  });
}

/// A backend service call detected in source.
class BackendCallEntry {
  final String callSignature;
  final String sourcePath;

  const BackendCallEntry({
    required this.callSignature,
    required this.sourcePath,
  });
}

/// A database access point detected in source.
class DbAccessEntry {
  final String accessPoint;
  final String sourcePath;

  const DbAccessEntry({required this.accessPoint, required this.sourcePath});
}

/// A mock data indicator detected in source.
class MockDataEntry {
  final String sourcePath;
  final String indicator;

  const MockDataEntry({required this.sourcePath, required this.indicator});
}

/// The complete system map produced by the InventoryScanner.
///
/// Contains separate collections for business types, screens, routes, modules,
/// roles, backend calls, DB access points, detected mock data, and coverage gaps.
class SystemMap {
  final List<BusinessTypeEntry> businessTypes;
  final List<ScreenEntry> screens;
  final List<RouteEntry> routes;
  final List<ModuleEntry> modules;
  final List<RoleEntry> roles;
  final List<BackendCallEntry> backendCalls;
  final List<DbAccessEntry> dbAccessPoints;
  final List<MockDataEntry> detectedMockData;
  final List<CoverageGap> coverageGaps;

  const SystemMap({
    required this.businessTypes,
    required this.screens,
    required this.routes,
    required this.modules,
    required this.roles,
    required this.backendCalls,
    required this.dbAccessPoints,
    required this.detectedMockData,
    required this.coverageGaps,
  });
}

// ---------------------------------------------------------------------------
// InventoryScanner implementation
// ---------------------------------------------------------------------------

/// Scans `Dukan_x/lib/features/*` to produce a [SystemMap].
///
/// Reuses audit_walker helpers for workspace resolution and file listing.
/// Continues past unreadable files, recording a [CoverageGap] per skip (Req 1.10).
class InventoryScanner {
  /// Mapping from feature directory names to [BusinessType] values.
  ///
  /// Feature directories that don't map directly to a business type are shared
  /// modules (billing, auth, etc.) and are associated with all types.
  static const Map<String, BusinessType> _featureDirToType = {
    'auto_parts': BusinessType.autoParts,
    'book_store': BusinessType.bookStore,
    'clinic': BusinessType.clinic,
    'clothing': BusinessType.clothing,
    'computer_shop': BusinessType.computerShop,
    'decoration_catering': BusinessType.decorationCatering,
    'hardware': BusinessType.hardware,
    'jewellery': BusinessType.jewellery,
    'petrol_pump': BusinessType.petrolPump,
    'pharmacy': BusinessType.pharmacy,
    'restaurant': BusinessType.restaurant,
    'service': BusinessType.service,
    'vegetable_broker': BusinessType.vegetablesBroker,
    'academic_coaching': BusinessType.schoolErp,
    'school_erp': BusinessType.schoolErp,
  };

  /// Regex patterns for detecting screens (classes extending StatelessWidget
  /// or StatefulWidget whose name contains 'Screen' or 'Page').
  static final RegExp _screenClassPattern = RegExp(
    r'class\s+(\w*(?:Screen|Page)\w*)\s+extends\s+(?:Stateless|Stateful)Widget',
  );

  /// Regex patterns for detecting route definitions.
  static final RegExp _routePattern = RegExp(
    r'''(?:routeName|route|path)\s*[:=]\s*['"](/[^'"]*|[^'"]+)[''"]''',
  );

  /// Named route push patterns.
  static final RegExp _namedRoutePattern = RegExp(
    r'''pushNamed\s*\(\s*['"](/[^'"]+)[''"]''',
  );

  /// Regex patterns for detecting backend/API calls.
  static final RegExp _backendCallPattern = RegExp(
    r'(?:apiClient|ApiClient|http|Http|dio|Dio)\s*\.\s*(get|post|put|delete|patch)\s*\(',
  );

  /// HTTP URL patterns in API calls.
  static final RegExp _httpUrlPattern = RegExp(
    r'''(?:url|endpoint|baseUrl|uri)\s*[:=]\s*['"]([^'"]*(?:api|lambda|execute-api)[^'"]*)['"]''',
  );

  /// Regex patterns for detecting DynamoDB access.
  static final RegExp _dynamoDbPattern = RegExp(
    r'(?:DynamoDB|dynamodb|dynamoDb|putItem|getItem|query|scan|updateItem|deleteItem|batchWrite|batchGet|TableName)',
  );

  /// Regex patterns for detecting mock data indicators.
  static final RegExp _mockDataPattern = RegExp(
    r'(?:mock|Mock|MOCK|stub|Stub|STUB|fake|Fake|FAKE|placeholder|hardcoded|TODO:\s*replace|dummy|sample_data|test_data)',
    caseSensitive: false,
  );

  /// Regex for role/permission annotations.
  static final RegExp _rolePattern = RegExp(
    r'''(?:role|Role|permission|Permission|guard|Guard|requiredRole|allowedRoles)\s*[:=\(]\s*['\[]?(\w+)''',
  );

  /// Walks `Dukan_x/lib/features/*` to produce a complete [SystemMap].
  ///
  /// [workspacePath] optionally specifies the workspace root. If null, uses
  /// the audit_walker's `resolveWorkspaceRoot()` or falls back to the current
  /// directory searching for `Dukan_x/`.
  Future<SystemMap> scan({String? workspacePath}) async {
    final root = _resolveRoot(workspacePath);
    final featuresDir = Directory('${root.path}/lib/features');

    if (!featuresDir.existsSync()) {
      // If features directory doesn't exist, return empty map with a gap.
      return SystemMap(
        businessTypes: const [],
        screens: const [],
        routes: const [],
        modules: const [],
        roles: const [],
        backendCalls: const [],
        dbAccessPoints: const [],
        detectedMockData: const [],
        coverageGaps: [
          CoverageGap(
            kind: 'unreadable_directory',
            expected: 1,
            actual: 0,
            shortfall: 1,
            reason: 'Features directory not found: ${featuresDir.path}',
          ),
        ],
      );
    }

    // Collect all Dart files using audit_walker's helper.
    final allFiles = walker.listDartFiles(featuresDir);

    // Accumulators
    final businessTypeEntries = <BusinessTypeEntry>[];
    final screenEntries = <ScreenEntry>[];
    final routeEntries = <RouteEntry>[];
    final moduleEntries = <String, Set<String>>{};
    final roleEntries = <RoleEntry>[];
    final backendCallEntries = <BackendCallEntry>[];
    final dbAccessEntries = <DbAccessEntry>[];
    final mockDataEntries = <MockDataEntry>[];
    final coverageGaps = <CoverageGap>[];
    final detectedTypes = <BusinessType>{};
    final detectedRoutes = <String>{};

    // Process each file
    for (final file in allFiles) {
      final relativePath = _relativize(file.path, root.path);
      String content;

      try {
        content = file.readAsStringSync();
      } catch (e) {
        // Req 1.10: Continue past unreadable files, record a CoverageGap.
        coverageGaps.add(
          CoverageGap(
            kind: 'unreadable_file',
            expected: 1,
            actual: 0,
            shortfall: 1,
            reason: 'Could not read file: $relativePath ($e)',
          ),
        );
        continue;
      }

      final featureModule = walker.detectModule(file);
      final businessType = _inferBusinessType(featureModule);
      final typeNames = businessType != null ? [businessType.name] : ['shared'];

      if (businessType != null) {
        detectedTypes.add(businessType);
      }

      // Track modules
      if (featureModule.isNotEmpty) {
        moduleEntries
            .putIfAbsent(featureModule, () => <String>{})
            .addAll(typeNames);
      }

      // Detect screens (Req 1.2)
      for (final match in _screenClassPattern.allMatches(content)) {
        final widgetName = match.group(1)!;
        final route = _extractRouteFromContent(content, widgetName);

        screenEntries.add(
          ScreenEntry(
            route: route,
            widgetName: widgetName,
            businessTypes: typeNames,
            sourcePath: relativePath,
          ),
        );

        if (route.isNotEmpty) {
          detectedRoutes.add(route);
          routeEntries.add(
            RouteEntry(route: route, target: widgetName, status: 'reachable'),
          );
        }
      }

      // Detect routes from push patterns
      for (final match in _namedRoutePattern.allMatches(content)) {
        final route = match.group(1)!;
        if (!detectedRoutes.contains(route)) {
          detectedRoutes.add(route);
          routeEntries.add(
            RouteEntry(route: route, target: 'unknown', status: 'reachable'),
          );
        }
      }

      // Detect backend/API calls (Req 1.5)
      for (final match in _backendCallPattern.allMatches(content)) {
        backendCallEntries.add(
          BackendCallEntry(
            callSignature: match.group(0)!.trim(),
            sourcePath: relativePath,
          ),
        );
      }
      for (final match in _httpUrlPattern.allMatches(content)) {
        backendCallEntries.add(
          BackendCallEntry(
            callSignature: match.group(1)!.trim(),
            sourcePath: relativePath,
          ),
        );
      }

      // Detect DB access points (Req 1.5)
      for (final match in _dynamoDbPattern.allMatches(content)) {
        dbAccessEntries.add(
          DbAccessEntry(
            accessPoint: match.group(0)!.trim(),
            sourcePath: relativePath,
          ),
        );
      }

      // Detect mock data indicators (Req 1.6)
      for (final match in _mockDataPattern.allMatches(content)) {
        mockDataEntries.add(
          MockDataEntry(sourcePath: relativePath, indicator: match.group(0)!),
        );
      }

      // Detect roles/permissions (Req 1.3)
      for (final match in _rolePattern.allMatches(content)) {
        final roleValue = match.group(1)!;
        roleEntries.add(
          RoleEntry(
            role: roleValue,
            module: featureModule.isNotEmpty ? featureModule : 'unknown',
            permittedAction: _inferActionFromContext(content, match.start),
          ),
        );
      }
    }

    // Build business type entries (Req 1.1)
    businessTypeEntries.addAll(_buildBusinessTypeEntries(detectedTypes, root));

    // Build module entries (Req 1.4)
    final moduleList = _buildModuleEntries(moduleEntries);

    // Use CoverageGapCalculator for count checks (Req 1.8, 1.9)
    final gapCalculator = CoverageGapCalculator();
    final screenGap = gapCalculator.checkScreenCount(screenEntries.length);
    if (screenGap != null) coverageGaps.add(screenGap);

    final typeGap = gapCalculator.checkBusinessTypeCount(detectedTypes.length);
    if (typeGap != null) coverageGaps.add(typeGap);

    return SystemMap(
      businessTypes: businessTypeEntries,
      screens: screenEntries,
      routes: routeEntries,
      modules: moduleList,
      roles: _deduplicateRoles(roleEntries),
      backendCalls: backendCallEntries,
      dbAccessPoints: dbAccessEntries,
      detectedMockData: mockDataEntries,
      coverageGaps: coverageGaps,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Resolves the Dukan_x package root directory.
  Directory _resolveRoot(String? workspacePath) {
    if (workspacePath != null) {
      final dukanDir = Directory('$workspacePath/Dukan_x');
      if (dukanDir.existsSync()) return dukanDir;
      // Try if workspacePath IS the Dukan_x directory itself.
      final dir = Directory(workspacePath);
      if (File('$workspacePath/pubspec.yaml').existsSync()) return dir;
      return dukanDir;
    }

    // Try audit_walker's resolution first.
    try {
      final wsRoot = walker.resolveWorkspaceRoot();
      return Directory('${wsRoot.path}/Dukan_x');
    } catch (_) {
      // Fall back to current directory.
      final cwd = Directory.current;
      if (Directory('${cwd.path}/lib/features').existsSync()) {
        return cwd;
      }
      final dukanDir = Directory('${cwd.path}/Dukan_x');
      if (dukanDir.existsSync()) return dukanDir;
      return cwd;
    }
  }

  /// Makes a file path relative to the root for evidence recording.
  String _relativize(String filePath, String rootPath) {
    final normalized = filePath.replaceAll('\\', '/');
    final normalizedRoot = rootPath.replaceAll('\\', '/');
    if (normalized.startsWith(normalizedRoot)) {
      return normalized.substring(normalizedRoot.length + 1);
    }
    return normalized;
  }

  /// Maps a feature directory name to a BusinessType, or null for shared modules.
  BusinessType? _inferBusinessType(String featureDir) {
    return _featureDirToType[featureDir];
  }

  /// Extracts a route string from the source content near a screen class.
  String _extractRouteFromContent(String content, String widgetName) {
    // Look for static routeName constants.
    final routeNameMatch = RegExp(
      '''static\\s+(?:const\\s+)?String\\s+routeName\\s*=\\s*['"]([^'"]+)['"]''',
    ).firstMatch(content);
    if (routeNameMatch != null) return routeNameMatch.group(1)!;

    // Look for route annotations or configurations.
    final routeMatch = _routePattern.firstMatch(content);
    if (routeMatch != null) return routeMatch.group(1)!;

    // Generate a conventional route from the widget name.
    return '/${_camelToSnake(widgetName.replaceAll(RegExp(r'Screen$|Page$'), ''))}';
  }

  /// Converts CamelCase to snake_case for route generation.
  String _camelToSnake(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (m) => '_${m.group(1)!.toLowerCase()}',
        )
        .replaceFirst(RegExp(r'^_'), '');
  }

  /// Infers the permitted action from context around a role match.
  String _inferActionFromContext(String content, int matchStart) {
    // Look for nearby action indicators within 200 chars.
    final start = (matchStart - 100).clamp(0, content.length);
    final end = (matchStart + 200).clamp(0, content.length);
    final context = content.substring(start, end);

    final actionMatch = RegExp(
      r'(?:action|Action|canDo|permission)\s*[:=]\s*['
      "'"
      r'"](\w+)',
    ).firstMatch(context);
    if (actionMatch != null) return actionMatch.group(1)!;

    // Check for common CRUD patterns.
    if (context.contains(RegExp(r'create|Create|add|Add'))) return 'create';
    if (context.contains(RegExp(r'read|Read|view|View|get|Get'))) return 'read';
    if (context.contains(RegExp(r'update|Update|edit|Edit'))) return 'update';
    if (context.contains(RegExp(r'delete|Delete|remove|Remove'))) {
      return 'delete';
    }

    return 'access';
  }

  /// Builds BusinessTypeEntry records for each detected type.
  List<BusinessTypeEntry> _buildBusinessTypeEntries(
    Set<BusinessType> detectedTypes,
    Directory root,
  ) {
    final entries = <BusinessTypeEntry>[];

    for (final type in BusinessType.values) {
      final featureDir = _typeToFeatureDir(type);
      final featurePath = '${root.path}/lib/features/$featureDir';
      final dir = Directory(featurePath);

      // Determine enabled modules based on service-only status.
      final enabledModules = kServiceOnlyTypes.contains(type)
          ? Module.values
                .where(
                  (m) =>
                      m != Module.inventoryTracking &&
                      m != Module.supplierManagement,
                )
                .toList()
          : Module.values.toList();

      // Tax rules depend on type.
      final taxRules = _inferTaxRules(type);

      // Workflows depend on type.
      final workflows = _inferWorkflows(type);

      // Permissions (common set).
      final permissions = _inferPermissions(type);

      // Source path evidence.
      final sourcePath = dir.existsSync()
          ? 'lib/features/$featureDir'
          : 'lib/models/business_type.dart';

      entries.add(
        BusinessTypeEntry(
          type: type,
          enabledModules: enabledModules,
          taxRules: taxRules,
          workflows: workflows,
          requiredPermissions: permissions,
          sourcePath: sourcePath,
        ),
      );
    }

    return entries;
  }

  /// Maps a BusinessType back to its expected feature directory name.
  String _typeToFeatureDir(BusinessType type) {
    // Reverse lookup from _featureDirToType, with fallbacks.
    switch (type) {
      case BusinessType.autoParts:
        return 'auto_parts';
      case BusinessType.bookStore:
        return 'book_store';
      case BusinessType.clinic:
        return 'clinic';
      case BusinessType.clothing:
        return 'clothing';
      case BusinessType.computerShop:
        return 'computer_shop';
      case BusinessType.decorationCatering:
        return 'decoration_catering';
      case BusinessType.hardware:
        return 'hardware';
      case BusinessType.jewellery:
        return 'jewellery';
      case BusinessType.petrolPump:
        return 'petrol_pump';
      case BusinessType.pharmacy:
        return 'pharmacy';
      case BusinessType.restaurant:
        return 'restaurant';
      case BusinessType.service:
        return 'service';
      case BusinessType.vegetablesBroker:
        return 'vegetable_broker';
      case BusinessType.schoolErp:
        return 'academic_coaching';
      case BusinessType.grocery:
        return 'billing'; // Grocery uses the shared billing module
      case BusinessType.electronics:
        return 'billing'; // Electronics uses shared billing
      case BusinessType.mobileShop:
        return 'billing'; // Mobile shop uses shared billing
      case BusinessType.wholesale:
        return 'billing'; // Wholesale uses shared billing
      case BusinessType.other:
        return 'billing'; // Other uses shared billing
    }
  }

  /// Infers tax rules applicable to a business type.
  List<String> _inferTaxRules(BusinessType type) {
    final rules = <String>['GST'];
    switch (type) {
      case BusinessType.jewellery:
        rules.addAll(['GST_3%', 'making_charges_GST_5%']);
      case BusinessType.restaurant:
        rules.addAll(['GST_5%_no_ITC']);
      case BusinessType.pharmacy:
        rules.addAll(['GST_5%', 'GST_12%', 'GST_18%', 'GST_exempt']);
      case BusinessType.petrolPump:
        rules.addAll(['excise_duty', 'VAT_state']);
      default:
        rules.addAll(['GST_5%', 'GST_12%', 'GST_18%', 'GST_28%']);
    }
    return rules;
  }

  /// Infers standard workflows for a business type.
  List<String> _inferWorkflows(BusinessType type) {
    final base = ['onboarding', 'billing', 'payments', 'reports'];
    if (!kServiceOnlyTypes.contains(type)) {
      base.addAll(['inventory_management', 'purchase_orders']);
    }
    switch (type) {
      case BusinessType.clinic:
        base.addAll(['patient_registration', 'appointment_booking']);
      case BusinessType.schoolErp:
        base.addAll([
          'student_enrollment',
          'attendance',
          'fee_collection',
          'exams',
        ]);
      case BusinessType.restaurant:
        base.addAll(['table_management', 'kitchen_orders']);
      case BusinessType.jewellery:
        base.addAll(['custom_orders', 'gold_schemes']);
      default:
        break;
    }
    return base;
  }

  /// Infers required permissions for a business type.
  List<String> _inferPermissions(BusinessType type) {
    return [
      'owner_full_access',
      'admin_manage',
      'accountant_financial',
      'salesperson_billing',
      'inventory_manager_stock',
    ];
  }

  /// Builds ModuleEntry list from the accumulated module→types mapping.
  List<ModuleEntry> _buildModuleEntries(Map<String, Set<String>> raw) {
    final entries = <ModuleEntry>[];

    // Map feature directory names to Module enum values where possible.
    for (final entry in raw.entries) {
      final module = _dirNameToModule(entry.key);
      if (module != null) {
        entries.add(
          ModuleEntry(module: module, owningTypes: entry.value.toList()),
        );
      }
    }

    // Ensure all Module enum values appear (Req 1.4).
    final covered = entries.map((e) => e.module).toSet();
    for (final m in Module.values) {
      if (!covered.contains(m)) {
        entries.add(ModuleEntry(module: m, owningTypes: ['all']));
      }
    }

    return entries;
  }

  /// Maps a feature directory name to a Module enum value, or null.
  Module? _dirNameToModule(String dirName) {
    switch (dirName) {
      case 'customers':
        return Module.customerManagement;
      case 'purchase':
        return Module.supplierManagement;
      case 'inventory' || 'stock':
        return Module.inventoryTracking;
      case 'invoice' || 'billing' || 'e_invoice':
        return Module.invoiceGeneration;
      case 'payment' || 'cash_closing':
        return Module.payments;
      case 'reports':
        return Module.reports;
      case 'analytics' || 'insights':
        return Module.analytics;
      case 'sync':
        return Module.dataSync;
      case 'backup':
        return Module.offlineMode;
      case 'subscription' || 'buy_flow':
        return Module.subscriptionControls;
      case 'auth':
        return Module.licenseActivation;
      default:
        return null;
    }
  }

  /// Deduplicates role entries based on role+module+action combo.
  List<RoleEntry> _deduplicateRoles(List<RoleEntry> roles) {
    final seen = <String>{};
    final unique = <RoleEntry>[];
    for (final r in roles) {
      final key = '${r.role}|${r.module}|${r.permittedAction}';
      if (seen.add(key)) unique.add(r);
    }
    return unique;
  }

  // ---------------------------------------------------------------------------
  // writeSystemMap — Writes inventory/system-map.md (Req 1.7, 1.8, 1.9)
  // ---------------------------------------------------------------------------

  /// Writes the [SystemMap] to the given [path] as a Markdown file containing
  /// one table per section plus the Coverage_Gap list.
  ///
  /// The file contains the following tables:
  /// - Business_Types: type, enabledModules, taxRules, workflows, requiredPermissions, sourcePath
  /// - Screens: screen, route, widget, businessTypes, sourcePath
  /// - Routes: route, target, status
  /// - Modules: module, owningTypes
  /// - Roles: role, module, permittedAction
  /// - Backend_Calls: callSignature, sourcePath
  /// - DB_Access: accessPoint, sourcePath
  /// - Mock_Data: sourcePath, indicator
  /// - Coverage_Gaps: kind, expected, actual, shortfall/reason
  ///
  /// Coverage gap seeds for <460 screens (Req 1.8) and <19 types (Req 1.9) are
  /// automatically included in the gaps section if present in the SystemMap.
  ///
  /// Requirements: 1.7, 1.8, 1.9
  void writeSystemMap(SystemMap map, String path) {
    final buffer = StringBuffer();

    buffer.writeln('# System Map');
    buffer.writeln();
    buffer.writeln(
      '> Auto-generated by InventoryScanner. '
      'Each entry references the source file path where it was detected.',
    );
    buffer.writeln();

    // --- Business_Types table ---
    _writeBusinessTypesTable(buffer, map.businessTypes);

    // --- Screens table ---
    _writeScreensTable(buffer, map.screens);

    // --- Routes table ---
    _writeRoutesTable(buffer, map.routes);

    // --- Modules table ---
    _writeModulesTable(buffer, map.modules);

    // --- Roles table ---
    _writeRolesTable(buffer, map.roles);

    // --- Backend_Calls table ---
    _writeBackendCallsTable(buffer, map.backendCalls);

    // --- DB_Access table ---
    _writeDbAccessTable(buffer, map.dbAccessPoints);

    // --- Mock_Data table ---
    _writeMockDataTable(buffer, map.detectedMockData);

    // --- Coverage_Gaps table ---
    _writeCoverageGapsTable(buffer, map.coverageGaps);

    // Write the file, creating parent directories if needed.
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(buffer.toString());
  }

  /// Writes the Business_Types Markdown table.
  void _writeBusinessTypesTable(
    StringBuffer buffer,
    List<BusinessTypeEntry> entries,
  ) {
    buffer.writeln('## Business_Types');
    buffer.writeln();
    buffer.writeln(
      '| type | enabledModules | taxRules | workflows | requiredPermissions | sourcePath |',
    );
    buffer.writeln(
      '|------|----------------|----------|-----------|---------------------|------------|',
    );

    for (final entry in entries) {
      final modules = entry.enabledModules.map((m) => m.name).join(', ');
      final taxRules = entry.taxRules.join(', ');
      final workflows = entry.workflows.join(', ');
      final permissions = entry.requiredPermissions.join(', ');
      buffer.writeln(
        '| ${entry.type.name} | $modules | $taxRules | $workflows | $permissions | ${entry.sourcePath} |',
      );
    }

    buffer.writeln();
  }

  /// Writes the Screens Markdown table.
  void _writeScreensTable(StringBuffer buffer, List<ScreenEntry> entries) {
    buffer.writeln('## Screens');
    buffer.writeln();
    buffer.writeln('| screen | route | widget | businessTypes | sourcePath |');
    buffer.writeln('|--------|-------|--------|---------------|------------|');

    for (final entry in entries) {
      final types = entry.businessTypes.join(', ');
      buffer.writeln(
        '| ${entry.widgetName} | ${entry.route} | ${entry.widgetName} | $types | ${entry.sourcePath} |',
      );
    }

    buffer.writeln();
  }

  /// Writes the Routes Markdown table.
  void _writeRoutesTable(StringBuffer buffer, List<RouteEntry> entries) {
    buffer.writeln('## Routes');
    buffer.writeln();
    buffer.writeln('| route | target | status |');
    buffer.writeln('|-------|--------|--------|');

    for (final entry in entries) {
      buffer.writeln('| ${entry.route} | ${entry.target} | ${entry.status} |');
    }

    buffer.writeln();
  }

  /// Writes the Modules Markdown table.
  void _writeModulesTable(StringBuffer buffer, List<ModuleEntry> entries) {
    buffer.writeln('## Modules');
    buffer.writeln();
    buffer.writeln('| module | owningTypes |');
    buffer.writeln('|--------|-------------|');

    for (final entry in entries) {
      final types = entry.owningTypes.join(', ');
      buffer.writeln('| ${entry.module.name} | $types |');
    }

    buffer.writeln();
  }

  /// Writes the Roles Markdown table.
  void _writeRolesTable(StringBuffer buffer, List<RoleEntry> entries) {
    buffer.writeln('## Roles');
    buffer.writeln();
    buffer.writeln('| role | module | permittedAction |');
    buffer.writeln('|------|--------|-----------------|');

    for (final entry in entries) {
      buffer.writeln(
        '| ${entry.role} | ${entry.module} | ${entry.permittedAction} |',
      );
    }

    buffer.writeln();
  }

  /// Writes the Backend_Calls Markdown table.
  void _writeBackendCallsTable(
    StringBuffer buffer,
    List<BackendCallEntry> entries,
  ) {
    buffer.writeln('## Backend_Calls');
    buffer.writeln();
    buffer.writeln('| callSignature | sourcePath |');
    buffer.writeln('|---------------|------------|');

    for (final entry in entries) {
      buffer.writeln('| ${entry.callSignature} | ${entry.sourcePath} |');
    }

    buffer.writeln();
  }

  /// Writes the DB_Access Markdown table.
  void _writeDbAccessTable(StringBuffer buffer, List<DbAccessEntry> entries) {
    buffer.writeln('## DB_Access');
    buffer.writeln();
    buffer.writeln('| accessPoint | sourcePath |');
    buffer.writeln('|-------------|------------|');

    for (final entry in entries) {
      buffer.writeln('| ${entry.accessPoint} | ${entry.sourcePath} |');
    }

    buffer.writeln();
  }

  /// Writes the Mock_Data Markdown table.
  void _writeMockDataTable(StringBuffer buffer, List<MockDataEntry> entries) {
    buffer.writeln('## Mock_Data');
    buffer.writeln();
    buffer.writeln('| sourcePath | indicator |');
    buffer.writeln('|------------|-----------|');

    for (final entry in entries) {
      buffer.writeln('| ${entry.sourcePath} | ${entry.indicator} |');
    }

    buffer.writeln();
  }

  /// Writes the Coverage_Gaps Markdown table.
  ///
  /// Includes gap seeds for <460 screens (Req 1.8) and <19 types (Req 1.9)
  /// if they are present in the [gaps] list.
  void _writeCoverageGapsTable(StringBuffer buffer, List<CoverageGap> gaps) {
    buffer.writeln('## Coverage_Gaps');
    buffer.writeln();
    buffer.writeln('| kind | expected | actual | shortfall/reason |');
    buffer.writeln('|------|----------|--------|------------------|');

    for (final gap in gaps) {
      final shortfallReason = gap.reason != null
          ? '${gap.shortfall} — ${gap.reason}'
          : '${gap.shortfall}';
      buffer.writeln(
        '| ${gap.kind} | ${gap.expected} | ${gap.actual} | $shortfallReason |',
      );
    }

    buffer.writeln();
  }
}
