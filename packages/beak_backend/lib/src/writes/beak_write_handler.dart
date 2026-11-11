import 'dart:async';

import 'package:beak_core/beak_core.dart';

import '../service/beak_graph_commit_service.dart';

/// Computes trusted scalar values a server stamps on a record it saves, or
/// `null` for none.
///
/// Runs for a create or an update, after the caller's input passed policy,
/// field, scope and revision checks and before ordinary persistence. The
/// values are merged over the validated input, validated again and written by
/// the stock path, so a stamp such as "who published this, and when" needs no
/// persistence code of its own. Values the caller may not write are fine here:
/// a derived value is the server's.
///
/// ```dart
/// BeakRecord? stampPublication(BeakSaveOperationContext context) =>
///     context.plan.runs(MenuActions.publish)
///     ? const MenuModel().record([
///         MenuModel.publishedAt.to(DateTime.now().toUtc()),
///         MenuModel.publishedBy.to(context.principal?.id),
///       ])
///     : null;
/// ```
typedef BeakDeriveValues =
    FutureOr<BeakRecord?> Function(BeakSaveOperationContext context);

/// Delegates one authorized operation to an existing use case, in the
/// transaction of the save.
///
/// Returns the primary key of the record the use case created or changed, and
/// Beak reads it back inside the transaction. Returns `null` when nothing is
/// left to read back, which is the right answer for a delete.
typedef BeakDomainWrite =
    Future<Object?> Function(BeakSaveOperationContext context);

/// What a [BeakWriteHandler.commands] handler does with an operation none of
/// its handlers claims.
enum BeakUnmatched {
  /// Persist it the stock way. Right for a model whose domain commands are
  /// extras on top of ordinary editing.
  stock,

  /// Refuse it with a validation error. Right for a model whose use cases own
  /// every change: nothing can reach its tables through plain persistence.
  refuse,
}

/// How the writes of one write binding are persisted.
///
/// A generated model names its binding in `admission.write`, an enum value of
/// the project. The server maps each value to one handler in a
/// [BeakWriteBindings]:
///
/// ```dart
/// final writes = BeakWriteBindings<ShopWrite>(
///   (binding) => switch (binding) {
///     ShopWrite.configuration => const BeakWriteHandler.stock(),
///     ShopWrite.menu => const BeakWriteHandler.derive(stampPublication),
///     ShopWrite.order => BeakWriteHandler.commands(
///       actions: {OrderActions.cancel: cancelOrder},
///       otherwise: BeakUnmatched.refuse,
///     ),
///   },
/// );
/// ```
///
/// The `switch` has no default, so adding a value to the enum is a compile
/// error until it has a handler.
sealed class BeakWriteHandler {
  const BeakWriteHandler();

  /// Ordinary persistence: what the client sent, after validation.
  ///
  /// The right handler for configuration records without side effects.
  const factory BeakWriteHandler.stock() = _Stock;

  /// Ordinary persistence with trusted values stamped by [derive].
  ///
  /// Only a create or an update is derived; a delete, attach or detach is
  /// persisted the stock way.
  const factory BeakWriteHandler.derive(BeakDeriveValues derive) = _Derive;

  /// Domain writes for the operations a use case owns.
  ///
  /// - [actions] bind a command of the model to its use case. A plan that runs
  ///   one of them must be a bare command (see
  ///   [BeakSaveOperationContext.requireCommandOnly]), and the write is the
  ///   only thing that happens: nothing else runs for that operation.
  /// - [create], [update] and [delete] take over those operations when no
  ///   command is running.
  /// - [derive] stamps trusted values on a create or an update no handler
  ///   above claims, which then persists the stock way.
  /// - [otherwise] decides what happens to an operation nothing claimed: the
  ///   stock path, or a refusal. Use [BeakUnmatched.refuse] on a model whose
  ///   use cases own every change.
  const factory BeakWriteHandler.commands({
    Map<BeakModelAction, BeakDomainWrite> actions,
    BeakDomainWrite? create,
    BeakDomainWrite? update,
    BeakDomainWrite? delete,
    BeakDeriveValues? derive,
    BeakUnmatched otherwise,
  }) = _Commands;

  /// The names of the commands this handler binds to a use case.
  Set<String> get actionNames => const {};

  /// Runs [context] through this handler; `null` means "persist it the stock
  /// way".
  Future<BeakSaveOperationWrite?> run(BeakSaveOperationContext context);
}

final class _Stock extends BeakWriteHandler {
  const _Stock();

  @override
  Future<BeakSaveOperationWrite?> run(BeakSaveOperationContext context) async =>
      null;
}

Future<BeakSaveOperationWrite?> _derived(
  BeakDeriveValues? derive,
  BeakSaveOperationContext context,
) async {
  final kind = context.operation.kind;
  if (derive == null ||
      (kind != BeakSaveOperationKind.create &&
          kind != BeakSaveOperationKind.update)) {
    return null;
  }
  final values = await derive(context);
  return values == null ? null : BeakSaveOperationWrite.withValues(values);
}

final class _Derive extends BeakWriteHandler {
  const _Derive(this.derive);

  final BeakDeriveValues derive;

  @override
  Future<BeakSaveOperationWrite?> run(BeakSaveOperationContext context) =>
      _derived(derive, context);
}

final class _Commands extends BeakWriteHandler {
  const _Commands({
    this.actions = const {},
    this.create,
    this.update,
    this.delete,
    this.derive,
    this.otherwise = BeakUnmatched.stock,
  });

  final Map<BeakModelAction, BeakDomainWrite> actions;
  final BeakDomainWrite? create;
  final BeakDomainWrite? update;
  final BeakDomainWrite? delete;
  final BeakDeriveValues? derive;
  final BeakUnmatched otherwise;

  @override
  Set<String> get actionNames => {
    for (final action in actions.keys) action.name,
  };

  @override
  Future<BeakSaveOperationWrite?> run(BeakSaveOperationContext context) async {
    final command = _command(context);
    if (command != null) {
      context.requireCommandOnly();
      return _persisted(await command(context));
    }
    final write = switch (context.operation.kind) {
      BeakSaveOperationKind.create => create,
      BeakSaveOperationKind.update => update,
      BeakSaveOperationKind.delete => delete,
      _ => null,
    };
    if (write != null) return _persisted(await write(context));
    if (await _derived(derive, context) case final BeakSaveOperationWrite d) {
      return d;
    }
    return switch (otherwise) {
      BeakUnmatched.stock => null,
      BeakUnmatched.refuse => throw BeakValidationException(
        '"${context.model.table}" changes only through its domain commands.',
      ),
    };
  }

  // The bound use case of the command this plan runs, when the command is one
  // of the operation's own model.
  BeakDomainWrite? _command(BeakSaveOperationContext context) {
    final running = context.plan.action;
    if (running == null ||
        !context.model.behavior.actions.any((a) => a.name == running)) {
      return null;
    }
    for (final MapEntry(:key, :value) in actions.entries) {
      if (key.name == running) return value;
    }
    return null;
  }

  static BeakSaveOperationWrite _persisted(Object? id) => id == null
      ? const BeakSaveOperationWrite()
      : BeakSaveOperationWrite.persisted(id);
}
