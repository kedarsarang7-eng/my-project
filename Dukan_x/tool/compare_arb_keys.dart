// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() {
  final enFile = File('lib/l10n/app_en.arb');
  if (!enFile.existsSync()) {
    print('English ARB not found');
    return;
  }

  final Map<String, dynamic> enJson = jsonDecode(enFile.readAsStringSync());
  final enKeys = enJson.keys.where((k) => !k.startsWith('@')).toSet();
  print('English keys: ${enKeys.length}\n');

  final dir = Directory('lib/l10n');
  final files = dir.listSync().whereType<File>().where(
    (f) => f.path.endsWith('.arb') && !f.path.endsWith('app_en.arb'),
  );

  for (final file in files) {
    final Map<String, dynamic> json = jsonDecode(file.readAsStringSync());
    final keys = json.keys.where((k) => !k.startsWith('@')).toSet();
    final missing = enKeys.difference(keys);
    final extra = keys.difference(enKeys);

    final lang = file.path.split(Platform.pathSeparator).last;

    if (missing.isEmpty && extra.isEmpty) {
      print('✅ $lang matches (129 keys)');
    } else {
      print('❌ $lang mismatch');
      if (missing.isNotEmpty) {
        print(
          '   Missing (${missing.length}): ${missing.take(5).join(', ')}...',
        );
      }
      if (extra.isNotEmpty) {
        print('   Extra (${extra.length}): ${extra.take(5).join(', ')}...');
      }
    }
  }
}
