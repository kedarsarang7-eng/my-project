// ============================================================================
// HARDWARE — Cross-Platform CSV Export Helper
// ============================================================================
// Replaces direct dart:io File/Directory usage in supplier CSV export so
// export succeeds on web as well as desktop/mobile (HARDWARE-023).
//
// On web: uses Share.shareXFiles with XFile.fromData (in-memory bytes).
// On native: writes to documents/exports directory, then shares.
// ============================================================================

import 'dart:convert';
import 'dart:io' show Directory, File, Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Cross-platform CSV export utility for hardware supplier data.
///
/// Guards dart:io usage behind a [kIsWeb] check so the export method
/// works on web (via in-memory XFile) as well as desktop/mobile
/// (via file-system write + share sheet).
class HardwareCsvExportHelper {
  HardwareCsvExportHelper._();

  /// Platform check — overridable in tests to simulate web environment.
  @visibleForTesting
  static bool Function() platformIsWeb = () => kIsWeb;

  /// Exports [csvContent] as a downloadable CSV file named [filename].
  ///
  /// Returns:
  /// - On web: `'web-download'`
  /// - On native: the absolute file path written
  static Future<String> exportCsv({
    required String csvContent,
    required String filename,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(csvContent));

    if (platformIsWeb()) {
      // Web: no dart:io — use in-memory XFile from share_plus.
      final xFile = XFile.fromData(bytes, name: filename, mimeType: 'text/csv');
      await Share.shareXFiles([xFile], text: filename);
      return 'web-download';
    } else {
      // Desktop / mobile: write to file system then share.
      final docsDir = await getApplicationDocumentsDirectory();
      final sep = Platform.pathSeparator;
      final exportsDir = Directory('${docsDir.path}${sep}exports');
      if (!await exportsDir.exists()) {
        await exportsDir.create(recursive: true);
      }
      final filePath = '${exportsDir.path}$sep$filename';
      await File(filePath).writeAsBytes(bytes);
      await Share.shareXFiles([XFile(filePath)], text: filename);
      return filePath;
    }
  }
}
