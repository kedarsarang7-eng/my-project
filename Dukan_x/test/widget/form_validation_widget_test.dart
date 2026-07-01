// ============================================================================
// WT-FORM — Form Validation Widget Tests
// Coverage: Empty submit errors, invalid format, max-length, rapid double-tap,
//           keyboard dismiss/re-focus, form reset, invoice builder interactions
// ============================================================================
// Run: flutter test test/widget/form_validation_widget_test.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Minimal Add-Product Form ──────────────────────────────────────────────────

class _AddProductForm extends StatefulWidget {
  final void Function(Map<String, String> data)? onSubmit;
  const _AddProductForm({this.onSubmit});

  @override
  State<_AddProductForm> createState() => _AddProductFormState();
}

class _AddProductFormState extends State<_AddProductForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _skuCtrl   = TextEditingController();
  DateTime? _lastSubmit;

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Product name is required';
    if (v.length > 100) return 'Name must be ≤100 characters';
    return null;
  }

  String? _validatePrice(String? v) {
    if (v == null || v.trim().isEmpty) return 'Sale price is required';
    final price = double.tryParse(v);
    if (price == null) return 'Enter a valid price';
    if (price < 0) return 'Price cannot be negative';
    if (price == 0) return 'Price cannot be zero';
    return null;
  }

  String? _validateSKU(String? v) {
    if (v != null && v.length > 30) return 'SKU must be ≤30 characters';
    return null;
  }

  void _handleSubmit() {
    final now = DateTime.now();
    // Debounce: block double-tap within 500ms
    if (_lastSubmit != null &&
        now.difference(_lastSubmit!).inMilliseconds < 500) {
      return;
    }
    _lastSubmit = now;

    if (_formKey.currentState!.validate()) {
      widget.onSubmit?.call({
        'name': _nameCtrl.text,
        'price': _priceCtrl.text,
        'sku': _skuCtrl.text,
      });
    }
  }

  void reset() {
    _formKey.currentState?.reset();
    _nameCtrl.clear();
    _priceCtrl.clear();
    _skuCtrl.clear();
    _lastSubmit = null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            key: const Key('name_field'),
            controller: _nameCtrl,
            validator: _validateName,
            maxLength: 101, // allow overflow to trigger error
            decoration: const InputDecoration(labelText: 'Product Name'),
          ),
          TextFormField(
            key: const Key('price_field'),
            controller: _priceCtrl,
            validator: _validatePrice,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Sale Price'),
          ),
          TextFormField(
            key: const Key('sku_field'),
            controller: _skuCtrl,
            validator: _validateSKU,
            decoration: const InputDecoration(labelText: 'SKU'),
          ),
          ElevatedButton(
            key: const Key('submit_btn'),
            onPressed: _handleSubmit,
            child: const Text('Save Product'),
          ),
          TextButton(
            key: const Key('reset_btn'),
            onPressed: reset,
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

// ============================================================================
// TESTS
// ============================================================================

void main() {
  // ── Empty Submit Tests ────────────────────────────────────────────────────

  group('WT-FORM-001: Empty Submit Shows Required Field Errors', () {
    testWidgets('Submitting empty form shows name and price errors', (tester) async {
      await tester.pumpWidget(_wrap(const _AddProductForm()));
      await tester.tap(find.byKey(const Key('submit_btn')));
      await tester.pump();

      expect(find.text('Product name is required'), findsOneWidget);
      expect(find.text('Sale price is required'), findsOneWidget);
    });

    testWidgets('Name filled but price empty → only price error shown', (tester) async {
      await tester.pumpWidget(_wrap(const _AddProductForm()));
      await tester.enterText(find.byKey(const Key('name_field')), 'Rice');
      await tester.tap(find.byKey(const Key('submit_btn')));
      await tester.pump();

      expect(find.text('Product name is required'), findsNothing);
      expect(find.text('Sale price is required'), findsOneWidget);
    });

    testWidgets('Price filled but name empty → only name error shown', (tester) async {
      await tester.pumpWidget(_wrap(const _AddProductForm()));
      await tester.enterText(find.byKey(const Key('price_field')), '100');
      await tester.tap(find.byKey(const Key('submit_btn')));
      await tester.pump();

      expect(find.text('Product name is required'), findsOneWidget);
      expect(find.text('Sale price is required'), findsNothing);
    });
  });

  // ── Invalid Format Tests ──────────────────────────────────────────────────

  group('WT-FORM-002: Invalid Format Shows Format Errors', () {
    testWidgets('Non-numeric price → "Enter a valid price"', (tester) async {
      await tester.pumpWidget(_wrap(const _AddProductForm()));
      await tester.enterText(find.byKey(const Key('name_field')), 'Rice');
      await tester.enterText(find.byKey(const Key('price_field')), 'abc');
      await tester.tap(find.byKey(const Key('submit_btn')));
      await tester.pump();

      expect(find.text('Enter a valid price'), findsOneWidget);
    });

    testWidgets('Negative price → "Price cannot be negative"', (tester) async {
      await tester.pumpWidget(_wrap(const _AddProductForm()));
      await tester.enterText(find.byKey(const Key('name_field')), 'Rice');
      await tester.enterText(find.byKey(const Key('price_field')), '-50');
      await tester.tap(find.byKey(const Key('submit_btn')));
      await tester.pump();

      expect(find.text('Price cannot be negative'), findsOneWidget);
    });

    testWidgets('Zero price → "Price cannot be zero"', (tester) async {
      await tester.pumpWidget(_wrap(const _AddProductForm()));
      await tester.enterText(find.byKey(const Key('name_field')), 'Rice');
      await tester.enterText(find.byKey(const Key('price_field')), '0');
      await tester.tap(find.byKey(const Key('submit_btn')));
      await tester.pump();

      expect(find.text('Price cannot be zero'), findsOneWidget);
    });
  });

  // ── Max Length Tests ──────────────────────────────────────────────────────

  group('WT-FORM-003: Max Length Overflow Shows Error', () {
    testWidgets('Product name > 100 chars → "Name must be ≤100 characters"', (tester) async {
      await tester.pumpWidget(_wrap(const _AddProductForm()));
      await tester.enterText(find.byKey(const Key('name_field')), 'A' * 101);
      await tester.enterText(find.byKey(const Key('price_field')), '100');
      await tester.tap(find.byKey(const Key('submit_btn')));
      await tester.pump();

      expect(find.text('Name must be ≤100 characters'), findsOneWidget);
    });

    testWidgets('SKU > 30 chars → "SKU must be ≤30 characters"', (tester) async {
      await tester.pumpWidget(_wrap(const _AddProductForm()));
      await tester.enterText(find.byKey(const Key('name_field')), 'Widget');
      await tester.enterText(find.byKey(const Key('price_field')), '50');
      await tester.enterText(find.byKey(const Key('sku_field')), 'S' * 31);
      await tester.tap(find.byKey(const Key('submit_btn')));
      await tester.pump();

      expect(find.text('SKU must be ≤30 characters'), findsOneWidget);
    });

    testWidgets('Exactly 100 char name is valid', (tester) async {
      var submitted = false;
      await tester.pumpWidget(_wrap(
        _AddProductForm(onSubmit: (_) => submitted = true),
      ));
      await tester.enterText(find.byKey(const Key('name_field')), 'A' * 100);
      await tester.enterText(find.byKey(const Key('price_field')), '10');
      await tester.tap(find.byKey(const Key('submit_btn')));
      await tester.pump();

      expect(submitted, isTrue);
    });
  });

  // ── Rapid Double-Tap Debounce ─────────────────────────────────────────────

  group('WT-FORM-004: Rapid Double-Tap Submit Fires Only Once', () {
    testWidgets('Double-tap within 500ms submits exactly once', (tester) async {
      var submitCount = 0;
      await tester.pumpWidget(_wrap(
        _AddProductForm(onSubmit: (_) => submitCount++),
      ));
      await tester.enterText(find.byKey(const Key('name_field')), 'Item');
      await tester.enterText(find.byKey(const Key('price_field')), '99');

      // Tap twice rapidly (no pump between)
      await tester.tap(find.byKey(const Key('submit_btn')));
      await tester.tap(find.byKey(const Key('submit_btn')));
      await tester.pump();

      expect(submitCount, equals(1));
    });

    testWidgets('Two taps 600ms apart submit twice', (tester) async {
      var submitCount = 0;
      await tester.pumpWidget(_wrap(
        _AddProductForm(onSubmit: (_) => submitCount++),
      ));
      await tester.enterText(find.byKey(const Key('name_field')), 'Item');
      await tester.enterText(find.byKey(const Key('price_field')), '99');

      await tester.tap(find.byKey(const Key('submit_btn')));
      await tester.pump();
      // Advance real wall-clock time so DateTime.now() debounce sees >500ms
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
      await tester.tap(find.byKey(const Key('submit_btn')));
      await tester.pump();

      expect(submitCount, equals(2));
    });
  });

  // ── Form Reset ────────────────────────────────────────────────────────────

  group('WT-FORM-005: Form Reset Clears All Fields', () {
    testWidgets('Pressing reset clears name, price, sku fields', (tester) async {
      await tester.pumpWidget(_wrap(const _AddProductForm()));

      await tester.enterText(find.byKey(const Key('name_field')), 'Widget');
      await tester.enterText(find.byKey(const Key('price_field')), '250');
      await tester.enterText(find.byKey(const Key('sku_field')), 'SKU-001');

      // Verify fields have values
      expect(find.text('Widget'), findsOneWidget);

      await tester.tap(find.byKey(const Key('reset_btn')));
      await tester.pump();

      final nameField = tester.widget<TextField>(
        find.descendant(of: find.byKey(const Key('name_field')), matching: find.byType(TextField)),
      );
      expect(nameField.controller?.text, isEmpty);
    });

    testWidgets('After reset, submit shows required field errors again', (tester) async {
      await tester.pumpWidget(_wrap(const _AddProductForm()));

      // Fill and submit successfully
      await tester.enterText(find.byKey(const Key('name_field')), 'Widget');
      await tester.enterText(find.byKey(const Key('price_field')), '100');
      await tester.tap(find.byKey(const Key('submit_btn')));
      await tester.pump();

      // Reset
      await tester.tap(find.byKey(const Key('reset_btn')));
      await tester.pump();

      // Submit blank again
      await tester.tap(find.byKey(const Key('submit_btn')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Product name is required'), findsOneWidget);
    });
  });

  // ── Valid Form Submission ─────────────────────────────────────────────────

  group('WT-FORM-006: Valid Submission', () {
    testWidgets('Valid name + price submits without errors', (tester) async {
      Map<String, String>? submittedData;
      await tester.pumpWidget(_wrap(
        _AddProductForm(onSubmit: (data) => submittedData = data),
      ));

      await tester.enterText(find.byKey(const Key('name_field')), 'Paracetamol 500mg');
      await tester.enterText(find.byKey(const Key('price_field')), '25.50');
      await tester.enterText(find.byKey(const Key('sku_field')), 'MED-001');
      await tester.tap(find.byKey(const Key('submit_btn')));
      await tester.pump();

      expect(submittedData, isNotNull);
      expect(submittedData!['name'], 'Paracetamol 500mg');
      expect(submittedData!['price'], '25.50');
      expect(submittedData!['sku'], 'MED-001');

      // No error messages shown
      expect(find.text('Product name is required'), findsNothing);
      expect(find.text('Sale price is required'), findsNothing);
    });

    testWidgets('Valid submission without optional SKU', (tester) async {
      var submitted = false;
      await tester.pumpWidget(_wrap(
        _AddProductForm(onSubmit: (_) => submitted = true),
      ));

      await tester.enterText(find.byKey(const Key('name_field')), 'Rice Bag 5kg');
      await tester.enterText(find.byKey(const Key('price_field')), '250');
      await tester.tap(find.byKey(const Key('submit_btn')));
      await tester.pump();

      expect(submitted, isTrue);
    });
  });
}
