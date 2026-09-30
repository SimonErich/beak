import '../common/beak_exception.dart';
import '../model/beak_field_ref.dart';
import '../model/beak_model.dart';
import '../query/beak_record.dart';
import '../query/beak_relation_load.dart';
import '../query/beak_value.dart';

/// When a declared value is evaluated.
enum BeakValueLifecycle {
  /// Supply an omitted value on creation.
  initial,

  /// Follow dependencies until the user supplies an override.
  suggested,

  /// Always recompute; the client cannot author this field.
  derived,

  /// Freeze a value when a named action executes.
  snapshot,
}

/// Immutable inputs to a shared value calculation. Callbacks must be pure.
final class BeakValueContext {
  /// Builds the inputs used identically by form previews and server writes.
  const BeakValueContext({
    required this.record,
    this.initial,
    this.arguments = const BeakRecord(values: {}),
  });

  /// Proposed record, including previously evaluated dependencies.
  final BeakRecord record;

  /// Stored record before this edit, absent for new records.
  final BeakRecord? initial;

  /// Validated input of the named action, when one is executing.
  final BeakRecord arguments;

  /// Reads a typed field from the proposed record.
  T? read<T extends Object>(BeakFieldRef<T> field) => field.readFrom(record);

  /// Reads a typed field before this edit.
  T? original<T extends Object>(BeakFieldRef<T> field) =>
      initial == null ? null : field.readFrom(initial!);

  /// Reads a typed field from the action's input model.
  T? argument<T extends Object>(BeakFieldRef<T> field) =>
      field.readFrom(arguments);
}

/// A typed value definition shared by presentation and authoritative writes.
final class BeakValueBehavior<T extends Object> {
  /// Supplies an omitted value on creation, preserving explicit nulls.
  const BeakValueBehavior.initial({
    required this.field,
    required this.resolve,
    this.dependencies = const [],
  }) : lifecycle = BeakValueLifecycle.initial,
       onAction = null;

  /// Follows dependencies unless the field has been explicitly overridden.
  ///
  /// Existing values different from the original calculated suggestion count as
  /// overrides. [BeakModelBehavior.apply]'s overriddenFields records manual edits
  /// within an unsaved session, including deliberate null overrides.
  const BeakValueBehavior.suggested({
    required this.field,
    required this.resolve,
    this.dependencies = const [],
  }) : lifecycle = BeakValueLifecycle.suggested,
       onAction = null;

  /// Recomputes a read-only field for every save or preview.
  const BeakValueBehavior.derived({
    required this.field,
    required this.resolve,
    this.dependencies = const [],
  }) : lifecycle = BeakValueLifecycle.derived,
       onAction = null;

  /// Computes a read-only historical value only during [onAction].
  ///
  /// [onAction] is the declared command itself, never its name, so renaming it
  /// cannot leave a dangling reference behind.
  const BeakValueBehavior.snapshot({
    required this.field,
    required this.resolve,
    required BeakModelAction this.onAction,
    this.dependencies = const [],
  }) : lifecycle = BeakValueLifecycle.snapshot;

  /// Field whose value this declaration owns.
  final BeakScalarField<T> field;

  /// Pure calculation; use declared dependencies for load inference and order.
  final T? Function(BeakValueContext context) resolve;

  /// Fields read by [resolve], in any declaration order.
  final List<BeakFieldRef<Object>> dependencies;

  /// Evaluation and override semantics.
  final BeakValueLifecycle lifecycle;

  /// The command whose execution triggers a snapshot.
  final BeakModelAction? onAction;

  /// Encoded result used without erasing the callback's value type.
  BeakValue evaluate(BeakValueContext context) =>
      field.encode(resolve(context));
}

/// A named transactionally executed command on one record.
///
/// The same declaration supplies UI labels, allowed states and typed input.
/// [values] declares authoritative field changes; custom graph preparation may
/// derive additional writes, which retain ordinary per-record authorization.
///
/// Declare each command once, then refer to that object everywhere: a form's
/// submit action, a list's row and bulk actions, a snapshot's trigger, and a
/// server preparer's `plan.runs(...)`. The [name] is only the identity the
/// command carries over the wire, so no caller ever writes it:
///
/// ```dart
/// abstract final class OrderActions {
///   static final place = BeakModelAction(
///     name: 'place',
///     label: 'Place order',
///     allowOnCreate: true,
///   );
/// }
/// ```
final class BeakModelAction {
  /// Defines a command. Names must be unique within a model.
  const BeakModelAction({
    required this.name,
    required this.label,
    this.description,
    this.availableWhen,
    this.inputModel,
    this.allowOnCreate = false,
    this.values = const [],
  });

  /// Stable wire identity, independent of translated labels.
  final String name;

  /// Human-readable command label.
  final String label;

  /// Optional explanation used by confirmation and input surfaces.
  final String? description;

  /// Allowed-state predicate, evaluated against the persisted record.
  final bool Function(BeakRecord record)? availableWhen;

  /// Typed command inputs, using normal columns, defaults and validation rules.
  final BeakModel? inputModel;

  /// Whether a create graph may execute this command atomically.
  final bool allowOnCreate;

  /// Field changes applied before model calculations and snapshots.
  final List<BeakValueBehavior<Object>> values;

  /// Whether the command is currently available.
  bool isAvailable(BeakRecord record) => availableWhen?.call(record) ?? true;
}

/// Shared value lifecycles and business operations belonging to a model.
final class BeakModelBehavior {
  /// Configures behavior without a separate registration mechanism.
  const BeakModelBehavior({
    this.values = const [],
    this.actions = const [],
    this.editableWhen,
    this.deletableWhen,
  });

  /// Default, suggested, calculated and historical fields.
  final List<BeakValueBehavior<Object>> values;

  /// Business commands supported by the model.
  final List<BeakModelAction> actions;

  /// Whether ordinary fields can change, evaluated against the stored record.
  final bool Function(BeakRecord record)? editableWhen;

  /// Whether records may be removed, evaluated against the stored record.
  final bool Function(BeakRecord record)? deletableWhen;

  /// Related data needed by live calculations and suggestions.
  /// These paths also identify inverse records affected by a related edit.
  List<BeakRelationLoad> get relationLoads => [
    for (final value in values.where(
      (value) =>
          value.lifecycle == BeakValueLifecycle.derived ||
          value.lifecycle == BeakValueLifecycle.suggested,
    ))
      for (final field in value.dependencies) ?_load(field),
  ];

  static BeakRelationLoad? _load(BeakFieldRef<Object> field) {
    final path = [
      ...field.path,
      if (field is BeakToOneField) field.relation,
      if (field is BeakToManyField) field.relation,
    ];
    BeakRelationLoad? result;
    for (final relation in path.reversed) {
      result = BeakRelationLoad(relation.key, nested: [?result]);
    }
    return result;
  }

  /// Whether authoritative graph preparation is required.
  bool get isEmpty =>
      values.isEmpty &&
      actions.isEmpty &&
      editableWhen == null &&
      deletableWhen == null;

  /// Resolves a command received over the wire by its [BeakModelAction.name],
  /// rejecting an undeclared one.
  ///
  /// Application code holds the [BeakModelAction] itself and never needs this.
  BeakModelAction action(String name) => actions.firstWhere(
    (action) => action.name == name,
    orElse: () => throw BeakConfigurationException('Unknown action "$name".'),
  );

  /// Whether an ordinary editor may author this field.
  bool canEdit(String key, BeakRecord record) =>
      (editableWhen?.call(record) ?? true) &&
      !values.any(
        (value) =>
            value.field.key == key &&
            (value.lifecycle == BeakValueLifecycle.derived ||
                value.lifecycle == BeakValueLifecycle.snapshot),
      ) &&
      !actions.any(
        (action) => action.values.any((value) => value.field.key == key),
      );

  /// Rejects direct edits to locked fields and action-controlled state.
  /// Derived values are recomputed, so untrusted supplied values are harmless.
  void validateEdits(
    BeakRecord record, {
    BeakRecord? initial,
    String? actionName,
    bool isCreate = false,
  }) {
    if (initial == null) return;
    final commanded = actionName == null
        ? const <String>{}
        : {
            for (final value in action(actionName).values) value.field.key,
            for (final value in values.where(
              (value) => value.onAction?.name == actionName,
            ))
              value.field.key,
          };
    final derived = {
      for (final value in values.where(
        (value) => value.lifecycle == BeakValueLifecycle.derived,
      ))
        value.field.key,
    };
    final errors = <String, List<String>>{};
    for (final entry in record.values.entries) {
      if (entry.value == initial[entry.key] ||
          (entry.value.raw == null && initial[entry.key]?.raw == null) ||
          derived.contains(entry.key)) {
        continue;
      }
      final initialInput =
          isCreate &&
          !initial.values.containsKey(entry.key) &&
          !values.any(
            (value) =>
                value.field.key == entry.key &&
                value.lifecycle == BeakValueLifecycle.snapshot,
          );
      if (initialInput) continue;
      if (!commanded.contains(entry.key) && !canEdit(entry.key, initial)) {
        errors[entry.key] = [
          'This field is controlled by the record workflow.',
        ];
      }
    }
    if (errors.isNotEmpty) {
      throw BeakValidationException(
        'The record cannot be edited in this state.',
        fieldErrors: errors,
      );
    }
  }

  /// Supplies only initial values, without running calculations on absent inputs.
  BeakRecord initialize(BeakRecord record) {
    var current = record;
    for (final value in _ordered(
      values
          .where((value) => value.lifecycle == BeakValueLifecycle.initial)
          .toList(),
    )) {
      if (!current.values.containsKey(value.field.key)) {
        current = _put(
          current,
          value.field.key,
          value.evaluate(BeakValueContext(record: current)),
        );
      }
    }
    return current;
  }

  /// Evaluates the declared dependency graph without mutating inputs.
  ///
  /// [overriddenFields] is explicit user input, never automatically calculated
  /// values. Unmodified suggestions follow their declared dependencies.
  BeakRecord apply(
    BeakRecord record, {
    BeakRecord? initial,
    Set<String> overriddenFields = const {},
    String? action,
    BeakRecord arguments = const BeakRecord(values: {}),
  }) {
    var current = record;
    BeakValueContext context() => BeakValueContext(
      record: current,
      initial: initial,
      arguments: arguments,
    );
    if (action != null) {
      final command = this.action(action);
      if (!command.isAvailable(initial ?? record)) {
        throw const BeakValidationException(
          'This action is unavailable in the current state.',
        );
      }
      for (final value in _ordered(command.values)) {
        current = _put(current, value.field.key, value.evaluate(context()));
      }
    }
    for (final value in _ordered(values)) {
      final key = value.field.key;
      final shouldApply = switch (value.lifecycle) {
        BeakValueLifecycle.initial =>
          initial == null && !current.values.containsKey(key),
        BeakValueLifecycle.derived => true,
        BeakValueLifecycle.snapshot => action == value.onAction?.name,
        BeakValueLifecycle.suggested =>
          !overriddenFields.contains(key) &&
              (initial == null ||
                  !initial.values.containsKey(key) ||
                  initial[key] ==
                      value.evaluate(
                        BeakValueContext(record: initial, initial: initial),
                      )),
      };
      if (shouldApply) current = _put(current, key, value.evaluate(context()));
    }
    return current;
  }

  /// Validates ownership, action names and dependency cycles at registration.
  void validate(BeakModel model) {
    final names = <String>{};
    for (final command in actions) {
      if (command.name.isEmpty || !names.add(command.name)) {
        throw const BeakConfigurationException(
          'Action names must be nonempty and unique.',
        );
      }
    }
    for (final value in [
      ...values,
      for (final action in actions) ...action.values,
    ]) {
      if (value.field.path.isNotEmpty ||
          value.field.model.table != model.table ||
          model.columnByKey(value.field.key) == null) {
        throw BeakConfigurationException(
          'Behavior field "${value.field.qualifiedKey}" must belong to ${model.table}.',
        );
      }
      if (value.onAction case final BeakModelAction snapshotAction
          when !names.contains(snapshotAction.name)) {
        throw BeakConfigurationException(
          'Snapshot refers to unknown action "${snapshotAction.name}".',
        );
      }
      for (final dependency in value.dependencies) {
        if (dependency.model.table != model.table) {
          throw BeakConfigurationException(
            'Behavior dependencies must be rooted at ${model.table}.',
          );
        }
      }
    }
    _ordered(values);
    for (final action in actions) {
      _ordered(action.values);
    }
  }

  static BeakRecord _put(BeakRecord record, String key, BeakValue value) =>
      BeakRecord(
        values: {...record.values, key: value},
        relations: record.relations,
      );

  static List<BeakValueBehavior<Object>> _ordered(
    List<BeakValueBehavior<Object>> values,
  ) {
    final byKey = <String, BeakValueBehavior<Object>>{};
    for (final value in values) {
      if (byKey.containsKey(value.field.key)) {
        throw BeakConfigurationException(
          'Duplicate behavior for "${value.field.key}".',
        );
      }
      byKey[value.field.key] = value;
    }
    final visiting = <String>{};
    final visited = <String>{};
    final result = <BeakValueBehavior<Object>>[];
    void visit(BeakValueBehavior<Object> value) {
      final key = value.field.key;
      if (visited.contains(key)) return;
      if (!visiting.add(key)) {
        throw BeakConfigurationException('Value dependency cycle at "$key".');
      }
      for (final dependency in value.dependencies) {
        if (dependency.path.isEmpty) {
          final next = byKey[dependency.key];
          if (next != null) visit(next);
        }
      }
      visiting.remove(key);
      visited.add(key);
      result.add(value);
    }

    for (final value in values) {
      visit(value);
    }
    return result;
  }
}
