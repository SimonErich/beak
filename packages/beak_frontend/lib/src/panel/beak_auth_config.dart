import 'package:meta/meta.dart';

/// Declarative authentication configuration for a panel.
///
/// When set on `BeakPanelConfig.auth`, the router mounts `/login` (always),
/// plus `/register` and `/recover` when enabled, each rendered with
/// obers_ui's `OiAuthPage`. The callbacks return `true` on success so the
/// auth screen can advance; wire them to your backend (or the seeded users
/// in a demo).
///
/// ```dart
/// BeakAuthConfig(
///   onLogin: (email, password) async => email == 'demo@beak.dev',
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
}
