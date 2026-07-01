// ============================================================================
// ACCESSIBILITY THEME - High Contrast Mode Support (P3 FIX)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Accessibility settings state
class AccessibilitySettings {
  final bool highContrast;
  final bool largeText;
  final bool reduceMotion;
  final double textScale;
  final bool boldText;

  const AccessibilitySettings({
    this.highContrast = false,
    this.largeText = false,
    this.reduceMotion = false,
    this.textScale = 1.0,
    this.boldText = false,
  });

  AccessibilitySettings copyWith({
    bool? highContrast,
    bool? largeText,
    bool? reduceMotion,
    double? textScale,
    bool? boldText,
  }) {
    return AccessibilitySettings(
      highContrast: highContrast ?? this.highContrast,
      largeText: largeText ?? this.largeText,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      textScale: textScale ?? this.textScale,
      boldText: boldText ?? this.boldText,
    );
  }

  double get effectiveTextScale => largeText ? textScale * 1.3 : textScale;
}

/// Accessibility preferences manager
class AccessibilityPreferences {
  static const String _keyHighContrast = 'accessibility_high_contrast';
  static const String _keyLargeText = 'accessibility_large_text';
  static const String _keyReduceMotion = 'accessibility_reduce_motion';
  static const String _keyTextScale = 'accessibility_text_scale';
  static const String _keyBoldText = 'accessibility_bold_text';

  final SharedPreferences _prefs;

  AccessibilityPreferences(this._prefs);

  AccessibilitySettings load() {
    return AccessibilitySettings(
      highContrast: _prefs.getBool(_keyHighContrast) ?? false,
      largeText: _prefs.getBool(_keyLargeText) ?? false,
      reduceMotion: _prefs.getBool(_keyReduceMotion) ?? false,
      textScale: _prefs.getDouble(_keyTextScale) ?? 1.0,
      boldText: _prefs.getBool(_keyBoldText) ?? false,
    );
  }

  Future<void> save(AccessibilitySettings settings) async {
    await _prefs.setBool(_keyHighContrast, settings.highContrast);
    await _prefs.setBool(_keyLargeText, settings.largeText);
    await _prefs.setBool(_keyReduceMotion, settings.reduceMotion);
    await _prefs.setDouble(_keyTextScale, settings.textScale);
    await _prefs.setBool(_keyBoldText, settings.boldText);
  }
}

/// Accessibility settings notifier
class AccessibilityNotifier extends Notifier<AccessibilitySettings> {
  late final AccessibilityPreferences _prefs;

  @override
  AccessibilitySettings build() => const AccessibilitySettings();

  /// Initialize with preferences (call after creation)
  void init(AccessibilityPreferences prefs) {
    _prefs = prefs;
  }

  Future<void> load() async {
    state = _prefs.load();
  }

  Future<void> setHighContrast(bool value) async {
    state = state.copyWith(highContrast: value);
    await _prefs.save(state);
  }

  Future<void> setLargeText(bool value) async {
    state = state.copyWith(largeText: value);
    await _prefs.save(state);
  }

  Future<void> setReduceMotion(bool value) async {
    state = state.copyWith(reduceMotion: value);
    await _prefs.save(state);
  }

  Future<void> setTextScale(double value) async {
    state = state.copyWith(textScale: value);
    await _prefs.save(state);
  }

  Future<void> setBoldText(bool value) async {
    state = state.copyWith(boldText: value);
    await _prefs.save(state);
  }

  Future<void> reset() async {
    state = const AccessibilitySettings();
    await _prefs.save(state);
  }
}

/// Provider for accessibility settings
final accessibilityProvider =
    NotifierProvider<AccessibilityNotifier, AccessibilitySettings>(
      AccessibilityNotifier.new,
    );

/// Initialize accessibility provider (call during app startup)
Future<void> initializeAccessibilityProvider(
  AccessibilityNotifier notifier,
) async {
  final prefs = await SharedPreferences.getInstance();
  final accessibilityPrefs = AccessibilityPreferences(prefs);
  notifier.init(accessibilityPrefs);
  await notifier.load();
}

/// High contrast color schemes
class HighContrastColors {
  // Light high contrast
  static const ColorScheme lightHighContrast = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0000FF), // Pure blue
    onPrimary: Color(0xFFFFFFFF), // White
    primaryContainer: Color(0xFFB3D7FF),
    onPrimaryContainer: Color(0xFF000000),
    secondary: Color(0xFF008000), // Pure green
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFB3E6B3),
    onSecondaryContainer: Color(0xFF000000),
    surface: Color(0xFFFFFFFF), // Pure white
    onSurface: Color(0xFF000000), // Pure black
    surfaceContainerHighest: Color(0xFFF0F0F0),
    onSurfaceVariant: Color(0xFF000000),
    error: Color(0xFFFF0000), // Pure red
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFCCCC),
    onErrorContainer: Color(0xFF000000),
    outline: Color(0xFF000000),
    shadow: Color(0xFF000000),
    inverseSurface: Color(0xFF000000),
    onInverseSurface: Color(0xFFFFFFFF),
    inversePrimary: Color(0xFFB3D7FF),
    surfaceTint: Color(0xFF0000FF),
  );

  // Dark high contrast
  static const ColorScheme darkHighContrast = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF66B2FF), // Bright blue
    onPrimary: Color(0xFF000000),
    primaryContainer: Color(0xFF0000FF),
    onPrimaryContainer: Color(0xFFFFFFFF),
    secondary: Color(0xFF66FF66), // Bright green
    onSecondary: Color(0xFF000000),
    secondaryContainer: Color(0xFF008000),
    onSecondaryContainer: Color(0xFFFFFFFF),
    surface: Color(0xFF000000), // Pure black
    onSurface: Color(0xFFFFFFFF), // Pure white
    surfaceContainerHighest: Color(0xFF1A1A1A),
    onSurfaceVariant: Color(0xFFFFFFFF),
    error: Color(0xFFFF6666), // Bright red
    onError: Color(0xFF000000),
    errorContainer: Color(0xFFCC0000),
    onErrorContainer: Color(0xFFFFFFFF),
    outline: Color(0xFFFFFFFF),
    shadow: Color(0xFF000000),
    inverseSurface: Color(0xFFFFFFFF),
    onInverseSurface: Color(0xFF000000),
    inversePrimary: Color(0xFF0000FF),
    surfaceTint: Color(0xFF66B2FF),
  );
}

// ============================================================================
// TEXT-SCALE INTEGRATION CONTRACT (mobile-text-scale-responsive-hardening, R2)
// ============================================================================
//
// The previous `AccessibilityThemeBuilder` was removed here because it applied
// text scaling TWICE — once via `textTheme.fontSizeFactor` and again via a
// nested `MediaQuery.textScaler` — which is the exact double-scaling forbidden
// by Requirements 1.5 and 2.3. It was also never mounted in the widget tree
// (dead code), so its removal changes no runtime behavior.
//
// The single, authoritative text-scale source is `applyTextScaleClamp` in
// `lib/app/app.dart` (clamped to `kMaxTextScaleFactor = 1.3` on non-Windows,
// pass-through on Windows). That `MaterialApp.builder` site is the ONLY place
// that may override `MediaQuery.textScaler` for the tree.
//
// INTEGRATION CONTRACT — if an in-app accessibility text scale is ever
// surfaced in the future, it MUST be injected by overriding
// `MediaQuery.textScaler` *upstream* of `applyTextScaleClamp` in `app.dart`,
// NEVER via `textTheme.fontSizeFactor`. This guarantees any contribution is
// applied exactly once and is clamped on non-Windows platforms (R2.2–R2.4).
//
// The `AccessibilitySettings` / `AccessibilityNotifier` /
// `AccessibilityPreferences` / `AccessibilitySettingsScreen` declarations below
// are left in place as inert configuration state. They contribute NOTHING to
// text scaling and are intentionally left unwired by this feature.

/// No transitions page transition builder
class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

/// Accessibility settings screen
class AccessibilitySettingsScreen extends ConsumerWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(accessibilityProvider);
    final notifier = ref.read(accessibilityProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Accessibility')),
      body: ListView(
        children: [
          // High Contrast Mode
          SwitchListTile(
            secondary: const Icon(Icons.contrast),
            title: const Text('High Contrast'),
            subtitle: const Text('Increase contrast for better visibility'),
            value: settings.highContrast,
            onChanged: (value) => notifier.setHighContrast(value),
          ),
          const Divider(),

          // Large Text
          SwitchListTile(
            secondary: const Icon(Icons.text_fields),
            title: const Text('Large Text'),
            subtitle: const Text('Increase text size by 30%'),
            value: settings.largeText,
            onChanged: (value) => notifier.setLargeText(value),
          ),
          const Divider(),

          // Bold Text
          SwitchListTile(
            secondary: const Icon(Icons.format_bold),
            title: const Text('Bold Text'),
            subtitle: const Text('Make text thicker and easier to read'),
            value: settings.boldText,
            onChanged: (value) => notifier.setBoldText(value),
          ),
          const Divider(),

          // Text Scale Slider
          ListTile(
            leading: const Icon(Icons.format_size),
            title: const Text('Text Size'),
            subtitle: Slider(
              value: settings.textScale,
              min: 0.8,
              max: 2.0,
              divisions: 12,
              label: '${(settings.textScale * 100).toInt()}%',
              onChanged: (value) => notifier.setTextScale(value),
            ),
            trailing: Text('${(settings.textScale * 100).toInt()}%'),
          ),
          const Divider(),

          // Reduce Motion
          SwitchListTile(
            secondary: const Icon(Icons.animation),
            title: const Text('Reduce Motion'),
            subtitle: const Text('Minimize animations'),
            value: settings.reduceMotion,
            onChanged: (value) => notifier.setReduceMotion(value),
          ),
          const Divider(),

          // Reset
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Reset to Defaults'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset Accessibility Settings?'),
                  content: const Text(
                    'This will restore all accessibility settings to their default values.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await notifier.reset();
              }
            },
          ),

          // Preview Section
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Preview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sample Heading',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is sample body text to demonstrate how your accessibility settings affect the appearance of text throughout the app.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Sample Button'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
