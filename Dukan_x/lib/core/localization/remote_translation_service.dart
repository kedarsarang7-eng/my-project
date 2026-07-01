// =============================================================================
// RemoteTranslationService — OTA Translation Delta Loader
// =============================================================================
// Fetches a lightweight JSON delta from S3/CDN on app startup and merges it
// over the bundled ARB-generated strings. This allows translation fixes and
// new keys to ship without a full app release.
//
// Architecture:
//   1. On startup, fetch {CDN_BASE}/translations/{version}/{locale}.json
//   2. Merge the delta into an in-memory map keyed by locale code
//   3. AppL10n.tOverride(context, key) checks the delta first, falls back to ARB
//   4. On failure (network / parse error), silently use bundled strings
//
// CDN delta format (flat JSON, only override keys needed):
//   {
//     "billing": "Billing",          ← top-level key
//     "invoiceFor": "Invoice for {customerName}"  ← replaces ARB value
//   }
//
// Deployment:
//   aws s3 cp translations/hi.json s3://dukanx-cdn/translations/v2/hi.json
//   Invalidate CloudFront path: /translations/v2/*
// =============================================================================

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

/// Base URL for translation deltas. Override via env / build config.
/// Path pattern: $cdnBase/$version/$locale.json
const String _kDefaultCdnBase = 'https://cdn.dukanx.app/translations';
const String _kCurrentVersion = 'v1';

/// SharedPreferences key for persisted delta cache per locale
String _cacheKey(String locale) => 'ota_translations_$locale';

/// Keys that are never overridable (system-critical strings)
const Set<String> _kNonOverridableKeys = {
  'passwordLabel', // auth — must stay exact
  'appName',
};

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

/// Holds the merged delta map for all loaded locales.
class TranslationDeltaState {
  final Map<String, Map<String, String>> _deltas;
  final bool isLoaded;

  const TranslationDeltaState({
    Map<String, Map<String, String>>? deltas,
    this.isLoaded = false,
  }) : _deltas = deltas ?? const {};

  static const empty = TranslationDeltaState();

  /// Look up an override value for [key] in [locale].
  /// Returns null if no override exists → caller falls back to ARB.
  String? lookup(String locale, String key) {
    if (_kNonOverridableKeys.contains(key)) return null;
    return _deltas[locale]?[key];
  }

  TranslationDeltaState copyWith({
    Map<String, Map<String, String>>? deltas,
    bool? isLoaded,
  }) {
    return TranslationDeltaState(
      deltas: deltas ?? _deltas,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class RemoteTranslationNotifier
    extends AsyncNotifier<TranslationDeltaState> {
  static const List<String> _supportedLocales = [
    'en', 'hi', 'mr', 'gu', 'ta', 'te', 'kn', 'ml', 'bn', 'pa', 'ur',
  ];

  @override
  Future<TranslationDeltaState> build() async {
    return _loadAll();
  }

  /// Public method: refresh translations (e.g. pull-to-refresh on settings).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadAll);
  }

  Future<TranslationDeltaState> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final merged = <String, Map<String, String>>{};

    for (final locale in _supportedLocales) {
      final delta = await _loadLocale(locale, prefs);
      if (delta != null && delta.isNotEmpty) {
        merged[locale] = delta;
      }
    }

    return TranslationDeltaState(deltas: merged, isLoaded: true);
  }

  Future<Map<String, String>?> _loadLocale(
    String locale,
    SharedPreferences prefs,
  ) async {
    // Try network first (with short timeout to not block startup)
    try {
      final url = Uri.parse(
        '$_kDefaultCdnBase/$_kCurrentVersion/$locale.json',
      );
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return null;
        final parsed = _parseDelta(body);
        if (parsed != null) {
          // Persist to cache for offline use
          await prefs.setString(_cacheKey(locale), body);
          developer.log(
            'OTA translations loaded for $locale (${parsed.length} keys)',
            name: 'RemoteTranslationService',
          );
          return parsed;
        }
      }
    } catch (e) {
      developer.log(
        'OTA fetch failed for $locale: $e — trying cache',
        name: 'RemoteTranslationService',
      );
    }

    // Fall back to disk cache
    final cached = prefs.getString(_cacheKey(locale));
    if (cached != null) {
      final parsed = _parseDelta(cached);
      if (parsed != null) {
        developer.log(
          'OTA translations loaded from cache for $locale',
          name: 'RemoteTranslationService',
        );
        return parsed;
      }
    }

    return null; // No delta — use bundled ARB
  }

  /// Parses flat JSON delta to `Map<String, String>`.
  /// Ignores nested objects and non-string values silently.
  Map<String, String>? _parseDelta(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      return Map.fromEntries(
        decoded.entries
            .whereType<MapEntry<String, dynamic>>()
            .where((e) => e.value is String)
            .map((e) => MapEntry(e.key, e.value as String)),
      );
    } catch (e) {
      developer.log(
        'OTA delta parse error: $e',
        name: 'RemoteTranslationService',
      );
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final remoteTranslationProvider =
    AsyncNotifierProvider<RemoteTranslationNotifier, TranslationDeltaState>(
  RemoteTranslationNotifier.new,
);

/// Convenience provider: returns the loaded delta state or empty if still
/// loading / errored — never blocks the UI.
final translationDeltaProvider = Provider<TranslationDeltaState>((ref) {
  return ref.watch(remoteTranslationProvider).maybeWhen(
        data: (state) => state,
        orElse: () => TranslationDeltaState.empty,
      );
});
