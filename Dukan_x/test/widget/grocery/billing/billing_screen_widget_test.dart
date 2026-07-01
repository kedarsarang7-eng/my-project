// ============================================================================
// LAYER 2 WIDGET TEST — Billing Screen (grocery)
// ============================================================================
// Demonstrates the widget test pattern for test/widget/<type>/<module>/.
//
// Tests:
//   1. Build & first frame (no exceptions, no overflow)
//   2. Input validation (valid/invalid field inputs)
//   3. State rendering (loading, empty, error, success)
//   4. Golden snapshot (≥1-pixel diff = failure, records screen + type)
//
// This is a scaffold/template. The InventoryScanner will discover all 460+
// screens across 19 types; per-screen tests will be populated using this
// pattern.
//
// Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '../../widget_test_harness.dart';

// ─── Minimal Billing Screen Stub ────────────────────────────────────────────
// A lightweight screen that mirrors the states and input behavior of
// BillCreationScreenV2 without requiring Riverpod, service locator, or backend
// wiring. Real screen tests will inject providers; this stub demonstrates the
// test harness pattern.

enum BillingScreenState { loading, empty, error, success }

class _BillingScreenStub extends StatefulWidget {
  final BillingScreenState initialState;
  const _BillingScreenStub({this.initialState = BillingScreenState.success});

  @override
  State<_BillingScreenStub> createState() => _BillingScreenStubState();
}

class _BillingScreenStubState extends State<_BillingScreenStub> {
  final _formKey = GlobalKey<FormState>();
  late BillingScreenState _state;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
  }

  String? _validateCustomerName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Customer name is required';
    }
    return null;
  }

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final amount = double.tryParse(value);
    if (amount == null) return 'Enter a valid amount';
    if (amount <= 0) return 'Amount must be positive';
    if (amount > 999999999.99) return 'Amount exceeds maximum limit';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Bill')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case BillingScreenState.loading:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(key: Key('loading_indicator')),
              SizedBox(height: 16),
              Text('Loading billing data...', key: Key('loading_text')),
            ],
          ),
        );

      case BillingScreenState.empty:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 64,
                key: Key('empty_icon'),
              ),
              const SizedBox(height: 16),
              const Text('No bills yet', key: Key('empty_text')),
              const SizedBox(height: 8),
              ElevatedButton(
                key: const Key('create_first_bill_btn'),
                onPressed: () =>
                    setState(() => _state = BillingScreenState.success),
                child: const Text('Create First Bill'),
              ),
            ],
          ),
        );

      case BillingScreenState.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
                key: Key('error_icon'),
              ),
              const SizedBox(height: 16),
              const Text('Failed to load billing data', key: Key('error_text')),
              const SizedBox(height: 8),
              ElevatedButton(
                key: const Key('retry_btn'),
                onPressed: () =>
                    setState(() => _state = BillingScreenState.loading),
                child: const Text('Retry'),
              ),
            ],
          ),
        );

      case BillingScreenState.success:
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Bill Creation',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    key: Key('success_title'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('customer_name_field'),
                    validator: _validateCustomerName,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('amount_field'),
                    validator: _validateAmount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (₹)'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    key: const Key('submit_bill_btn'),
                    onPressed: () => _formKey.currentState?.validate(),
                    child: const Text('Save Bill'),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}

// ============================================================================
// TESTS
// ============================================================================

void main() {
  // ─── 1. Build & First Frame ─────────────────────────────────────────────
  // Requirement 3.1: Screen builds and completes first frame without
  // throwing an exception and without reporting layout overflow errors.

  testBuildAndFirstFrame(
    screenName: 'BillingScreen',
    businessType: 'grocery',
    screenBuilder: () =>
        const _BillingScreenStub(initialState: BillingScreenState.success),
  );

  // ─── 2. Input Validation ────────────────────────────────────────────────
  // Requirement 3.2: valid input → accepted, no validation error
  // Requirement 3.3: invalid input → rejected, visible error indicator

  testInputValidation(
    screenName: 'BillingScreen',
    businessType: 'grocery',
    screenBuilder: () =>
        const _BillingScreenStub(initialState: BillingScreenState.success),
    submitButtonKey: const Key('submit_bill_btn'),
    fields: [
      const InputFieldTestConfig(
        fieldKey: Key('customer_name_field'),
        fieldName: 'Customer Name',
        validValue: 'Rajesh Kumar',
        invalidValue: '',
        expectedErrorText: 'Customer name is required',
      ),
      const InputFieldTestConfig(
        fieldKey: Key('amount_field'),
        fieldName: 'Amount',
        validValue: '1500.50',
        invalidValue: 'abc',
        expectedErrorText: 'Enter a valid amount',
      ),
    ],
  );

  // ─── 3. State Rendering ─────────────────────────────────────────────────
  // Requirement 3.4: For each defined state (loading, empty, error, success),
  // assert the screen renders the widgets corresponding to that state.

  testStates(
    screenName: 'BillingScreen',
    businessType: 'grocery',
    states: [
      StateTestConfig(
        stateName: 'loading',
        screenBuilder: () =>
            const _BillingScreenStub(initialState: BillingScreenState.loading),
        settle: false, // CircularProgressIndicator has infinite animation
        expectedWidgets: [
          find.byKey(const Key('loading_indicator')),
          find.byKey(const Key('loading_text')),
        ],
        absentWidgets: [
          find.byKey(const Key('empty_icon')),
          find.byKey(const Key('error_icon')),
          find.byKey(const Key('success_title')),
        ],
      ),
      StateTestConfig(
        stateName: 'empty',
        screenBuilder: () =>
            const _BillingScreenStub(initialState: BillingScreenState.empty),
        expectedWidgets: [
          find.byKey(const Key('empty_icon')),
          find.byKey(const Key('empty_text')),
          find.byKey(const Key('create_first_bill_btn')),
        ],
        absentWidgets: [
          find.byKey(const Key('loading_indicator')),
          find.byKey(const Key('error_icon')),
          find.byKey(const Key('success_title')),
        ],
      ),
      StateTestConfig(
        stateName: 'error',
        screenBuilder: () =>
            const _BillingScreenStub(initialState: BillingScreenState.error),
        expectedWidgets: [
          find.byKey(const Key('error_icon')),
          find.byKey(const Key('error_text')),
          find.byKey(const Key('retry_btn')),
        ],
        absentWidgets: [
          find.byKey(const Key('loading_indicator')),
          find.byKey(const Key('empty_icon')),
          find.byKey(const Key('success_title')),
        ],
      ),
      StateTestConfig(
        stateName: 'success',
        screenBuilder: () =>
            const _BillingScreenStub(initialState: BillingScreenState.success),
        expectedWidgets: [
          find.byKey(const Key('success_title')),
          find.byKey(const Key('customer_name_field')),
          find.byKey(const Key('amount_field')),
          find.byKey(const Key('submit_bill_btn')),
        ],
        absentWidgets: [
          find.byKey(const Key('loading_indicator')),
          find.byKey(const Key('empty_icon')),
          find.byKey(const Key('error_icon')),
        ],
      ),
    ],
  );

  // ─── 4. Golden Snapshot ─────────────────────────────────────────────────
  // Requirement 3.5: At least one golden snapshot per screen per business type
  // Requirement 3.6: ≥1-pixel diff from baseline FAILS; records screen + type
  //
  // Golden comparison behavior:
  //   - Reference PNG stored at: test/widget/grocery/billing/goldens/
  //   - File naming: billing_screen_grocery.png
  //   - Tolerance: 0 pixels (any diff fails)
  //   - On failure: records "BillingScreen [grocery]" in the test message
  //   - To generate/update baselines: flutter test --update-goldens

  goldenScreenTest(
    screenName: 'BillingScreen',
    businessType: 'grocery',
    module: 'billing',
    screenBuilder: () =>
        const _BillingScreenStub(initialState: BillingScreenState.success),
  );
}
