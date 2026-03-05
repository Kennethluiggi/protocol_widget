import 'package:flutter/foundation.dart';

/// Enable logs with:
/// flutter run -d windows --dart-define=DEBUG_WINDOW=true
/// flutter run -d windows --dart-define=DEBUG_LIFECYCLE=true
/// flutter run -d windows --dart-define=DEBUG_INIT=true
/// flutter run -d windows --dart-define=DEBUG_DB=true
/// flutter run -d windows --dart-define=DEBUG_WIDGET_MODE=true
///
/// In normal builds, these are false and produce no output.
class DebugLog {
  // Flags (named *Enabled* to avoid colliding with method names)
  static const bool enableWindow =
      bool.fromEnvironment('DEBUG_WINDOW', defaultValue: false);
  static const bool enableLifecycle =
      bool.fromEnvironment('DEBUG_LIFECYCLE', defaultValue: false);
  static const bool enableInit =
      bool.fromEnvironment('DEBUG_INIT', defaultValue: false);
  static const bool enableDb =
      bool.fromEnvironment('DEBUG_DB', defaultValue: false);
  static const bool enableWidgetMode =
      bool.fromEnvironment('DEBUG_WIDGET_MODE', defaultValue: false);

  // Log helpers
  static void window(String msg) {
    if (kDebugMode && enableWindow) debugPrint('[WINDOW] $msg');
  }

  static void lifecycle(String msg) {
    if (kDebugMode && enableLifecycle) debugPrint('[LIFECYCLE] $msg');
  }

  static void init(String msg) {
    if (kDebugMode && enableInit) debugPrint('[INIT] $msg');
  }

  static void widgetMode(String msg) {
    if (kDebugMode && enableWidgetMode) debugPrint('[WIDGET_MODE] $msg');
  }

  static void db(String msg) {
    if (kDebugMode && enableDb) debugPrint('[DB] $msg');
  }
}