import 'package:flutter/services.dart';

class PwaHaptics {
  static Future<void> tap() => HapticFeedback.selectionClick();
  static Future<void> success() => HapticFeedback.lightImpact();
}
