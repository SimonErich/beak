import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:serverpod/serverpod.dart' show Session, Transaction, UuidValue;

import 'beak_serverpod.dart';

/// One admin write a model's server handler runs.
///
/// Beak has already checked permissions, admission and rules. The write runs
/// inside the request's transaction: pass [transaction] to every use case and
/// ORM call, so they join Beak's commit. An exception goes through the
/// engine's `mapException`.
///
/// `beak generate` wraps it per model (`VoucherWrite`), adding the record's
/// values typed as Serverpod reads them.
final class BeakServerpodWrite {
  /// Wraps the operation Beak is saving.
  const BeakServerpodWrite(this.context);

  /// The operation, as Beak's save pipeline hands it over.
  final BeakSaveOperationContext context;

  /// The request's Serverpod session.
  Session get session => BeakServerpod.sessionOf(context.transaction.adapter);

  /// The Serverpod transaction Beak's save runs in.
  Transaction get transaction =>
      BeakServerpod.transactionOf(context.transaction.adapter);

  /// What is being saved: a create, an update (a command is one too) or a
  /// delete.
  BeakSaveOperationKind get kind => context.operation.kind;

  /// Who is saving.
  BeakPrincipal? get principal => context.principal;

  /// The record's id. A create carries the id Beak generated for it.
  Object? get id => context.id ?? context.model.primaryKeyOf(values);

  /// [id] as a Serverpod `UuidValue`.
  ///
  /// Throws a [BeakValidationException] when the id is not a UUID.
  UuidValue get uuid => BeakServerpodValues.uuid(id);

  /// The record after the write: the stored values with the change laid over.
  BeakRecord get values => context.merged;

  /// Only what the caller sent.
  BeakRecord get changes => context.values;

  /// The stored record, or `null` for a create.
  BeakRecord? get existing => context.existing;

  /// The typed input of the command this save runs (a `@CommandInput`
  /// model's values), empty without one.
  BeakRecord get arguments => context.plan.arguments;

  /// Whether this save runs [action].
  bool runs(BeakModelAction action) => context.plan.runs(action);
}

/// Conversions from Beak's stored values to Serverpod's types.
abstract final class BeakServerpodValues {
  /// [value] (a `UuidValue` or its text) as a `UuidValue`.
  ///
  /// Throws a [BeakValidationException] when it is not a UUID.
  static UuidValue uuid(Object? value) {
    if (value is UuidValue) return value;
    if (value is String) {
      try {
        return UuidValue.withValidation(value);
      } on FormatException {
        throw const BeakValidationException('Not a valid record id.');
      }
    }
    throw const BeakValidationException('Not a valid record id.');
  }

  /// [value] as a `UuidValue`, or `null` when there is none.
  static UuidValue? uuidOrNull(Object? value) =>
      value == null ? null : uuid(value);
}

/// Every server handler a generated admin passes to the engine.
///
/// `beak generate` implements it (`QateryAdminHandlers`), with one required
/// handler per model whose definition opens custom code, so a missing one
/// does not compile.
abstract interface class BeakServerpodHandlers {
  /// The write handler of every writable model, or `null` when nothing is
  /// written.
  BeakWriteBindings<Enum>? get writes;

  /// The row scopes of the models with a custom list.
  List<BeakRowScope> get scopes;
}

/// Binds [commands] of [model] to their handlers.
///
/// Throws a [BeakConfigurationException] when the model's behavior does not
/// declare one of them, which the engine raises when it starts.
Map<BeakModelAction, BeakDomainWrite> beakServerpodCommands(
  BeakModel model,
  Map<String, BeakDomainWrite> commands,
) {
  final declared = {
    for (final action in model.behavior.actions) action.name: action,
  };
  return {
    for (final MapEntry(key: name, value: write) in commands.entries)
      (declared[name] ??
              (throw BeakConfigurationException(
                'The server handler of "${model.table}" runs the command '
                '"$name", which the model\'s behavior does not declare.',
              ))):
          write,
  };
}

/// Refuses a plain update of a model whose changes run only through its
/// commands.
Future<Object?> beakServerpodRefused(BeakSaveOperationContext context) =>
    throw BeakValidationException(
      '"${context.model.table}" changes only through its commands.',
    );
