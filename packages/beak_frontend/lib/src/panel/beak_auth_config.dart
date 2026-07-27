import 'package:meta/meta.dart';

/// Declarative authentication configuration for a panel.
///
/// When set on `BeakPanelConfig.auth`, the router mounts `/login` (always),
/// plus `/register` and `/recover` when enabled, each rendered with
/// obers_ui's `OiAuthPage`.
///
/// The callbacks are overrides, not requirements: with no [onLogin] the panel
/// signs in against the generated `/api/auth/login` through the registered
/// `BeakSessionStore`, and every later request carries the session. Supply one
/// to authenticate somewhere else. Each returns `true` on success so the auth
/// screen can advance.
///
/// ```dart
/// // Server-side auth, already configured in lib/server.dart:
/// const BeakAuthConfig();
///
/// // Or somewhere else entirely:
/// BeakAuthConfig(
///   onLogin: (email, password) async => mySso.signIn(email, password),
/// );
/// ```
@immutable
final class BeakAuthConfig {
  /// Creates an auth configuration.
  const BeakAuthConfig({
    this.register = true,
    this.recover = true,
    this.onLogin,
    this.onRegister,
    this.onRecover,
    this.idleLockTimeout,
    this.lockUserName,
    this.onUnlock,
  });

  /// Whether a `/register` route is mounted.
  final bool register;

  /// Whether a `/recover` (forgot-password) route is mounted.
  final bool recover;

  /// Validates a sign-in; returns `true` on success.
  final Future<bool> Function(String email, String password)? onLogin;

  /// Handles a registration; returns `true` on success.
  final Future<bool> Function(String name, String email, String password)?
  onRegister;

  /// Handles a password-recovery request; returns `true` on success.
  final Future<bool> Function(String email)? onRecover;

  /// When set, the panel locks to `/lock` after this much inactivity inside
  /// the shell; `null` never auto-locks.
  final Duration? idleLockTimeout;

  /// The name shown on the lock screen (defaults to the panel title).
  final String? lockUserName;

  /// Validates the unlock password; returns `true` to unlock. `null` accepts
  /// any password (demo-friendly).
  final Future<bool> Function(String password)? onUnlock;
}
