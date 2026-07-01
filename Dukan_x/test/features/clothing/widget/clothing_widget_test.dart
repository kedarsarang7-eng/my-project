// ============================================================================
// Clothing Widget Tests — Phase 10 (Requirement 16.4)
// Coverage: Variant grid save path + Tailoring measurement validation
// ============================================================================
// Run: flutter test test/features/clothing/widget/clothing_widget_test.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/clothing/widgets/variant_grid/variant_grid_widget.dart';
import 'package:dukanx/features/clothing/widgets/variant_grid/variant_cell_key.dart';
import 'package:dukanx/features/clothing/utils/clothing_business_rules.dart';

void main() {
  // ─── VariantGridWidget Save Path ──────────────────────────────────────────

  group('VariantGridWidget save path', () {
    const testSizes = ['S', 'M', 'L'];
    const testColors = ['Red', 'Blue'];

    Widget buildGrid({
      Future<bool> Function(Map<String, int>)? onSave,
      bool isSaving = false,
      Map<String, int> initialQuantities = const {},
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: VariantGridWidget(
              sizes: testSizes,
              colors: testColors,
              initialQuantities: initialQuantities,
              onQuantitiesChanged: (_) {},
              onSave: onSave,
              isSaving: isSaving,
            ),
          ),
        ),
      );
    }

    testWidgets('Save button appears when onSave is provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildGrid(onSave: (_) async => true));
      await tester.pump();

      // The Save button should be present
      expect(find.text('Save Quantities'), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('Save button is absent when onSave is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildGrid(onSave: null));
      await tester.pump();

      // No Save button
      expect(find.text('Save Quantities'), findsNothing);
      expect(find.text('Saving…'), findsNothing);
    });

    testWidgets('Save button is disabled while isSaving=true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildGrid(onSave: (_) async => true, isSaving: true),
      );
      await tester.pump();

      // Button shows "Saving…" text and is disabled
      expect(find.text('Saving…'), findsOneWidget);
      expect(find.text('Save Quantities'), findsNothing);

      // The ElevatedButton should have a null onPressed (disabled)
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('Tapping Save invokes onSave with current quantities', (
      WidgetTester tester,
    ) async {
      Map<String, int>? savedQuantities;

      final initialQty = {
        variantCellKey('Red', 'S'): 5,
        variantCellKey('Blue', 'M'): 3,
      };

      await tester.pumpWidget(
        buildGrid(
          onSave: (quantities) async {
            savedQuantities = quantities;
            return true;
          },
          initialQuantities: initialQty,
        ),
      );
      await tester.pump();

      // Tap the Save button
      await tester.tap(find.text('Save Quantities'));
      await tester.pumpAndSettle();

      // onSave should have been called with the current quantities
      expect(savedQuantities, isNotNull);
      expect(savedQuantities![variantCellKey('Red', 'S')], 5);
      expect(savedQuantities![variantCellKey('Blue', 'M')], 3);
    });

    testWidgets('Quantity bounds: rejects > 999,999', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildGrid(onSave: (_) async => true));
      await tester.pump();

      // Find a quantity text field (data cells, not headers)
      // The grid has header cells and data cells. Data cells have TextFields.
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);

      // Enter a value > 999,999 into the first data cell
      await tester.enterText(textFields.first, '1000000');
      await tester.pump();

      // The grid uses _updateQuantity which shows a SnackBar for out-of-bounds
      // The cell's onChanged fires on text changes, but the parent grid's
      // _updateQuantity validates bounds. Let's verify the SnackBar appears.
      // Note: The VariantCell fires onChanged with the parsed int directly,
      // so we need to verify the grid catches it. Actually, looking at the code:
      // VariantCell.onChanged fires with the int value, and the grid's
      // _updateQuantity rejects values > 999,999.
      //
      // The VariantCell itself doesn't validate bounds — it just parses the int
      // and fires onChanged. The grid's _updateQuantity does the bound check.
      // Since entering "1000000" in the TextField triggers VariantCell's local
      // onChanged which calls widget.onChanged(1000000), which triggers the
      // grid's _updateQuantity(color, size, 1000000), which rejects it.
      //
      // Verify the error SnackBar appeared:
      await tester.pump(); // pump for SnackBar animation
      expect(
        find.textContaining('Quantity must be between 0 and 999,999'),
        findsOneWidget,
      );
    });
  });

  // ─── Tailoring Measurement Validation ─────────────────────────────────────
  //
  // The full TailoringMeasurementsScreen has heavy infrastructure dependencies
  // (Riverpod, service locator, ClothingRepositoryOffline). These tests verify
  // the key validation behavior in isolation using a minimal form harness that
  // exercises the same ClothingBusinessRules.isValidMeasurement logic.

  group('Tailoring measurement validation', () {
    /// Minimal form that mirrors TailoringMeasurementsScreen's validation:
    /// - Parses each field with double.tryParse
    /// - Validates against ClothingBusinessRules.isValidMeasurement bounds
    /// - On invalid: shows error, retains values, does not call onSave
    /// - On valid: calls onSave with parsed measurements
    Widget buildTailoringForm({
      required void Function(Map<MeasurementKey, double>) onSave,
    }) {
      return MaterialApp(
        home: Scaffold(body: _TailoringValidationTestForm(onSave: onSave)),
      );
    }

    testWidgets('Invalid measurement shows error and retains values', (
      WidgetTester tester,
    ) async {
      bool saveCalled = false;

      await tester.pumpWidget(
        buildTailoringForm(onSave: (_) => saveCalled = true),
      );
      await tester.pumpAndSettle();

      // Enter a chest value of 10 (below min bound of 20)
      final chestField = find.byKey(const Key('field_chest'));
      await tester.enterText(chestField, '10');

      // Enter a valid waist value
      final waistField = find.byKey(const Key('field_waist'));
      await tester.enterText(waistField, '30');

      // Tap save
      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      // Save should NOT have been called
      expect(saveCalled, isFalse);

      // Error should be shown naming the invalid field
      expect(find.textContaining('Chest'), findsWidgets);
      expect(find.textContaining('out of valid range'), findsOneWidget);

      // Values are retained (not cleared)
      final chestWidget = tester.widget<TextFormField>(
        find.byKey(const Key('field_chest')),
      );
      expect(chestWidget.controller?.text, '10');
    });

    testWidgets('Valid measurements proceed to save', (
      WidgetTester tester,
    ) async {
      Map<MeasurementKey, double>? savedMeasurements;

      await tester.pumpWidget(
        buildTailoringForm(
          onSave: (measurements) => savedMeasurements = measurements,
        ),
      );
      await tester.pumpAndSettle();

      // Enter valid values within bounds
      // Chest: min=20, max=70
      await tester.enterText(find.byKey(const Key('field_chest')), '38');
      // Waist: min=18, max=70
      await tester.enterText(find.byKey(const Key('field_waist')), '32');
      // Hips: min=20, max=70
      await tester.enterText(find.byKey(const Key('field_hip')), '40');

      // Tap save
      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      // Save should have been called with the valid measurements
      expect(savedMeasurements, isNotNull);
      expect(savedMeasurements![MeasurementKey.chest], 38.0);
      expect(savedMeasurements![MeasurementKey.waist], 32.0);
      expect(savedMeasurements![MeasurementKey.hip], 40.0);
    });

    testWidgets('Non-numeric input shows parse error', (
      WidgetTester tester,
    ) async {
      bool saveCalled = false;

      await tester.pumpWidget(
        buildTailoringForm(onSave: (_) => saveCalled = true),
      );
      await tester.pumpAndSettle();

      // Enter non-numeric text
      await tester.enterText(find.byKey(const Key('field_chest')), 'abc');

      // Tap save
      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      // Save should NOT have been called
      expect(saveCalled, isFalse);

      // Error should appear for the invalid field
      expect(find.textContaining('valid number'), findsOneWidget);
    });
  });
}

// ─── Test Harness Widget ────────────────────────────────────────────────────
// A simplified form that mimics TailoringMeasurementsScreen's validation logic
// (same bounds via ClothingBusinessRules.isValidMeasurement) without requiring
// Riverpod, service locator, or repository dependencies.

class _TailoringValidationTestForm extends StatefulWidget {
  final void Function(Map<MeasurementKey, double>) onSave;

  const _TailoringValidationTestForm({required this.onSave});

  @override
  State<_TailoringValidationTestForm> createState() =>
      _TailoringValidationTestFormState();
}

class _TailoringValidationTestFormState
    extends State<_TailoringValidationTestForm> {
  final _formKey = GlobalKey<FormState>();

  final _fields =
      <({String label, MeasurementKey key, TextEditingController controller})>[
        (
          label: 'Chest',
          key: MeasurementKey.chest,
          controller: TextEditingController(),
        ),
        (
          label: 'Waist',
          key: MeasurementKey.waist,
          controller: TextEditingController(),
        ),
        (
          label: 'Hips',
          key: MeasurementKey.hip,
          controller: TextEditingController(),
        ),
        (
          label: 'Shoulder',
          key: MeasurementKey.shoulder,
          controller: TextEditingController(),
        ),
        (
          label: 'Sleeve',
          key: MeasurementKey.sleeve,
          controller: TextEditingController(),
        ),
        (
          label: 'Length',
          key: MeasurementKey.length,
          controller: TextEditingController(),
        ),
        (
          label: 'Inseam',
          key: MeasurementKey.inseam,
          controller: TextEditingController(),
        ),
      ];

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    // Parse and validate against ClothingBusinessRules (same as real screen)
    final invalidFields = <String>[];
    final parsed = <MeasurementKey, double>{};

    for (final field in _fields) {
      final text = field.controller.text.trim();
      if (text.isEmpty) continue;

      final value = double.tryParse(text);
      if (value == null) {
        invalidFields.add(field.label);
        continue;
      }

      if (!ClothingBusinessRules.isValidMeasurement(field.key, value)) {
        invalidFields.add(field.label);
        continue;
      }

      parsed[field.key] = value;
    }

    if (invalidFields.isNotEmpty) {
      // Show error, retain values, do not call onSave
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid: ${invalidFields.join(', ')}')),
      );
      return;
    }

    widget.onSave(parsed);
  }

  @override
  void dispose() {
    for (final f in _fields) {
      f.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ..._fields.map((field) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  key: Key('field_${field.key.name}'),
                  controller: field.controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: field.label,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final number = double.tryParse(value);
                    if (number == null) {
                      return 'Please enter a valid number for ${field.label}';
                    }
                    if (!ClothingBusinessRules.isValidMeasurement(
                      field.key,
                      number,
                    )) {
                      return '${field.label} is out of valid range';
                    }
                    return null;
                  },
                ),
              );
            }),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('save_button'),
              onPressed: _handleSave,
              child: const Text('Save Measurements'),
            ),
          ],
        ),
      ),
    );
  }
}
