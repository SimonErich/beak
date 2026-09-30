import 'package:beak_core/beak_core.dart';
import 'package:signals/signals.dart';

import '../form/beak_form_session.dart';

/// The result of a command, including an unresolved server receipt.
final class BeakModelActionOutcome {
  /// Captures the session outcome without exposing a second form state.
  const BeakModelActionOutcome({
    this.receipt,
    this.error,
    this.cancelled = false,
  });

  /// Authoritative receipt when dispatch or recovery returned one.
  final BeakSaveResult? receipt;

  /// Validation/transport/configuration failure for presentation.
  final BeakException? error;

  /// User closed input confirmation before dispatch.
  final bool cancelled;

  /// Whether this attempt completed all writes.
  bool get complete => receipt?.complete ?? false;
}

/// An unresolved command that remains recoverable from any panel route.
final class BeakPendingModelAction {
  BeakPendingModelAction._(
    this.principal,
    this.model,
    this.recordId,
    this.action,
    this.source,
    this.registry,
  );

  /// Principal that submitted this command.
  final Object? principal;

  /// Root model.
  final BeakModel model;

  /// Root identity.
  final Object recordId;

  /// Shared command metadata.
  final BeakModelAction action;

  /// Original panel transport.
  final BeakDataSource source;

  /// Original model registry.
  final BeakModelRegistry? registry;
}

/// Panel-owned command sessions, coalescing dispatch and retaining uncertainty.
///
/// A second invocation of an unresolved action checks the original receipt;
/// it never generates another save identity. Records are isolated by principal.
final class BeakModelActionRunner {
  final _pending = <(Object?, String, String, String), BeakFormSession>{};
  final _running =
      <(Object?, String, String, String), Future<BeakModelActionOutcome>>{};
  bool _disposed = false;
  final _unresolved = signal<List<BeakPendingModelAction>>([]);

  /// Unresolved commands; consumers must filter by the current principal.
  ReadonlySignal<List<BeakPendingModelAction>> get unresolved => _unresolved;

  /// Confirms/collects inputs once, then uses the existing graph transaction.
  Future<BeakModelActionOutcome> execute({
    required BeakModel model,
    required BeakDataSource source,
    required Object recordId,
    required BeakModelAction action,
    required Future<BeakRecord?> Function(BeakFormSession) prepare,
    Object? principal,
    BeakModelRegistry? registry,
  }) {
    if (_disposed) throw StateError('Command runner was disposed.');
    final key = (principal, model.table, recordId.toString(), action.name);
    return _running[key] ??=
        _execute(
          key,
          model,
          source,
          recordId,
          action,
          prepare,
          registry,
        ).whenComplete(() {
          _running.remove(key);
        });
  }

  Future<BeakModelActionOutcome> _execute(
    (Object?, String, String, String) key,
    BeakModel model,
    BeakDataSource source,
    Object recordId,
    BeakModelAction action,
    Future<BeakRecord?> Function(BeakFormSession) prepare,
    BeakModelRegistry? registry,
  ) async {
    final retained = _pending[key];
    final session =
        retained ??
        BeakFormSession(
          model: model,
          dataSource: source,
          recordId: recordId,
          registry: registry,
        );
    _pending[key] = session;
    try {
      BeakSaveResult? receipt;
      if (session.hasUnknown) {
        await session.recover();
        receipt = session.saveResult.value;
      } else {
        await session.load();
        if (session.error.value case final BeakException error) {
          return BeakModelActionOutcome(error: error);
        }
        if (!session.canExecuteAction(action)) {
          return const BeakModelActionOutcome(
            error: BeakAuthorizationException('This action is not permitted.'),
          );
        }
        final arguments = await prepare(session);
        if (arguments == null || _disposed) {
          return const BeakModelActionOutcome(cancelled: true);
        }
        receipt = await session.executeAction(action, arguments: arguments);
      }
      if (receipt?.complete == true) {
        return BeakModelActionOutcome(receipt: receipt);
      }
      return BeakModelActionOutcome(
        receipt: receipt,
        error: session.hasUnknown
            ? const BeakConflictException(
                'The outcome is not yet known. Run this action again to check its existing receipt; it will not be submitted twice.',
              )
            : session.error.value ??
                  BeakValidationException(
                    session.root.errors.values
                        .expand((messages) => messages)
                        .join(' '),
                  ),
      );
    } finally {
      if (!_disposed) {
        final others = _unresolved
            .peek()
            .where(
              (value) =>
                  (
                    value.principal,
                    value.model.table,
                    value.recordId.toString(),
                    value.action.name,
                  ) !=
                  key,
            )
            .toList();
        _unresolved.value = [
          ...others,
          if (session.hasUnknown)
            BeakPendingModelAction._(
              key.$1,
              model,
              recordId,
              action,
              source,
              registry,
            ),
        ];
      }
      if (_disposed || !session.hasUnknown) {
        _pending.remove(key);
        session.dispose();
      }
    }
  }

  /// Releases the panel's retained sessions at its lifecycle boundary.
  void dispose() {
    _disposed = true;
    for (final session in _pending.values) {
      session.dispose();
    }
    _pending.clear();
    _unresolved.dispose();
  }
}
