l// ignore_for_file: avoid_print
import 'dart:io';

const header = '''// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

''';

const gHeader = '''// GENERATED CODE - DO NOT MODIFY BY HAND

''';

const privError =
    "UnsupportedError('It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models')";

class Field {
  final String type;
  final String name;
  final String? defaultValue;
  Field(this.type, this.name, [this.defaultValue]);
  bool get isNullable => type.endsWith('?');
}

class FreezedClass {
  final String name;
  final List<Field> fields;
  final bool hasPrivateConstructor;
  FreezedClass(this.name, this.fields, {this.hasPrivateConstructor = false});
}

String genMixin(FreezedClass c) {
  final sb = StringBuffer();
  sb.writeln('/// @nodoc');
  sb.writeln('mixin _\$${c.name} {');
  for (final f in c.fields) {
    sb.writeln(
      '  ${f.type} get ${f.name} => throw _privateConstructorUsedError;',
    );
  }
  sb.writeln('');
  sb.writeln('  /// Serializes this ${c.name} to a JSON map.');
  sb.writeln(
    '  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;',
  );
  sb.writeln('  @JsonKey(ignore: true)');
  sb.writeln(
    '  \$${c.name}CopyWith<${c.name}> get copyWith => throw _privateConstructorUsedError;',
  );
  sb.writeln('}');
  return sb.toString();
}

String genCopyWith(FreezedClass c) {
  final sb = StringBuffer();
  final params = c.fields.map((f) => '${f.type} ${f.name}').join(', ');

  sb.writeln('/// @nodoc');
  sb.writeln('abstract class \$${c.name}CopyWith<\$Res> {');
  sb.writeln(
    '  factory \$${c.name}CopyWith(${c.name} value, \$Res Function(${c.name}) then) = _\$${c.name}CopyWithImpl<\$Res, ${c.name}>;',
  );
  sb.writeln('  @useResult');
  sb.writeln('  \$Res call({$params});');
  sb.writeln('}');
  sb.writeln('');

  sb.writeln('/// @nodoc');
  sb.writeln(
    'class _\$${c.name}CopyWithImpl<\$Res, \$Val extends ${c.name}> implements \$${c.name}CopyWith<\$Res> {',
  );
  sb.writeln('  _\$${c.name}CopyWithImpl(this._value, this._then);');
  sb.writeln('  final \$Val _value;');
  sb.writeln('  final \$Res Function(\$Val) _then;');
  sb.writeln('');
  sb.writeln('  @pragma(\'vm:prefer-inline\')');
  sb.writeln('  @override');
  final objParams = c.fields
      .map((f) => 'Object? ${f.name} = freezed')
      .join(', ');
  sb.writeln('  \$Res call({$objParams,}) {');
  sb.writeln('    return _then(_value.copyWith(');
  for (final f in c.fields) {
    final check = f.isNullable ? 'freezed' : 'null';
    sb.writeln(
      '      ${f.name}: $check == ${f.name} ? _value.${f.name} : ${f.name} as ${f.type},',
    );
  }
  sb.writeln('    ) as \$Val);');
  sb.writeln('  }');
  sb.writeln('}');
  return sb.toString();
}

String genImplCopyWith(FreezedClass c) {
  final sb = StringBuffer();
  final params = c.fields.map((f) => '${f.type} ${f.name}').join(', ');
  final objParams = c.fields
      .map((f) => 'Object? ${f.name} = freezed')
      .join(', ');

  sb.writeln('/// @nodoc');
  sb.writeln(
    'abstract class _\$\$${c.name}CopyWith<\$Res> implements \$${c.name}CopyWith<\$Res> {',
  );
  sb.writeln(
    '  factory _\$\$${c.name}CopyWith(_${c.name} value, \$Res Function(_${c.name}) then) = __\$\$${c.name}CopyWithImpl<\$Res>;',
  );
  sb.writeln('  @override');
  sb.writeln('  @useResult');
  sb.writeln('  \$Res call({$params});');
  sb.writeln('}');
  sb.writeln('');

  sb.writeln('/// @nodoc');
  sb.writeln(
    'class __\$\$${c.name}CopyWithImpl<\$Res> extends _\$${c.name}CopyWithImpl<\$Res, _${c.name}> implements _\$\$${c.name}CopyWith<\$Res> {',
  );
  sb.writeln(
    '  __\$\$${c.name}CopyWithImpl(_${c.name} _value, \$Res Function(_${c.name}) _then) : super(_value, _then);',
  );
  sb.writeln('');
  sb.writeln('  @pragma(\'vm:prefer-inline\')');
  sb.writeln('  @override');
  sb.writeln('  \$Res call({$objParams,}) {');
  sb.writeln('    return _then(_${c.name}(');
  for (final f in c.fields) {
    final check = f.isNullable ? 'freezed' : 'null';
    sb.writeln(
      '      ${f.name}: $check == ${f.name} ? _value.${f.name} : ${f.name} as ${f.type},',
    );
  }
  sb.writeln('    ));');
  sb.writeln('  }');
  sb.writeln('}');
  return sb.toString();
}

String genImpl(FreezedClass c) {
  final sb = StringBuffer();

  sb.writeln('/// @nodoc');
  sb.writeln('@JsonSerializable()');
  sb.writeln('class _${c.name} extends ${c.name} {');

  // Constructor
  final ctorParams = c.fields
      .map((f) {
        final req = (!f.isNullable && f.defaultValue == null)
            ? 'required '
            : '';
        final def = f.defaultValue != null ? ' = ${f.defaultValue}' : '';
        return '${req}this.${f.name}$def';
      })
      .join(', ');

  if (c.hasPrivateConstructor) {
    sb.writeln('  const _${c.name}({$ctorParams}) : super._();');
  } else {
    sb.writeln('  const _${c.name}({$ctorParams});');
  }
  sb.writeln('');

  sb.writeln(
    '  factory _${c.name}.fromJson(Map<String, dynamic> json) => _\$\$${c.name}ImplFromJson(json);',
  );
  sb.writeln('');

  // Fields
  for (final f in c.fields) {
    sb.writeln('  @override');
    if (f.defaultValue != null) sb.writeln('  @JsonKey()');
    sb.writeln('  final ${f.type} ${f.name};');
  }
  sb.writeln('');

  // toString
  sb.writeln('  @override');
  sb.writeln('  String toString() {');
  final toStrFields = c.fields.map((f) => '${f.name}: \$${f.name}').join(', ');
  sb.writeln("    return '${c.name}($toStrFields)';");
  sb.writeln('  }');
  sb.writeln('');

  // operator ==
  sb.writeln('  @override');
  sb.writeln('  bool operator ==(Object other) {');
  sb.writeln(
    '    return identical(this, other) || (other.runtimeType == runtimeType && other is _${c.name}',
  );
  for (final f in c.fields) {
    if (f.type.startsWith('List') || f.type.startsWith('Map')) {
      sb.writeln(
        '      && const DeepCollectionEquality().equals(other.${f.name}, ${f.name})',
      );
    } else {
      sb.writeln(
        '      && (identical(other.${f.name}, ${f.name}) || other.${f.name} == ${f.name})',
      );
    }
  }
  sb.writeln('    );');
  sb.writeln('  }');
  sb.writeln('');

  // hashCode
  sb.writeln('  @JsonKey(includeFromJson: false, includeToJson: false)');
  sb.writeln('  @override');
  if (c.fields.length <= 20) {
    final hashFields = c.fields
        .map((f) {
          if (f.type.startsWith('List') || f.type.startsWith('Map')) {
            return 'const DeepCollectionEquality().hash(${f.name})';
          }
          return f.name;
        })
        .join(', ');
    sb.writeln('  int get hashCode => Object.hash($hashFields);');
  } else {
    sb.writeln('  int get hashCode => Object.hashAll([');
    for (final f in c.fields) {
      if (f.type.startsWith('List') || f.type.startsWith('Map')) {
        sb.writeln('    const DeepCollectionEquality().hash(${f.name}),');
      } else {
        sb.writeln('    ${f.name},');
      }
    }
    sb.writeln('  ]);');
  }
  sb.writeln('');

  // copyWith
  sb.writeln('  @JsonKey(ignore: true)');
  sb.writeln('  @override');
  sb.writeln('  @pragma(\'vm:prefer-inline\')');
  sb.writeln(
    '  _\$\$${c.name}CopyWith<_${c.name}> get copyWith => __\$\$${c.name}CopyWithImpl<_${c.name}>(this, _\$identity);',
  );
  sb.writeln('');

  // toJson
  sb.writeln('  @override');
  sb.writeln('  Map<String, dynamic> toJson() {');
  sb.writeln('    return _\$\$${c.name}ImplToJson(this,);');
  sb.writeln('  }');
  sb.writeln('}');

  return sb.toString();
}

String genFreezedFile(String partOf, List<FreezedClass> classes) {
  final sb = StringBuffer();
  sb.write(header);
  sb.writeln("part of '$partOf';");
  sb.writeln('');
  sb.writeln(
    '// **************************************************************************',
  );
  sb.writeln('// FreezedGenerator');
  sb.writeln(
    '// **************************************************************************',
  );
  sb.writeln('');
  sb.writeln('T _\$identity<T>(T value) => value;');
  sb.writeln('');
  sb.writeln("final _privateConstructorUsedError = $privError;");
  sb.writeln('');

  for (final c in classes) {
    // Top-level fromJson function that the source file calls
    sb.writeln('${c.name} _\$${c.name}FromJson(Map<String, dynamic> json) {');
    sb.writeln('  return _${c.name}.fromJson(json);');
    sb.writeln('}');
    sb.writeln('');
    sb.writeln(genMixin(c));
    sb.writeln('');
    sb.writeln(genCopyWith(c));
    sb.writeln('');
    sb.writeln(genImplCopyWith(c));
    sb.writeln('');
    sb.writeln(genImpl(c));
    sb.writeln('');
  }

  return sb.toString();
}

String genGFile(String partOf, List<FreezedClass> classes) {
  final sb = StringBuffer();
  sb.write(gHeader);
  sb.writeln("part of '$partOf';");
  sb.writeln('');
  sb.writeln(
    '// **************************************************************************',
  );
  sb.writeln('// JsonSerializableGenerator');
  sb.writeln(
    '// **************************************************************************',
  );
  sb.writeln('');

  for (final c in classes) {
    // fromJson
    sb.writeln(
      '_${c.name} _\$\$${c.name}ImplFromJson(Map<String, dynamic> json) => _${c.name}(',
    );
    for (final f in c.fields) {
      sb.writeln('      ${f.name}: ${genFromJsonField(f)},');
    }
    sb.writeln('    );');
    sb.writeln('');

    // toJson
    sb.writeln(
      'Map<String, dynamic> _\$\$${c.name}ImplToJson(_${c.name} instance) => <String, dynamic>{',
    );
    for (final f in c.fields) {
      sb.writeln("      '${f.name}': ${genToJsonField(f)},");
    }
    sb.writeln('    };');
    sb.writeln('');
  }

  return sb.toString();
}

String genFromJsonField(Field f) {
  final n = f.name;
  final t = f.type;

  if (t == 'String') return "json['$n'] as String";
  if (t == 'String?') return "json['$n'] as String?";
  if (t == 'int') return "(json['$n'] as num).toInt()";
  if (t == 'int?') return "(json['$n'] as num?)?.toInt()";
  if (t == 'double') return "(json['$n'] as num).toDouble()";
  if (t == 'double?') return "(json['$n'] as num?)?.toDouble()";
  if (t == 'bool') return "json['$n'] as bool? ?? ${f.defaultValue ?? 'false'}";
  if (t == 'bool?') return "json['$n'] as bool?";
  if (t == 'DateTime') return "DateTime.parse(json['$n'] as String)";
  if (t == 'DateTime?')
    return "json['$n'] == null ? null : DateTime.parse(json['$n'] as String)";

  // List types
  if (t.startsWith('List<') && t.endsWith('?>')) {
    final inner = t.substring(5, t.length - 2);
    return "(json['$n'] as List<dynamic>?)?.map((e) => ${genFromJsonInner(inner, 'e')}).toList()";
  }
  if (t.startsWith('List<') && t.endsWith('>')) {
    final inner = t.substring(5, t.length - 1);
    return "(json['$n'] as List<dynamic>?)?.map((e) => ${genFromJsonInner(inner, 'e')}).toList() ?? ${f.defaultValue ?? 'const []'}";
  }

  // Map types
  if (t.startsWith('Map<String,') && t.endsWith('?>')) {
    final inner = t.substring(12, t.length - 2).trim();
    return "(json['$n'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, ${genFromJsonInner(inner, 'v')}))";
  }
  if (t.startsWith('Map<String, double>?')) {
    return "(json['$n'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble()))";
  }

  // Enum types
  if (isEnumType(t)) {
    final base = t.replaceAll('?', '');
    if (t.endsWith('?')) {
      return "json['$n'] == null ? null : $base.values.firstWhere((e) => e.name == json['$n'], orElse: () => $base.values.first)";
    }
    final def = f.defaultValue ?? '$base.values.first';
    return "$base.values.firstWhere((e) => e.name == json['$n'], orElse: () => $def)";
  }

  // Complex object types
  final base = t.replaceAll('?', '');
  if (t.endsWith('?')) {
    return "json['$n'] == null ? null : $base.fromJson(json['$n'] as Map<String, dynamic>)";
  }
  return "$base.fromJson(json['$n'] as Map<String, dynamic>)";
}

String genFromJsonInner(String type, String varName) {
  if (type == 'String') return '$varName as String';
  if (type == 'int') return '($varName as num).toInt()';
  if (type == 'double') return '($varName as num).toDouble()';
  if (type == 'bool') return '$varName as bool';
  if (type == 'DateTime') return 'DateTime.parse($varName as String)';
  if (isEnumType(type))
    return '$type.values.firstWhere((x) => x.name == $varName, orElse: () => $type.values.first)';
  return '$type.fromJson($varName as Map<String, dynamic>)';
}

String genToJsonField(Field f) {
  final n = f.name;
  final t = f.type;

  if (t == 'DateTime') return "instance.$n.toIso8601String()";
  if (t == 'DateTime?') return "instance.$n?.toIso8601String()";

  if (t.startsWith('List<') && !isPrimitiveList(t)) {
    final isNullable = t.endsWith('?>');
    if (isNullable) {
      return "instance.$n?.map((e) => e.toJson()).toList()";
    }
    return "instance.$n.map((e) => e.toJson()).toList()";
  }

  if (t.startsWith('Map<String,') && !isPrimitiveMap(t)) {
    return "instance.$n?.map((k, v) => MapEntry(k, v.toJson()))";
  }

  if (isEnumType(t)) {
    if (t.endsWith('?')) return "instance.$n?.name";
    return "instance.$n.name";
  }

  // Complex object
  final base = t.replaceAll('?', '');
  if (!isPrimitive(base) && !t.startsWith('List') && !t.startsWith('Map')) {
    if (t.endsWith('?')) return "instance.$n?.toJson()";
    return "instance.$n.toJson()";
  }

  return "instance.$n";
}

bool isPrimitive(String t) {
  return ['String', 'int', 'double', 'bool', 'num'].contains(t);
}

bool isPrimitiveList(String t) {
  return t.contains('String') ||
      t.contains('int') ||
      t.contains('double') ||
      t.contains('bool');
}

bool isPrimitiveMap(String t) {
  return t.contains('double>') || t.contains('int>') || t.contains('String>');
}

// Known enum types in this project
final enumTypes = {
  'MetalType',
  'PurityStandard',
  'MakingChargeType',
  'JewelleryComplexity',
  'RepairStatus',
  'RepairPriority',
  'RepairType',
  'SchemeStatus',
  'PaymentFrequency',
  'RedemptionType',
  'AlertDirection',
  'NotificationMethod',
  'AlertStatus',
  'BusinessOrderStatus',
  'BusinessPaymentMethod',
  'BusinessPaymentStatus',
};

bool isEnumType(String t) {
  final base = t.replaceAll('?', '');
  return enumTypes.contains(base);
}

void main() {
  final base = 'lib';

  // 1. Product Model
  generateProductModel(base);

  // 2. Gold Rate Alert Model
  generateGoldRateAlertModel(base);

  // 3. Gold Scheme Model
  generateGoldSchemeModel(base);

  // 4. Jewellery Product Model
  generateJewelleryProductModel(base);

  // 5. Jewellery Repair Model
  generateJewelleryRepairModel(base);

  // 6. Making Charges Model
  generateMakingChargesModel(base);

  // 7. Business Order Models
  generateBusinessOrderModels(base);

  // 8. Vegetable Broker Models
  generateVegetableBrokerModels(base);

  print('All 16 generated files created successfully!');
}

void generateProductModel(String base) {
  final dir = '$base/features/inventory/data/models';
  final classes = [
    FreezedClass('ProductImage', [
      Field('String', 's3Key'),
      Field('String', 's3ThumbnailKey'),
      Field('int', 'uploadedAt'),
      Field('int', 'fileSize'),
    ]),
    FreezedClass('ProductVariant', [
      Field('String', 'id'),
      Field('String', 'name'),
      Field('String?', 'sku'),
      Field('double?', 'price'),
      Field('int?', 'stock'),
      Field('String?', 'strength'),
    ]),
    FreezedClass('Product', [
      Field('String', 'id'),
      Field('String', 'tenantId'),
      Field('String', 'businessType'),
      Field('String', 'name'),
      Field('String?', 'description'),
      Field('String?', 'category'),
      Field('String?', 'brand'),
      Field('ProductImage?', 'mainImage'),
      Field('List<ProductImage>?', 'images'),
      Field('double', 'price'),
      Field('double?', 'mrp'),
      Field('double?', 'cost'),
      Field('double', 'gstRate', '0'),
      Field('String?', 'hsn'),
      Field('String?', 'barcode'),
      Field('String?', 'sku'),
      Field('String?', 'batchNo'),
      Field('int?', 'expiryDate'),
      Field('String?', 'drugSchedule'),
      Field('String?', 'strength'),
      Field('String?', 'formulation'),
      Field('String?', 'manufacturer'),
      Field('int', 'stock', '0'),
      Field('int?', 'reorderLevel'),
      Field('int?', 'maxStock'),
      Field('String?', 'unit'),
      Field('List<ProductVariant>?', 'variants'),
      Field('bool', 'isActive', 'true'),
      Field('int', 'createdAt'),
      Field('int', 'updatedAt'),
      Field('String', 'createdBy'),
      Field('String', 'updatedBy'),
      Field('bool?', 'synced'),
      Field('int?', 'lastSyncedAt'),
      Field('int?', 'version'),
      Field('bool?', 'isDeleted'),
      Field('int?', 'deletedAt'),
    ]),
    FreezedClass('ProductListResponse', [
      Field('List<Product>', 'items'),
      Field('int', 'total'),
      Field('int', 'page'),
      Field('int', 'limit'),
      Field('String?', 'nextToken'),
    ]),
    FreezedClass('ProductFilters', [
      Field('String?', 'category'),
      Field('String?', 'brand'),
      Field('double?', 'minPrice'),
      Field('double?', 'maxPrice'),
      Field('bool?', 'inStock'),
      Field('String?', 'searchTerm'),
      Field('String?', 'barcode'),
      Field('bool?', 'lowStock'),
      Field('bool?', 'expiringSoon'),
    ]),
    FreezedClass('CreateProductRequest', [
      Field('String', 'name'),
      Field('String?', 'description'),
      Field('String?', 'category'),
      Field('String?', 'brand'),
      Field('double', 'price'),
      Field('double?', 'mrp'),
      Field('double?', 'cost'),
      Field('double?', 'gstRate'),
      Field('String?', 'hsn'),
      Field('String?', 'barcode'),
      Field('String?', 'sku'),
      Field('int?', 'stock'),
      Field('int?', 'reorderLevel'),
      Field('String?', 'unit'),
      Field('List<ProductVariant>?', 'variants'),
    ]),
    FreezedClass('UpdateProductRequest', [
      Field('String?', 'name'),
      Field('String?', 'description'),
      Field('String?', 'category'),
      Field('String?', 'brand'),
      Field('double?', 'price'),
      Field('double?', 'mrp'),
      Field('double?', 'cost'),
      Field('double?', 'gstRate'),
      Field('String?', 'hsn'),
      Field('String?', 'barcode'),
      Field('String?', 'sku'),
      Field('int?', 'stock'),
      Field('int?', 'reorderLevel'),
      Field('String?', 'unit'),
      Field('bool?', 'isActive'),
      Field('List<ProductVariant>?', 'variants'),
    ]),
  ];

  writeFiles(dir, 'product_model', classes);
}

void generateGoldRateAlertModel(String base) {
  final dir = '$base/features/jewellery/data/models';
  final classes = [
    FreezedClass('GoldRateAlert', [
      Field('String', 'id'),
      Field('String', 'tenantId'),
      Field('String', 'userId'),
      Field('MetalType', 'metalType'),
      Field('int', 'thresholdRatePaisaPerGram'),
      Field('AlertDirection', 'direction', 'AlertDirection.above'),
      Field('NotificationMethod', 'method', 'NotificationMethod.push'),
      Field('String?', 'note'),
      Field('bool', 'isRecurring', 'false'),
      Field('int?', 'recurrenceHours'),
      Field('DateTime?', 'expiryDate'),
      Field('AlertStatus', 'status', 'AlertStatus.active'),
      Field('DateTime?', 'lastTriggeredAt'),
      Field('int?', 'triggeredRatePaisa'),
      Field('int', 'triggerCount', '0'),
      Field('List<AlertRateCheck>?', 'rateHistory'),
      Field('List<AlertNotificationLog>?', 'notificationHistory'),
      Field('DateTime', 'createdAt'),
      Field('DateTime', 'updatedAt'),
      Field('bool', 'synced', 'true'),
      Field('DateTime?', 'lastSyncedAt'),
      Field('String?', 'pendingOperation'),
    ], hasPrivateConstructor: true),
    FreezedClass('AlertRateCheck', [
      Field('DateTime', 'checkedAt'),
      Field('int', 'ratePaisaPerGram'),
      Field('bool', 'wouldTrigger'),
    ]),
    FreezedClass('AlertNotificationLog', [
      Field('DateTime', 'sentAt'),
      Field('NotificationMethod', 'method'),
      Field('int', 'ratePaisaAtNotification'),
      Field('String', 'message'),
      Field('bool', 'delivered', 'true'),
      Field('String?', 'errorMessage'),
    ]),
    FreezedClass('AlertStatistics', [
      Field('int', 'totalAlerts', '0'),
      Field('int', 'activeAlerts', '0'),
      Field('int', 'triggeredAlerts', '0'),
      Field('int', 'expiredAlerts', '0'),
      Field('int', 'totalTriggers', '0'),
      Field('GoldRateAlert?', 'mostTriggeredAlert'),
      Field('GoldRateAlert?', 'recentlyTriggeredAlert'),
    ]),
  ];

  writeFiles(dir, 'gold_rate_alert_model', classes);
}

void generateGoldSchemeModel(String base) {
  final dir = '$base/features/jewellery/data/models';
  final classes = [
    FreezedClass('SchemePayment', [
      Field('String', 'id'),
      Field('int', 'installmentNumber'),
      Field('int', 'amountPaisa'),
      Field('DateTime', 'dueDate'),
      Field('DateTime?', 'paidDate'),
      Field('int?', 'paidAmountPaisa'),
      Field('bool', 'isPaid', 'false'),
      Field('bool', 'isLate', 'false'),
      Field('int?', 'lateFeePaisa'),
      Field('String?', 'paymentMode'),
      Field('String?', 'transactionId'),
      Field('String?', 'notes'),
      Field('String?', 'receivedBy'),
      Field('List<String>?', 'reminderSentDates'),
    ], hasPrivateConstructor: true),
    FreezedClass('GoldWeightRecord', [
      Field('DateTime', 'date'),
      Field('double', 'goldRatePerGramPaisa'),
      Field('double', 'goldWeightGrams'),
      Field('int', 'amountPaisa'),
      Field('String?', 'notes'),
    ], hasPrivateConstructor: true),
    FreezedClass('SchemeRedemption', [
      Field('String', 'id'),
      Field('RedemptionType', 'type'),
      Field('DateTime', 'redemptionDate'),
      Field('int', 'totalAmountPaisa'),
      Field('int?', 'bonusAmountPaisa'),
      Field('int?', 'discountAmountPaisa'),
      Field('int?', 'finalAmountPaisa'),
      Field('double?', 'goldWeightGrams'),
      Field('double?', 'goldRateAtRedemptionPaisa'),
      Field('String?', 'purity'),
      Field('String?', 'productId'),
      Field('String?', 'productName'),
      Field('String?', 'invoiceId'),
      Field('String?', 'bankAccountNumber'),
      Field('String?', 'bankIfsc'),
      Field('String?', 'upiId'),
      Field('DateTime?', 'payoutDate'),
      Field('String?', 'notes'),
      Field('String?', 'processedBy'),
    ], hasPrivateConstructor: true),
    FreezedClass('GoldScheme', [
      Field('String', 'id'),
      Field('String', 'tenantId'),
      Field('String', 'schemeNumber'),
      Field('String', 'customerId'),
      Field('String', 'customerName'),
      Field('String?', 'customerPhone'),
      Field('String?', 'customerEmail'),
      Field('String?', 'customerAddress'),
      Field('String', 'schemeName'),
      Field('String?', 'schemeDescription'),
      Field('int', 'installmentAmountPaisa'),
      Field('int', 'totalInstallments'),
      Field('PaymentFrequency', 'frequency', 'PaymentFrequency.monthly'),
      Field('int?', 'minimumInstallmentsForRedemption'),
      Field('int?', 'vendorBonusPaisa'),
      Field('double?', 'bonusPercentage'),
      Field('String?', 'bonusDescription'),
      Field('bool', 'isGoldLinked', 'false'),
      Field('MetalType?', 'linkedMetalType'),
      Field('List<GoldWeightRecord>?', 'goldWeightHistory'),
      Field('SchemeStatus', 'status', 'SchemeStatus.active'),
      Field('DateTime', 'startDate'),
      Field('DateTime?', 'endDate'),
      Field('DateTime?', 'promisedRedemptionDate'),
      Field('List<SchemePayment>', 'payments'),
      Field('int', 'completedInstallments', '0'),
      Field('int', 'missedInstallments', '0'),
      Field('int', 'lateInstallments', '0'),
      Field('int', 'totalPaidPaisa', '0'),
      Field('int', 'totalLateFeesPaisa', '0'),
      Field('int?', 'accumulatedGoldWeightGrams'),
      Field('SchemeRedemption?', 'redemption'),
      Field('RedemptionType?', 'plannedRedemptionType'),
      Field('int?', 'defaultAfterMissedInstallments'),
      Field('int?', 'foreclosureChargePercent'),
      Field('DateTime?', 'defaultedDate'),
      Field('String?', 'defaultReason'),
      Field('DateTime?', 'cancelledDate'),
      Field('String?', 'cancellationReason'),
      Field('int?', 'cancellationChargesPaisa'),
      Field('int?', 'refundAmountPaisa'),
      Field('String?', 'referredByCustomerId'),
      Field('String?', 'referralCode'),
      Field('DateTime', 'createdAt'),
      Field('String', 'createdBy'),
      Field('DateTime', 'updatedAt'),
      Field('String', 'updatedBy'),
      Field('bool', 'synced', 'true'),
      Field('DateTime?', 'lastSyncedAt'),
      Field('String?', 'pendingOperation'),
    ], hasPrivateConstructor: true),
    FreezedClass('SchemeTemplate', [
      Field('String', 'id'),
      Field('String', 'name'),
      Field('String?', 'description'),
      Field('int', 'installmentAmountPaisa'),
      Field('int', 'totalInstallments'),
      Field('PaymentFrequency', 'frequency', 'PaymentFrequency.monthly'),
      Field('int?', 'vendorBonusPaisa'),
      Field('double?', 'bonusPercentage'),
      Field('String?', 'bonusDescription'),
      Field('int?', 'minimumInstallmentsForRedemption'),
      Field('bool', 'isGoldLinked', 'false'),
      Field('MetalType?', 'linkedMetalType'),
      Field('int?', 'defaultAfterMissedInstallments'),
      Field('int?', 'foreclosureChargePercent'),
      Field('bool', 'isActive', 'true'),
    ], hasPrivateConstructor: true),
    FreezedClass('GoldSchemeStatistics', [
      Field('int', 'totalSchemes', '0'),
      Field('int', 'activeSchemes', '0'),
      Field('int', 'completedSchemes', '0'),
      Field('int', 'redeemedSchemes', '0'),
      Field('int', 'defaultedSchemes', '0'),
      Field('int', 'totalCustomers', '0'),
      Field('int', 'totalPaidPaisa', '0'),
      Field('int', 'totalBonusPaisa', '0'),
      Field('int', 'totalOutstandingPaisa', '0'),
      Field('int', 'totalOverduePaisa', '0'),
      Field('double', 'averageSchemeDuration', '0.0'),
      Field('int', 'schemesDueThisMonth', '0'),
      Field('int', 'schemesOverdue', '0'),
    ], hasPrivateConstructor: true),
  ];

  writeFiles(dir, 'gold_scheme_model', classes);
}

void generateJewelleryProductModel(String base) {
  final dir = '$base/features/jewellery/data/models';
  final classes = [
    FreezedClass('JewelleryProduct', [
      Field('String', 'id'),
      Field('String', 'tenantId'),
      Field('String', 'businessType', "'jewellery'"),
      Field('String', 'name'),
      Field('String?', 'description'),
      Field('String', 'category', "'General'"),
      Field('String?', 'subCategory'),
      Field('MetalType', 'metalType', 'MetalType.gold22k'),
      Field('PurityStandard?', 'purityStandard'),
      Field('String?', 'purity'),
      Field('double', 'metalWeightGrams', '0.0'),
      Field('double', 'grossWeightGrams', '0.0'),
      Field('double', 'netWeightGrams', '0.0'),
      Field('double', 'makingChargesPerGram', '0'),
      Field('double', 'wastagePercent', '0'),
      Field('double', 'stoneWeightGrams', '0'),
      Field('double', 'stoneCharges', '0'),
      Field('String?', 'huid'),
      Field('String?', 'hallmarkNumber'),
      Field('DateTime?', 'hallmarkDate'),
      Field('String?', 'assayingCenter'),
      Field('bool', 'isHallmarked', 'false'),
      Field('int', 'pricePerGramPaisa'),
      Field('int', 'totalMrpPaisa'),
      Field('int?', 'costPricePaisa'),
      Field('int', 'stockQuantity', '0'),
      Field('int', 'reorderLevel', '5'),
      Field('String', 'unit', "'pcs'"),
      Field('double', 'gstRate', '3.0'),
      Field('String?', 'hsnCode'),
      Field('String?', 'barcode'),
      Field('String?', 'sku'),
      Field('String?', 's3ImageKey'),
      Field('String?', 's3ThumbnailKey'),
      Field('String?', 'presignedImageUrl'),
      Field('List<String>?', 'additionalImageKeys'),
      Field('bool', 'isActive', 'true'),
      Field('DateTime', 'createdAt'),
      Field('DateTime', 'updatedAt'),
      Field('String', 'createdBy'),
      Field('String', 'updatedBy'),
      Field('bool', 'synced', 'true'),
      Field('DateTime?', 'lastSyncedAt'),
      Field('int', 'version', '1'),
      Field('bool', 'isDeleted', 'false'),
      Field('DateTime?', 'deletedAt'),
      Field('String?', 'pendingOperation'),
      Field('DateTime?', 'pendingSince'),
    ], hasPrivateConstructor: true),
    FreezedClass('GoldRateCard', [
      Field('String', 'id'),
      Field('String', 'tenantId'),
      Field('String', 'date'),
      Field('int', 'gold24KPer10gPaisa'),
      Field('int', 'gold22KPer10gPaisa'),
      Field('int', 'gold18KPer10gPaisa'),
      Field('int', 'silverPerKgPaisa'),
      Field('int', 'platinumPerGramPaisa'),
      Field('String', 'source', "'MANUAL'"),
      Field('String?', 'notes'),
      Field('DateTime', 'createdAt'),
      Field('String', 'createdBy'),
      Field('bool', 'synced', 'true'),
      Field('DateTime?', 'lastSyncedAt'),
      Field('String?', 'pendingOperation'),
    ], hasPrivateConstructor: true),
    FreezedClass('OldGoldExchange', [
      Field('String', 'id'),
      Field('String', 'tenantId'),
      Field('String', 'customerId'),
      Field('String', 'customerName'),
      Field('String?', 'customerPhone'),
      Field('String', 'customerIdType'),
      Field('String', 'customerIdNumber'),
      Field('String?', 'customerPhotoUrl'),
      Field('String?', 'idDocumentUrl'),
      Field('MetalType', 'oldGoldMetalType'),
      Field('double', 'oldGoldWeightGrams'),
      Field('int', 'oldGoldValuePaisa'),
      Field('int', 'oldGoldRatePerGramPaisa'),
      Field('String?', 'purityTestMethod'),
      Field('double?', 'actualPurityPercentage'),
      Field('String?', 'purityTestReportUrl'),
      Field('String?', 'newItemDescription'),
      Field('MetalType?', 'newItemMetalType'),
      Field('double?', 'newItemWeightGrams'),
      Field('int?', 'newItemTotalPaisa'),
      Field('String?', 'newItemInvoiceId'),
      Field('int', 'exchangeValuePaisa'),
      Field('int', 'cashAdjustmentPaisa', '0'),
      Field('String', 'status', "'PENDING'"),
      Field('String?', 'verifiedBy'),
      Field('DateTime?', 'verifiedAt'),
      Field('DateTime', 'createdAt'),
      Field('String', 'createdBy'),
      Field('bool', 'synced', 'true'),
      Field('DateTime?', 'lastSyncedAt'),
      Field('String?', 'pendingOperation'),
      Field('bool', 'pmlCompliant', 'true'),
      Field('String?', 'complianceNotes'),
    ], hasPrivateConstructor: true),
    FreezedClass('JewelleryOrder', [
      Field('String', 'id'),
      Field('String', 'tenantId'),
      Field('String', 'customerId'),
      Field('String', 'customerName'),
      Field('String?', 'customerPhone'),
      Field('String', 'itemDescription'),
      Field('String?', 'designReference'),
      Field('String?', 'designNotes'),
      Field('MetalType', 'metalType'),
      Field('double', 'estimatedWeightGrams'),
      Field('double?', 'actualWeightGrams'),
      Field('int', 'metalRatePerGramPaisa'),
      Field('int', 'makingChargesPerGramPaisa'),
      Field('double', 'wastagePercent', '0'),
      Field('int', 'stoneChargesPaisa', '0'),
      Field('int', 'otherChargesPaisa', '0'),
      Field('int', 'estimatedTotalPaisa'),
      Field('int?', 'actualTotalPaisa'),
      Field('int', 'advanceReceivedPaisa', '0'),
      Field('String?', 'advancePaymentMode'),
      Field('DateTime', 'orderDate'),
      Field('String', 'promisedDeliveryDate'),
      Field('String?', 'actualDeliveryDate'),
      Field('String', 'status', "'PENDING'"),
      Field('List<OrderStatusUpdate>?', 'statusHistory'),
      Field('String?', 'assignedTo'),
      Field('List<WorkProgressUpdate>?', 'workProgress'),
      Field('String?', 'finalProductId'),
      Field('String?', 'invoiceId'),
      Field('DateTime', 'createdAt'),
      Field('String', 'createdBy'),
      Field('DateTime', 'updatedAt'),
      Field('String', 'updatedBy'),
      Field('bool', 'synced', 'true'),
      Field('DateTime?', 'lastSyncedAt'),
      Field('String?', 'pendingOperation'),
    ], hasPrivateConstructor: true),
    FreezedClass('OrderStatusUpdate', [
      Field('String', 'status'),
      Field('DateTime', 'timestamp'),
      Field('String', 'updatedBy'),
      Field('String?', 'notes'),
    ]),
    FreezedClass('WorkProgressUpdate', [
      Field('String', 'stage'),
      Field('DateTime', 'timestamp'),
      Field('String?', 'notes'),
      Field('List<String>?', 'imageUrls'),
    ]),
    FreezedClass('HallmarkRegisterEntry', [
      Field('String', 'id'),
      Field('String', 'tenantId'),
      Field('String', 'huid'),
      Field('String', 'productId'),
      Field('String', 'productName'),
      Field('PurityStandard', 'purityStandard'),
      Field('double', 'weightGrams'),
      Field('String?', 'articleType'),
      Field('String?', 'bisLogo'),
      Field('String?', 'purityMark'),
      Field('String?', 'assayingCenterMark'),
      Field('String?', 'jewelerMark'),
      Field('DateTime', 'hallmarkDate'),
      Field('String?', 'registrationNumber'),
      Field('String', 'status', "'ACTIVE'"),
      Field('String?', 'saleInvoiceId'),
      Field('DateTime?', 'soldDate'),
      Field('String?', 'hallmarkImageUrl'),
      Field('String?', 'productImageUrl'),
      Field('DateTime', 'createdAt'),
      Field('bool', 'synced', 'true'),
      Field('DateTime?', 'lastSyncedAt'),
    ], hasPrivateConstructor: true),
  ];

  writeFiles(dir, 'jewellery_product_model', classes);
}

void generateJewelleryRepairModel(String base) {
  final dir = '$base/features/jewellery/data/models';
  final classes = [
    FreezedClass('RepairStatusUpdate', [
      Field('RepairStatus', 'status'),
      Field('DateTime', 'timestamp'),
      Field('String', 'updatedBy'),
      Field('String?', 'notes'),
      Field('List<String>?', 'photoUrls'),
    ]),
    FreezedClass('RepairWorkItem', [
      Field('String', 'id'),
      Field('RepairType', 'type'),
      Field('String', 'description'),
      Field('int?', 'estimatedCostPaisa'),
      Field('int?', 'actualCostPaisa'),
      Field('bool', 'isCompleted', 'false'),
      Field('String?', 'completedBy'),
      Field('DateTime?', 'completedAt'),
      Field('String?', 'notes'),
    ], hasPrivateConstructor: true),
    FreezedClass('RepairMaterial', [
      Field('String', 'id'),
      Field('String', 'name'),
      Field('double', 'quantity'),
      Field('String', 'unit'),
      Field('int', 'costPaisa'),
      Field('String?', 'supplier'),
      Field('String?', 'notes'),
    ], hasPrivateConstructor: true),
    FreezedClass('JewelleryRepair', [
      Field('String', 'id'),
      Field('String', 'tenantId'),
      Field('String', 'jobNumber'),
      Field('String', 'customerId'),
      Field('String', 'customerName'),
      Field('String?', 'customerPhone'),
      Field('String?', 'customerEmail'),
      Field('String', 'itemDescription'),
      Field('String?', 'itemCategory'),
      Field('String?', 'metalType'),
      Field('double?', 'weightGrams'),
      Field('String?', 'productId'),
      Field('List<RepairWorkItem>', 'workItems'),
      Field('List<RepairMaterial>?', 'materials'),
      Field('RepairStatus', 'status', 'RepairStatus.pending'),
      Field('RepairPriority', 'priority', 'RepairPriority.normal'),
      Field('List<RepairStatusUpdate>?', 'statusHistory'),
      Field('List<String>?', 'conditionPhotoUrls'),
      Field('String?', 'customerComplaint'),
      Field('String?', 'damageAssessment'),
      Field('String?', 'recommendedWork'),
      Field('int?', 'estimatedCostPaisa'),
      Field('int?', 'estimatedDays'),
      Field('DateTime?', 'estimatedCompletionDate'),
      Field('int?', 'actualCostPaisa'),
      Field('int?', 'materialCostPaisa'),
      Field('int?', 'laborCostPaisa'),
      Field('int?', 'additionalChargesPaisa'),
      Field('String?', 'additionalChargesNote'),
      Field('int', 'advanceReceivedPaisa', '0'),
      Field('String?', 'assignedTo'),
      Field('String?', 'assignedToName'),
      Field('DateTime?', 'assignedAt'),
      Field('DateTime', 'receivedDate'),
      Field('DateTime?', 'promisedDate'),
      Field('DateTime?', 'completedDate'),
      Field('DateTime?', 'deliveredDate'),
      Field('DateTime?', 'workStartedDate'),
      Field('DateTime?', 'workCompletedDate'),
      Field('int?', 'actualWorkHours'),
      Field('String?', 'deliveredTo'),
      Field('String?', 'deliveryNotes'),
      Field('List<String>?', 'completionPhotoUrls'),
      Field('int', 'warrantyDays', '0'),
      Field('DateTime?', 'warrantyExpiryDate'),
      Field('String?', 'originalJobId'),
      Field('bool', 'isWarrantyClaim', 'false'),
      Field('int?', 'customerRating'),
      Field('String?', 'customerFeedback'),
      Field('String?', 'invoiceId'),
      Field('bool', 'isPaid', 'false'),
      Field('DateTime', 'createdAt'),
      Field('String', 'createdBy'),
      Field('DateTime', 'updatedAt'),
      Field('String', 'updatedBy'),
      Field('bool', 'synced', 'true'),
      Field('DateTime?', 'lastSyncedAt'),
      Field('String?', 'pendingOperation'),
    ], hasPrivateConstructor: true),
    FreezedClass('RepairStatistics', [
      Field('int', 'totalJobs', '0'),
      Field('int', 'pendingJobs', '0'),
      Field('int', 'inProgressJobs', '0'),
      Field('int', 'completedJobs', '0'),
      Field('int', 'deliveredJobs', '0'),
      Field('int', 'overdueJobs', '0'),
      Field('int', 'warrantyClaims', '0'),
      Field('double', 'averageRepairDays', '0'),
      Field('int', 'totalRevenuePaisa', '0'),
      Field('int', 'totalMaterialCostPaisa', '0'),
      Field('int', 'totalLaborCostPaisa', '0'),
    ], hasPrivateConstructor: true),
  ];

  writeFiles(dir, 'jewellery_repair_model', classes);
}

void generateMakingChargesModel(String base) {
  final dir = '$base/features/jewellery/data/models';
  final classes = [
    FreezedClass('TieredRate', [
      Field('double', 'minWeightGrams'),
      Field('double', 'maxWeightGrams'),
      Field('int', 'ratePaisaPerGram'),
      Field('String?', 'description'),
    ], hasPrivateConstructor: true),
    FreezedClass('ComplexityRate', [
      Field('JewelleryComplexity', 'complexity'),
      Field('int', 'ratePaisaPerGram'),
      Field('String?', 'description'),
    ], hasPrivateConstructor: true),
    FreezedClass('MakingChargesConfig', [
      Field('String', 'id'),
      Field('String', 'tenantId'),
      Field('String', 'name'),
      Field('String?', 'description'),
      Field('MakingChargeType', 'type', 'MakingChargeType.perGram'),
      Field('int?', 'ratePaisaPerGram'),
      Field('double?', 'percentageOfMetalValue'),
      Field('int?', 'fixedAmountPaisa'),
      Field('List<TieredRate>?', 'tieredRates'),
      Field('List<ComplexityRate>?', 'complexityRates'),
      Field('int?', 'baseAmountPaisa'),
      Field('double?', 'additionalPercentage'),
      Field('int?', 'minimumChargePaisa'),
      Field('int?', 'maximumChargePaisa'),
      Field('bool', 'applyOnWastage', 'false'),
      Field('bool', 'includeStoneWeight', 'false'),
      Field('int?', 'stoneMakingChargePaisa'),
      Field('double', 'stoneWeightPercentage', '0'),
      Field('bool', 'isActive', 'true'),
      Field('DateTime', 'createdAt'),
      Field('DateTime', 'updatedAt'),
      Field('bool', 'synced', 'true'),
      Field('DateTime?', 'lastSyncedAt'),
    ], hasPrivateConstructor: true),
    FreezedClass('MakingChargeResult', [
      Field('int', 'totalChargePaisa'),
      Field('int', 'metalChargePaisa'),
      Field('int?', 'stoneChargePaisa'),
      Field('double', 'metalWeightGrams'),
      Field('double?', 'stoneWeightGrams'),
      Field('int', 'metalRatePaisaPerGram'),
      Field('MakingChargeType', 'appliedType'),
      Field('String', 'calculationBreakdown'),
      Field('List<CalculationStep>', 'steps'),
      Field('DateTime?', 'calculatedAt'),
    ], hasPrivateConstructor: true),
    FreezedClass('CalculationStep', [
      Field('String', 'description'),
      Field('String', 'formula'),
      Field('int', 'resultPaisa'),
    ]),
  ];

  writeFiles(dir, 'making_charges_model', classes);
}

void generateBusinessOrderModels(String base) {
  final dir = '$base/features/marketplace/models';
  final classes = [
    FreezedClass('OnlineCustomer', [
      Field('String', 'customerId'),
      Field('String', 'name'),
      Field('String', 'phone'),
      Field('String?', 'email'),
      Field('int', 'totalOrders'),
      Field('double', 'totalSpent'),
      Field('String', 'connectedAt'),
    ]),
    FreezedClass('BusinessOrderItem', [
      Field('String', 'productId'),
      Field('String', 'name'),
      Field('String?', 'image'),
      Field('int', 'quantity'),
      Field('int?', 'stockQuantity'),
      Field('String', 'unit'),
      Field('double', 'mrp'),
      Field('double', 'sellingPrice'),
      Field('double', 'itemTotal'),
      Field('String?', 'prescriptionUrl'),
      Field('String?', 'cookingInstructions'),
      Field('bool?', 'warrantyRequired'),
      Field('bool?', 'isPrepared'),
      Field('String?', 'preparedAt'),
      Field('String?', 'preparedBy'),
    ]),
    FreezedClass('BusinessDeliveryAddress', [
      Field('String', 'id'),
      Field('String', 'label'),
      Field('String', 'addressLine1'),
      Field('String?', 'addressLine2'),
      Field('String?', 'landmark'),
      Field('String', 'city'),
      Field('String', 'state'),
      Field('String', 'pincode'),
      Field('String', 'contactName'),
      Field('String', 'contactPhone'),
      Field('Map<String, double>?', 'location'),
    ]),
    FreezedClass('BusinessOrderTimelineEvent', [
      Field('BusinessOrderStatus', 'status'),
      Field('String', 'timestamp'),
      Field('String?', 'note'),
      Field('String', 'updatedBy'),
    ]),
    FreezedClass('BusinessOrder', [
      Field('String', 'orderId'),
      Field('BusinessOrderStatus', 'status'),
      Field('OnlineCustomer', 'customer'),
      Field('int', 'itemCount'),
      Field('double', 'total'),
      Field('BusinessPaymentMethod', 'paymentMethod'),
      Field('BusinessPaymentStatus', 'paymentStatus'),
      Field('bool?', 'isExpress'),
      Field('String?', 'scheduledFor'),
      Field('String?', 'estimatedDeliveryTime'),
      Field('String', 'createdAt'),
      Field('String?', 'updatedAt'),
    ]),
    FreezedClass('BusinessOrderDetail', [
      Field('String', 'orderId'),
      Field('BusinessOrderStatus', 'status'),
      Field('OnlineCustomer', 'customer'),
      Field('List<BusinessOrderItem>', 'items', 'const []'),
      Field('BusinessDeliveryAddress', 'deliveryAddress'),
      Field('double', 'subtotal'),
      Field('double', 'taxAmount'),
      Field('double', 'deliveryCharge'),
      Field('double', 'discountAmount'),
      Field('String?', 'couponCode'),
      Field('double', 'total'),
      Field('BusinessPaymentMethod', 'paymentMethod'),
      Field('BusinessPaymentStatus', 'paymentStatus'),
      Field('bool?', 'isExpress'),
      Field('String?', 'scheduledFor'),
      Field('String?', 'estimatedDeliveryTime'),
      Field('List<BusinessOrderTimelineEvent>', 'timeline', 'const []'),
      Field('String?', 'notes'),
      Field('String?', 'prescriptionUrl'),
      Field('String?', 'createdAt'),
      Field('String?', 'updatedAt'),
      Field('DeliveryPartnerInfo?', 'assignedPartner'),
    ]),
    FreezedClass('DeliveryPartnerInfo', [
      Field('String', 'partnerId'),
      Field('String', 'name'),
      Field('String', 'phone'),
      Field('Map<String, double>?', 'currentLocation'),
      Field('String?', 'vehicleType'),
      Field('String?', 'vehicleNumber'),
      Field('bool?', 'isActive'),
    ]),
    FreezedClass('OrderStats', [
      Field('int', 'totalOrders'),
      Field('double', 'totalRevenue'),
      Field('int', 'pendingOrders'),
      Field('int', 'preparingOrders'),
      Field('int', 'outForDeliveryOrders'),
      Field('int', 'deliveredToday'),
      Field('double', 'avgOrderValue'),
      Field('int', 'newCustomers'),
      Field('int', 'repeatCustomers'),
    ]),
    FreezedClass('OrderFilters', [
      Field('BusinessOrderStatus?', 'status'),
      Field('DateTime?', 'dateFrom'),
      Field('DateTime?', 'dateTo'),
      Field('String?', 'searchQuery'),
      Field('String?', 'sortBy'),
      Field('bool?', 'isExpress'),
    ]),
    FreezedClass('PaginatedOrders', [
      Field('List<BusinessOrder>', 'orders', 'const []'),
      Field('int', 'total'),
      Field('int', 'page'),
      Field('int', 'limit'),
      Field('bool', 'hasMore'),
    ]),
    FreezedClass('InventorySyncItem', [
      Field('String', 'productId'),
      Field('String', 'name'),
      Field('String', 'category'),
      Field('double?', 'mrp'),
      Field('double?', 'sellingPrice'),
      Field('int?', 'stockQuantity'),
      Field('bool?', 'isActive'),
      Field('bool?', 'isAvailableForOnline'),
      Field('String?', 'barcode'),
      Field('String?', 'hsnCode'),
      Field('double?', 'gstPercent'),
      Field('String?', 'expiryDate'),
      Field('String?', 'drugSchedule'),
    ]),
  ];

  writeFiles(dir, 'business_order_models', classes);
}

void generateVegetableBrokerModels(String base) {
  final dir = '$base/features/vegetable_broker/data/models';
  final classes = [
    FreezedClass('VegetableLot', [
      Field('String', 'lotId'),
      Field('String', 'vegetableName'),
      Field('String', 'variety'),
      Field('double', 'grossWeightKg'),
      Field('double', 'tareWeightKg'),
      Field('double', 'netWeightKg'),
      Field('double', 'ratePerKgPaisa'),
      Field('double', 'totalValuePaisa'),
      Field('String', 'farmerId'),
      Field('String?', 'farmerName'),
      Field('String?', 'farmerPhone'),
      Field('String?', 'lotNumber'),
      Field('DateTime?', 'arrivalDate'),
      Field('String?', 'vehicleNumber'),
      Field('String?', 'grade'),
      Field('double?', 'commissionPercent'),
      Field('double?', 'commissionPaisa'),
      Field('double?', 'marketFeePaisa'),
      Field('double?', 'otherChargesPaisa'),
      Field('double?', 'farmerPayablePaisa'),
      Field('String', 'status', "'ARRIVED'"),
      Field('String?', 'buyerId'),
      Field('String?', 'buyerName'),
      Field('DateTime?', 'soldDate'),
      Field('double?', 'soldRatePerKgPaisa'),
      Field('DateTime?', 'createdAt'),
      Field('DateTime?', 'updatedAt'),
      Field('String?', 'notes'),
    ]),
    FreezedClass('Farmer', [
      Field('String', 'farmerId'),
      Field('String', 'name'),
      Field('String?', 'phone'),
      Field('String?', 'address'),
      Field('String?', 'village'),
      Field('String?', 'district'),
      Field('String?', 'state'),
      Field('String?', 'bankAccountNumber'),
      Field('String?', 'bankIfsc'),
      Field('String?', 'upiId'),
      Field('double?', 'totalLotsSupplied'),
      Field('double?', 'totalWeightSuppliedKg'),
      Field('double?', 'totalPayablePaisa'),
      Field('double?', 'totalPaidPaisa'),
      Field('double?', 'totalDuePaisa'),
      Field('DateTime?', 'createdAt'),
      Field('DateTime?', 'updatedAt'),
    ]),
    FreezedClass('VegetableBuyer', [
      Field('String', 'buyerId'),
      Field('String', 'name'),
      Field('String?', 'phone'),
      Field('String?', 'gstin'),
      Field('String?', 'businessType'),
      Field('double?', 'commissionPercent'),
      Field('double?', 'totalLotsBought'),
      Field('double?', 'totalPurchaseValuePaisa'),
      Field('double?', 'totalPaidPaisa'),
      Field('double?', 'totalDuePaisa'),
      Field('double?', 'creditLimitPaisa'),
      Field('DateTime?', 'createdAt'),
      Field('DateTime?', 'updatedAt'),
    ]),
    FreezedClass('MandiSession', [
      Field('String', 'sessionId'),
      Field('DateTime', 'date'),
      Field('String?', 'location'),
      Field('String?', 'mandiName'),
      Field('int?', 'totalLots'),
      Field('double?', 'totalWeightKg'),
      Field('double?', 'totalTurnoverPaisa'),
      Field('double?', 'totalCommissionPaisa'),
      Field('double?', 'totalMarketFeePaisa'),
      Field('Map<String, RateTrend>?', 'rateTrends'),
      Field('DateTime?', 'createdAt'),
      Field('DateTime?', 'closedAt'),
      Field('bool', 'isClosed', 'false'),
    ]),
    FreezedClass('RateTrend', [
      Field('String', 'vegetableName'),
      Field('String', 'variety'),
      Field('double?', 'minRatePaisa'),
      Field('double?', 'maxRatePaisa'),
      Field('double?', 'avgRatePaisa'),
      Field('double?', 'totalWeightKg'),
      Field('int?', 'lotCount'),
    ]),
    FreezedClass('FarmerSettlement', [
      Field('String', 'settlementId'),
      Field('String', 'farmerId'),
      Field('String', 'farmerName'),
      Field('DateTime', 'fromDate'),
      Field('DateTime', 'toDate'),
      Field('int?', 'totalLots'),
      Field('double?', 'totalWeightKg'),
      Field('double?', 'totalValuePaisa'),
      Field('double?', 'totalDeductionsPaisa'),
      Field('double?', 'netPayablePaisa'),
      Field('List<String>?', 'lotIds'),
      Field('double?', 'paidAmountPaisa'),
      Field('DateTime?', 'paidDate'),
      Field('String?', 'paymentMode'),
      Field('String?', 'referenceNumber'),
      Field('String?', 'status'),
      Field('DateTime?', 'createdAt'),
      Field('DateTime?', 'updatedAt'),
    ]),
  ];

  writeFiles(dir, 'vegetable_broker_models', classes);
}

void writeFiles(String dir, String baseName, List<FreezedClass> classes) {
  final freezedContent = genFreezedFile('$baseName.dart', classes);
  final gContent = genGFile('$baseName.dart', classes);

  final freezedFile = File('$dir/$baseName.freezed.dart');
  final gFile = File('$dir/$baseName.g.dart');

  freezedFile.writeAsStringSync(freezedContent);
  print('  Created: ${freezedFile.path}');

  gFile.writeAsStringSync(gContent);
  print('  Created: ${gFile.path}');
}
