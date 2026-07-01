import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/billing/feature_resolver.dart';
import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/core/pdf/invoice_column_model.dart';

void main() {
  group('Stability Verification - Business Types', () {
    test(
      'All 13 BusinessTypes should have valid FeatureResolver configuration',
      () {
        for (final type in BusinessType.values) {
          final resolver = FeatureResolver(type);
          // Basic sanity checks - no crash accessing getters
          expect(resolver.isMandiMode, isA<bool>());
          expect(resolver.isRetailMode, isA<bool>());
          expect(resolver.isServiceMode, isA<bool>());
          expect(resolver.showCommissionLogic, isA<bool>());
        }
      },
    );

    test('VegetablesBroker should have correct unique flags', () {
      final resolver = FeatureResolver(BusinessType.vegetablesBroker);
      expect(resolver.isMandiMode, true, reason: 'Broker MUST be Mandi mode');
      expect(
        resolver.showCommissionLogic,
        true,
        reason: 'Broker MUST show commission',
      );
      expect(
        resolver.showWeightBilling,
        true,
        reason: 'Broker MUST show weight billing',
      );
      expect(
        resolver.showBarcodeScanner,
        false,
        reason: 'Broker does NOT need barcode',
      );
    });

    test('Grocery should have correct flags', () {
      final resolver = FeatureResolver(BusinessType.grocery);
      expect(resolver.isRetailMode, true);
      expect(resolver.isMandiMode, false);
      expect(resolver.showCommissionLogic, false);
    });

    test('Restaurant should have correct flags', () {
      final resolver = FeatureResolver(BusinessType.restaurant);
      expect(resolver.isRestaurantMode, true);
      expect(resolver.isRetailMode, false);
    });
  });

  group('Stability Verification - Configuration', () {
    test('All BusinessTypes must have a valid Config', () {
      for (final type in BusinessType.values) {
        final config = BusinessTypeRegistry.getConfig(type);
        expect(config.type, type, reason: 'Config type mismatch for $type');
        expect(
          config.requiredFields,
          isNotEmpty,
          reason: '$type has no required fields',
        );
        expect(config.unitOptions, isNotEmpty, reason: '$type has no units');
      }
    });

    test('VegetablesBroker Config Integrity', () {
      final config = BusinessTypeRegistry.getConfig(
        BusinessType.vegetablesBroker,
      );
      expect(config.hasField(ItemField.commission), true);
      expect(config.hasField(ItemField.marketFee), true);
      expect(config.hasField(ItemField.grossWeight), true);
      expect(config.defaultGstRate, 0.0);
    });
  });

  group('Stability Verification - PDF Columns', () {
    test('InvoiceSchemaResolver returns columns for all types', () {
      for (final type in BusinessType.values) {
        final columns = InvoiceSchemaResolver.getColumns(
          type,
          true,
        ); // true = showTax
        expect(columns, isNotEmpty);
        expect(
          columns.any((c) => c.key == 'sno'),
          true,
          reason: 'S.No missing for $type',
        );
        expect(
          columns.any((c) => c.key == 'amount'),
          true,
          reason: 'Amount missing for $type',
        );
      }
    });

    test('Mandi PDF has special columns', () {
      final columns = InvoiceSchemaResolver.getColumns(
        BusinessType.vegetablesBroker,
        false,
      );
      expect(
        columns.any((c) => c.key == 'gross'),
        true,
        reason: 'Gross Weight missing in PDF',
      );
      expect(
        columns.any((c) => c.key == 'comm'),
        true,
        reason: 'Commission missing in PDF',
      );
    });
  });
}
