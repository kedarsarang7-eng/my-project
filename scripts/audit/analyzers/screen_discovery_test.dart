/// Unit tests for ScreenDiscoveryEngine.detectMockData()
///
/// Verifies all 4 mock data detection categories:
/// 1. Hardcoded sample data arrays with 2+ literal entries
/// 2. TODO/placeholder comments indicating fake data
/// 3. Imports from paths containing "mock"/"dummy"/"fake"/"sample"
/// 4. Conditional logic returning inline literal data without API calls
///
/// Requirements: 6.1
library;

import 'screen_discovery.dart';

void main() {
  print('=== ScreenDiscoveryEngine.detectMockData() Unit Tests ===\n');

  final engine = ScreenDiscoveryEngine();

  _testNoMockData(engine);
  _testHardcodedArrayObjects(engine);
  _testHardcodedArrayStringSingleQuotes(engine);
  _testHardcodedArrayStringDoubleQuotes(engine);
  _testTodoPlaceholderComments(engine);
  _testFixmeMockComment(engine);
  _testHackSampleComment(engine);
  _testPlainPlaceholderComment(engine);
  _testDummyDataComment(engine);
  _testSampleDataComment(engine);
  _testMockImport(engine);
  _testDummyImport(engine);
  _testFakeImport(engine);
  _testSampleImport(engine);
  _testMocksDirectoryImport(engine);
  _testMockPrefixImport(engine);
  _testFakePrefixImport(engine);
  _testInlineLiteralReturnArray(engine);
  _testInlineLiteralReturnStringArray(engine);
  _testInlineLiteralFinalAssignment(engine);
  _testMultiplePatterns(engine);
  _testAllFourPatterns(engine);
  _testRealCodeNotFlagged(engine);
  _testCommasSeparatedReasons(engine);

  print('\n✓ All detectMockData() tests passed.');
}

// ─── No Mock Data ───────────────────────────────────────────────────────────

void _testNoMockData(ScreenDiscoveryEngine engine) {
  print('Test: Clean file with no mock data patterns...');

  const content = '''
import 'package:flutter/material.dart';
import '../repositories/product_repository.dart';

class ProductScreen extends StatefulWidget {
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final _repository = ProductRepository();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await _repository.getProducts();
    setState(() => _products = products);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Products')),
      body: ListView.builder(
        itemCount: _products.length,
        itemBuilder: (ctx, i) => ListTile(title: Text(_products[i].name)),
      ),
    );
  }
}
''';

  final result = engine.detectMockData(content);
  assert(!result.hasMockData, 'Clean code should not be flagged as mock data');
  assert(result.mockReasons.isEmpty, 'Should have empty reasons');
  print('  ✓ No false positive on clean code');
}

// ─── Category 1: Hardcoded Arrays ───────────────────────────────────────────

void _testHardcodedArrayObjects(ScreenDiscoveryEngine engine) {
  print('Test: Hardcoded array of objects [{...}, {...}]...');

  const content = '''
class MenuScreen extends StatelessWidget {
  final items = [
    {'name': 'Pizza', 'price': 299},
    {'name': 'Burger', 'price': 199},
    {'name': 'Pasta', 'price': 249},
  ];
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'Hardcoded object array should be detected');
  assert(
    result.mockReasons.contains('hardcoded_array'),
    'Should contain hardcoded_array reason, got: ${result.mockReasons}',
  );
  print('  ✓ Detected hardcoded object array');
}

void _testHardcodedArrayStringSingleQuotes(ScreenDiscoveryEngine engine) {
  print("Test: Hardcoded array of strings (single quotes)...");

  const content = '''
class CategoryScreen extends StatelessWidget {
  final categories = ['Electronics', 'Clothing', 'Food'];
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'Hardcoded string array should be detected');
  assert(
    result.mockReasons.contains('hardcoded_array'),
    'Should contain hardcoded_array reason',
  );
  print('  ✓ Detected hardcoded string array (single quotes)');
}

void _testHardcodedArrayStringDoubleQuotes(ScreenDiscoveryEngine engine) {
  print('Test: Hardcoded array of strings (double quotes)...');

  const content = '''
class TagScreen extends StatelessWidget {
  final tags = ["urgent", "pending", "completed"];
}
''';

  final result = engine.detectMockData(content);
  assert(
    result.hasMockData,
    'Hardcoded double-quoted array should be detected',
  );
  assert(
    result.mockReasons.contains('hardcoded_array'),
    'Should contain hardcoded_array reason',
  );
  print('  ✓ Detected hardcoded string array (double quotes)');
}

// ─── Category 2: TODO/Placeholder Comments ──────────────────────────────────

void _testTodoPlaceholderComments(ScreenDiscoveryEngine engine) {
  print('Test: TODO comment with mock keyword...');

  const content = '''
class DashboardScreen extends StatelessWidget {
  // TODO: Replace fake data with real API call
  final data = getStaticData();
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'TODO with fake keyword should be detected');
  assert(
    result.mockReasons.contains('todo_placeholder'),
    'Should contain todo_placeholder reason, got: ${result.mockReasons}',
  );
  print('  ✓ Detected TODO with fake keyword');
}

void _testFixmeMockComment(ScreenDiscoveryEngine engine) {
  print('Test: FIXME comment with mock keyword...');

  const content = '''
class OrderScreen extends StatefulWidget {
  // FIXME: remove mock data before release
  List<Order> _orders = [];
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'FIXME with mock keyword should be detected');
  assert(
    result.mockReasons.contains('todo_placeholder'),
    'Should contain todo_placeholder reason',
  );
  print('  ✓ Detected FIXME with mock keyword');
}

void _testHackSampleComment(ScreenDiscoveryEngine engine) {
  print('Test: HACK comment with sample keyword...');

  const content = '''
class ReportScreen extends StatelessWidget {
  // HACK using sample data for now
  Widget build(BuildContext context) => Container();
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'HACK with sample keyword should be detected');
  assert(
    result.mockReasons.contains('todo_placeholder'),
    'Should contain todo_placeholder reason',
  );
  print('  ✓ Detected HACK with sample keyword');
}

void _testPlainPlaceholderComment(ScreenDiscoveryEngine engine) {
  print('Test: Plain // placeholder comment...');

  const content = '''
class ItemScreen extends StatelessWidget {
  // placeholder
  final items = <String>[];
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'Plain placeholder comment should be detected');
  assert(
    result.mockReasons.contains('todo_placeholder'),
    'Should contain todo_placeholder reason',
  );
  print('  ✓ Detected plain placeholder comment');
}

void _testDummyDataComment(ScreenDiscoveryEngine engine) {
  print('Test: // dummy data comment...');

  const content = '''
class StockScreen extends StatelessWidget {
  // dummy data
  final stock = <Map<String, dynamic>>[];
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'Dummy data comment should be detected');
  assert(
    result.mockReasons.contains('todo_placeholder'),
    'Should contain todo_placeholder reason',
  );
  print('  ✓ Detected dummy data comment');
}

void _testSampleDataComment(ScreenDiscoveryEngine engine) {
  print('Test: // sample data comment...');

  const content = '''
class InvoiceScreen extends StatelessWidget {
  // sample data
  final invoices = <Invoice>[];
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'Sample data comment should be detected');
  assert(
    result.mockReasons.contains('todo_placeholder'),
    'Should contain todo_placeholder reason',
  );
  print('  ✓ Detected sample data comment');
}

// ─── Category 3: Mock/Fake/Dummy/Sample Imports ─────────────────────────────

void _testMockImport(ScreenDiscoveryEngine engine) {
  print('Test: Import from path containing "mock"...');

  const content = '''
import '../data/mock_products.dart';

class ProductListScreen extends StatelessWidget {
  Widget build(BuildContext context) => Container();
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'Mock import should be detected');
  assert(
    result.mockReasons.contains('mock_import'),
    'Should contain mock_import reason, got: ${result.mockReasons}',
  );
  print('  ✓ Detected mock import');
}

void _testDummyImport(ScreenDiscoveryEngine engine) {
  print('Test: Import from path containing "dummy"...');

  const content = '''
import 'package:app/data/dummy_orders.dart';

class OrderListScreen extends StatelessWidget {
  Widget build(BuildContext context) => Container();
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'Dummy import should be detected');
  assert(
    result.mockReasons.contains('mock_import'),
    'Should contain mock_import reason',
  );
  print('  ✓ Detected dummy import');
}

void _testFakeImport(ScreenDiscoveryEngine engine) {
  print('Test: Import from path containing "fake"...');

  const content = '''
import '../services/fake_api_service.dart';

class ServiceScreen extends StatelessWidget {
  Widget build(BuildContext context) => Container();
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'Fake import should be detected');
  assert(
    result.mockReasons.contains('mock_import'),
    'Should contain mock_import reason',
  );
  print('  ✓ Detected fake import');
}

void _testSampleImport(ScreenDiscoveryEngine engine) {
  print('Test: Import from path containing "sample"...');

  const content = '''
import 'package:dukan_x/data/sample_inventory.dart';

class InventoryScreen extends StatefulWidget {
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'Sample import should be detected');
  assert(
    result.mockReasons.contains('mock_import'),
    'Should contain mock_import reason',
  );
  print('  ✓ Detected sample import');
}

void _testMocksDirectoryImport(ScreenDiscoveryEngine engine) {
  print('Test: Import from /mocks/ directory...');

  const content = '''
import '../mocks/user_data.dart';

class UserScreen extends StatelessWidget {
  Widget build(BuildContext context) => Container();
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'Mocks directory import should be detected');
  assert(
    result.mockReasons.contains('mock_import'),
    'Should contain mock_import reason',
  );
  print('  ✓ Detected /mocks/ directory import');
}

void _testMockPrefixImport(ScreenDiscoveryEngine engine) {
  print('Test: Import from /mock_* path...');

  const content = '''
import '../data/mock_restaurant_menu.dart';

class MenuScreen extends StatelessWidget {
  Widget build(BuildContext context) => Container();
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'mock_ prefix import should be detected');
  assert(
    result.mockReasons.contains('mock_import'),
    'Should contain mock_import reason',
  );
  print('  ✓ Detected mock_ prefix import');
}

void _testFakePrefixImport(ScreenDiscoveryEngine engine) {
  print('Test: Import from /fake_* path...');

  const content = '''
import '../services/fake_payment_gateway.dart';

class PaymentScreen extends StatelessWidget {
  Widget build(BuildContext context) => Container();
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'fake_ prefix import should be detected');
  assert(
    result.mockReasons.contains('mock_import'),
    'Should contain mock_import reason',
  );
  print('  ✓ Detected fake_ prefix import');
}

// ─── Category 4: Inline Literal Returns ─────────────────────────────────────

void _testInlineLiteralReturnArray(ScreenDiscoveryEngine engine) {
  print('Test: return [{...}] inline literal...');

  const content = '''
class DataProvider {
  List<Map<String, dynamic>> getItems() {
    return [{'id': 1, 'name': 'Test Item'}];
  }
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'Inline literal return should be detected');
  assert(
    result.mockReasons.contains('inline_literal'),
    'Should contain inline_literal reason, got: ${result.mockReasons}',
  );
  print('  ✓ Detected return [{...}] inline literal');
}

void _testInlineLiteralReturnStringArray(ScreenDiscoveryEngine engine) {
  print("Test: return ['...'] inline literal...");

  const content = '''
class TagProvider {
  List<String> getTags() {
    return ['tag1', 'tag2', 'tag3'];
  }
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'Inline string return should be detected');
  assert(
    result.mockReasons.contains('inline_literal'),
    'Should contain inline_literal reason',
  );
  print("  ✓ Detected return ['...'] inline literal");
}

void _testInlineLiteralFinalAssignment(ScreenDiscoveryEngine engine) {
  print('Test: final x = [{...}, {...}] assignment...');

  const content = '''
class OrderScreen extends StatelessWidget {
  final orders = [{'id': 1, 'total': 500}, {'id': 2, 'total': 750}];
}
''';

  final result = engine.detectMockData(content);
  assert(
    result.hasMockData,
    'Final assignment with literal array should be detected',
  );
  // This should trigger hardcoded_array and/or inline_literal
  assert(
    result.mockReasons.contains('hardcoded_array') ||
        result.mockReasons.contains('inline_literal'),
    'Should contain hardcoded_array or inline_literal reason, got: ${result.mockReasons}',
  );
  print('  ✓ Detected final assignment with inline literal array');
}

// ─── Multiple Patterns ──────────────────────────────────────────────────────

void _testMultiplePatterns(ScreenDiscoveryEngine engine) {
  print('Test: Multiple mock patterns in same file...');

  const content = '''
import '../mocks/sample_data.dart';

class DemoScreen extends StatelessWidget {
  // TODO: replace with real API call using placeholder data
  final items = [
    {'name': 'Item 1', 'price': 100},
    {'name': 'Item 2', 'price': 200},
  ];
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'Multiple patterns should be detected');

  // Should detect mock_import + todo_placeholder + hardcoded_array
  final reasons = result.mockReasons.split(',');
  assert(reasons.contains('hardcoded_array'), 'Should contain hardcoded_array');
  assert(
    reasons.contains('todo_placeholder'),
    'Should contain todo_placeholder',
  );
  assert(reasons.contains('mock_import'), 'Should contain mock_import');
  print('  ✓ Detected multiple patterns: ${result.mockReasons}');
}

void _testAllFourPatterns(ScreenDiscoveryEngine engine) {
  print('Test: All four detection categories in one file...');

  const content = '''
import '../data/fake_inventory.dart';

class InventoryScreen extends StatelessWidget {
  // TODO: connect to real mock service
  
  List<Map<String, dynamic>> getItems() {
    return [{'id': 1, 'name': 'Sample'}];
  }
  
  final categories = [
    {'id': 'cat1', 'name': 'Category 1'},
    {'id': 'cat2', 'name': 'Category 2'},
  ];
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'All four patterns should be detected');

  final reasons = result.mockReasons.split(',');
  assert(reasons.contains('hardcoded_array'), 'Should contain hardcoded_array');
  assert(
    reasons.contains('todo_placeholder'),
    'Should contain todo_placeholder',
  );
  assert(reasons.contains('mock_import'), 'Should contain mock_import');
  assert(reasons.contains('inline_literal'), 'Should contain inline_literal');
  assert(
    reasons.length == 4,
    'Should have exactly 4 reasons, got: ${reasons.length}',
  );
  print('  ✓ All four categories detected: ${result.mockReasons}');
}

// ─── No False Positives ─────────────────────────────────────────────────────

void _testRealCodeNotFlagged(ScreenDiscoveryEngine engine) {
  print('Test: Real production code not flagged...');

  const content = '''
import 'package:flutter/material.dart';
import '../repositories/order_repository.dart';
import '../models/order.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _repository = OrderRepository();
  List<Order> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _loading = true);
    try {
      final orders = await _repository.fetchOrders();
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load orders')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const CircularProgressIndicator();
    return ListView.builder(
      itemCount: _orders.length,
      itemBuilder: (ctx, i) => OrderTile(order: _orders[i]),
    );
  }
}
''';

  final result = engine.detectMockData(content);
  assert(!result.hasMockData, 'Real production code should not be flagged');
  assert(result.mockReasons.isEmpty, 'Reasons should be empty for real code');
  print('  ✓ No false positive on real production code');
}

// ─── Comma-Separated Reasons Format ─────────────────────────────────────────

void _testCommasSeparatedReasons(ScreenDiscoveryEngine engine) {
  print('Test: MockReasons is comma-separated without spaces...');

  const content = '''
import '../mocks/data.dart';
// TODO: remove dummy data
class TestScreen extends StatelessWidget {
  Widget build(BuildContext context) => Container();
}
''';

  final result = engine.detectMockData(content);
  assert(result.hasMockData, 'Should detect mock patterns');

  // Verify comma-separated format (no spaces around commas)
  final reasons = result.mockReasons;
  assert(!reasons.contains(', '), 'Should not have space after comma');
  assert(!reasons.startsWith(','), 'Should not start with comma');
  assert(!reasons.endsWith(','), 'Should not end with comma');

  final parts = reasons.split(',');
  assert(parts.length >= 2, 'Should have at least 2 reasons');
  for (final part in parts) {
    assert(part.isNotEmpty, 'No empty segments between commas');
    assert(part == part.trim(), 'No leading/trailing spaces in segments');
  }
  print('  ✓ MockReasons format is correct: $reasons');
}
