import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obers_ui/obers_ui.dart';

/// Holds the panel's active [OiThemeMode] and notifies when it changes.
///
/// Registered in the panel's DI container so the shell's theme toggle can
/// update it and the root `BeakPanel` can rebuild `OiApp` with the new mode
/// — light/dark/system switching without rebuilding the router.
///
/// The chosen mode is persisted locally (browser `localStorage` /
/// `SharedPreferences` by default) so a reload keeps the user's preference.
/// [initialMode] is only the fallback when nothing has been saved yet.
// --8<-- [start:BeakThemeController]
final class BeakThemeController extends ValueNotifier<OiThemeMode> {
  /// Creates a controller starting in [initialMode], then restoring any
  /// previously saved preference from local storage.
  BeakThemeController([OiThemeMode initialMode = OiThemeMode.system])
    : this._(initialMode, const OiLocalStorageDriver(prefix: 'beak'));

  /// Test and host seam that supplies a custom settings [store].
  BeakThemeController.withStore(
    OiSettingsDriver store, {
    OiThemeMode initialMode = OiThemeMode.system,
  }) : this._(initialMode, store);

  BeakThemeController._(this.initialMode, this._store) : super(initialMode) {
    unawaited(restore());
  }

  /// Fallback mode used when no preference has been saved yet.
  final OiThemeMode initialMode;

  final OiSettingsDriver _store;
  int _epoch = 0;

  static const _namespace = 'theme';

  /// Reloads the persisted preference, if any.
  ///
  /// A concurrent [value] write wins over an in-flight restore.
  Future<void> restore() async {
    final epoch = ++_epoch;
    final saved = await _load();
    if (epoch != _epoch || saved == null || saved == value) return;
    super.value = saved;
  }

  @override
  set value(OiThemeMode newValue) {
    if (newValue == value) return;
    _epoch++;
    super.value = newValue;
    unawaited(_persist(newValue));
  }

  Future<OiThemeMode?> _load() async {
    try {
      final settings = await _store.load(
        namespace: _namespace,
        deserialize: _BeakThemeSettings.fromJson,
      );
      return settings?.mode;
    } on Object {
      return null;
    }
  }

  Future<void> _persist(OiThemeMode mode) async {
    try {
      final settings = _BeakThemeSettings(mode);
      await _store.save(
        namespace: _namespace,
        data: settings,
        serialize: (data) => data.toJson(),
      );
    } on Object {
      // Best-effort: missing plugin bindings (e.g. widget tests) must not
      // break the live theme toggle.
    }
  }
}
// --8<-- [end:BeakThemeController]

@immutable
final class _BeakThemeSettings with OiSettingsData {
  const _BeakThemeSettings(this.mode);

  factory _BeakThemeSettings.fromJson(Map<String, dynamic> json) {
    final name = json['mode'];
    if (name is! String) {
      throw const FormatException('Theme settings require a mode string.');
    }
    for (final mode in OiThemeMode.values) {
      if (mode.name == name) return _BeakThemeSettings(mode);
    }
    throw FormatException('Unknown theme mode "$name".');
  }

  final OiThemeMode mode;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'mode': mode.name,
  };
}
