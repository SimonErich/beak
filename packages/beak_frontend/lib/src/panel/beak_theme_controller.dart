import 'package:flutter/foundation.dart';
import 'package:obers_ui/obers_ui.dart';

/// Holds the panel's active [OiThemeMode] and notifies when it changes.
///
/// Registered in the panel's DI container so the shell's theme toggle can
/// update it and the root `BeakPanel` can rebuild `OiApp` with the new mode
/// — light/dark/system switching without rebuilding the router.
// --8<-- [start:BeakThemeController]
final class BeakThemeController extends ValueNotifier<OiThemeMode> {
  /// Creates a controller starting in the given mode (default: system).
  BeakThemeController([super.initialMode = OiThemeMode.system]);
}

// --8<-- [end:BeakThemeController]
