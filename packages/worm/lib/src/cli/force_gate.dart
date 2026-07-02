/// Helpers and the [ProductionGuard] class for `--force` enforcement
/// on destructive CLI commands.
library;

import 'dart:io' as io;

import 'cli_context.dart';

/// Signature of the exit function consumed by [ProductionGuard].
///
/// Declared as `void` (rather than `Never`) so test doubles that
/// simply record the requested code are statically assignable;
/// `dart:io`'s real `exit` is a `Never Function(int)` and remains a
/// valid subtype.
typedef ExitFn = void Function(int code);

/// Returns `true` when [raw] (typically `Platform.environment['WORM_ENV']`)
/// names the production environment, **case-insensitively**.
///
/// Whitespace is trimmed before comparison. `null`, empty strings, and
/// any other recognised environment (`development`, `staging`,
/// `testing`, …) return `false`. Pure function — safe to call in
/// unit tests without spawning a real process.
bool isProductionWormEnv(String? raw) {
  if (raw == null) return false;
  return raw.trim().toLowerCase() == 'production';
}

/// Bool-returning helper used by commands that want to translate a
/// failed `--force` check into a non-zero exit code rather than
/// terminating the process via `dart:io` exit.
///
/// Returns `true` when the command may proceed (non-production or
/// production with `--force`); returns `false` after writing a
/// diagnostic to [CliContext.err] when the command must abort.
bool ensureForceForProduction({
  required CliContext context,
  required bool force,
}) {
  if (!context.isProduction) return true;
  if (force) return true;
  context.err.writeln(_forceMissingMessage);
  return false;
}

/// Process-aware production guard with an injectable exit hook.
///
/// Used where the AC contract is "calls `exit(1)`" rather than
/// "returns non-zero". The injected [ExitFn] makes the class testable
/// without terminating the test process — production code uses the
/// default `dart:io` exit; tests pass a fake that throws or records.
final class ProductionGuard {
  /// Creates a [ProductionGuard] bound to [context].
  ///
  /// [exit] defaults to `dart:io`'s `exit`.
  ProductionGuard({required this.context, ExitFn? exit})
    : _exit = exit ?? io.exit;

  /// Shared CLI execution context (drives [isProduction]).
  final CliContext context;

  final ExitFn _exit;

  /// Whether the active environment is production. Resolved via the
  /// [CliContext] which sources `WORM_ENV` through `Worm.environment`
  /// (case-insensitive parsing).
  bool isProduction() => context.isProduction;

  /// Verifies a destructive command is allowed to proceed.
  ///
  /// * Non-production → returns immediately.
  /// * Production with `force: true` → returns immediately.
  /// * Production without `--force` → writes a diagnostic to
  ///   [CliContext.err] and calls the injected exit with code `1`.
  ///   The real `dart:io` exit never returns; test fakes may return
  ///   for assertion purposes.
  void enforceForce({required bool force}) {
    if (!isProduction()) return;
    if (force) return;
    context.err.writeln(_forceMissingMessage);
    _exit(1);
  }
}

const String _forceMissingMessage =
    'error: refusing to run destructive command in production '
    'without --force';
