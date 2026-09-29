import 'package:meta/meta.dart';

import '../auth/beak_auth_adapter.dart';

/// Authentication screens over one existing backend session authority.
///
/// Registration and recovery require both opt-in and an adapter capability;
/// absent operations never report success.
@immutable
final class BeakAuthConfig {
  /// Configures built-in authentication screens; public registration is off.
  // --8<-- [start:BeakAuthConfig]
  const BeakAuthConfig({
    this.adapter,
    this.register = false,
    this.recover = false,
    this.idleLockTimeout,
    this.lockUserName,
    this.onUnlock,
  });
  // --8<-- [end:BeakAuthConfig]

  /// Backend authority; null uses the registered HTTP session store.
  final BeakAuthAdapter? adapter;

  /// Opt-in to the adapter's registration flow.
  final bool register;

  /// Opt-in to the adapter's password recovery flow.
  final bool recover;

  /// Both registration opt-in and transport capability are present.
  bool get allowsRegistration => register && adapter?.registration != null;

  /// Both recovery opt-in and transport capability are present.
  bool get allowsRecovery => recover && adapter?.recovery != null;

  /// Optional inactivity timeout before opening the configured lock screen.
  final Duration? idleLockTimeout;

  /// Display name used on the lock screen.
  final String? lockUserName;

  /// Validates unlocking; an absent callback never accepts a password.
  final Future<bool> Function(String password)? onUnlock;
}
