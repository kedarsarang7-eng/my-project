import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Loads the bundled NotoSansDevanagari TTFs and builds a [pw.ThemeData] so the
/// config-driven PDF builder renders the rupee symbol (₹) and Devanagari/Hindi
/// text correctly instead of falling back to Helvetica (which has no Unicode
/// support and emits warnings + missing glyphs).
class InvoicePdfFonts {
  static const _regularAsset = 'assets/fonts/NotoSansDevanagari-Regular.ttf';
  static const _boldAsset = 'assets/fonts/NotoSansDevanagari-Bold.ttf';

  static pw.Font? _regular;
  static pw.Font? _bold;
  static pw.ThemeData? _cachedTheme;

  /// Build (and cache) a Unicode-capable PDF theme. Falls back to `null` if the
  /// fonts cannot be loaded, in which case the builder uses the default font.
  static Future<pw.ThemeData?> theme() async {
    if (_cachedTheme != null) return _cachedTheme;
    try {
      _regular ??= pw.Font.ttf(await rootBundle.load(_regularAsset));
      _bold ??= pw.Font.ttf(await rootBundle.load(_boldAsset));
      _cachedTheme = pw.ThemeData.withFont(base: _regular!, bold: _bold!);
      return _cachedTheme;
    } catch (_) {
      // Missing/unloadable font must not break invoice generation.
      return null;
    }
  }

  /// Test hook to reset the cache.
  static void resetForTest() {
    _regular = null;
    _bold = null;
    _cachedTheme = null;
  }
}
