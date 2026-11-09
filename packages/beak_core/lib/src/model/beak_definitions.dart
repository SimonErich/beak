import 'package:meta/meta.dart';

import '../behavior/beak_model_behavior.dart';
import '../common/beak_exception.dart';
import '../validation/beak_record_rule.dart';
import 'beak_model.dart';

/// The authored side of one generated model: its behavior and its rules.
///
/// A generated model carries only facts a generator can know. Everything a
/// person writes (value lifecycles, workflow guards, commands, cross-field
/// rules) lives in a definition, next to the model it belongs to:
///
/// ```dart
/// final menuDefinition = BeakModelDefinition(
///   const MenuModel(),
///   behavior: BeakModelBehavior(
///     deletableWhen: (record) => MenuModel.isLocked.readFrom(record) != true,
///   ),
/// );
/// ```
///
/// Collect the definitions in a [BeakDefinitions] and bind them once at
/// startup.
@immutable
final class BeakModelDefinition<M extends BeakModel> {
  /// Defines [model] with its [behavior] and validation [rules].
  const BeakModelDefinition(
    this.model, {
    this.behavior = const BeakModelBehavior(),
    this.rules = const [],
  });

  /// The model this definition belongs to.
  final M model;

  /// Value lifecycles, workflow guards and commands of [model].
  final BeakModelBehavior behavior;

  /// Shared validation rules of [model], beyond its column rules.
  final List<BeakRecordRule> rules;
}

/// The authored definitions of a set of models, keyed by table.
///
/// Generated models read their behavior and rules from the bound set instead of
/// importing authored code, so the generated library depends on `beak_core`
/// alone. Bind the set once per isolate, before the first model registry is
/// built:
///
/// ```dart
/// final definitions = BeakDefinitions([
///   BeakModelDefinition(const MenuModel(), behavior: menuBehavior),
///   BeakModelDefinition(const OrderModel(), rules: orderRules),
/// ]);
///
/// final registry = BeakModelRegistry.of(shopModels, definitions: definitions);
/// ```
///
/// Lookups are strict. Before anything is bound, [behaviorOf] and [rulesOf]
/// throw, so a model that forgot its definitions never runs with the default
/// behavior in place of the one that guards it. Once a set is bound, a model
/// without an entry gets the empty behavior and no rules.
final class BeakDefinitions {
  /// Collects [definitions], keyed by the table of each model.
  ///
  /// Throws a [BeakConfigurationException] when two definitions name the same
  /// table.
  BeakDefinitions(Iterable<BeakModelDefinition<BeakModel>> definitions)
    : _byTable = _index(definitions);

  /// The empty set, for hosts that define nothing: every model keeps the
  /// default behavior and no rules.
  static final BeakDefinitions none = BeakDefinitions(const []);

  final Map<String, BeakModelDefinition<BeakModel>> _byTable;

  static BeakDefinitions? _bound;

  static Map<String, BeakModelDefinition<BeakModel>> _index(
    Iterable<BeakModelDefinition<BeakModel>> definitions,
  ) {
    final byTable = <String, BeakModelDefinition<BeakModel>>{};
    for (final definition in definitions) {
      final table = definition.model.table;
      if (byTable.containsKey(table)) {
        throw BeakConfigurationException(
          'Two definitions name the table "$table". Give each model one '
          'BeakModelDefinition.',
        );
      }
      byTable[table] = definition;
    }
    return Map.unmodifiable(byTable);
  }

  /// The definition of [model], or `null` when this set has none for its
  /// table.
  BeakModelDefinition<BeakModel>? operator [](BeakModel model) =>
      _byTable[model.table];

  /// Every definition in this set, in the order they were given.
  Iterable<BeakModelDefinition<BeakModel>> get all => _byTable.values;

  /// Binds [definitions] for every model in this isolate.
  ///
  /// Bind once, before the first registry is built. Binding the same set
  /// again, as a second registry for the same app does, changes nothing.
  /// Binding a different set throws a [BeakConfigurationException], because
  /// two sets disagreeing about the same models means one of them guards
  /// nothing.
  static void bind(BeakDefinitions definitions) {
    final bound = _bound;
    if (bound == null) {
      _bound = definitions;
      return;
    }
    if (!bound._sameAs(definitions)) {
      throw const BeakConfigurationException(
        'A different set of BeakDefinitions is already bound in this isolate. '
        'Bind one set at startup and reuse it: build the definitions once '
        '(a top-level final) and pass that same instance to every '
        'BeakModelRegistry.of.',
      );
    }
  }

  /// The behavior of [model] under the bound definitions.
  ///
  /// Throws a [BeakConfigurationException] naming [model] when nothing is
  /// bound yet. A model the bound set has no entry for gets the empty
  /// behavior.
  static BeakModelBehavior behaviorOf(BeakModel model) =>
      _requireBound(model)[model]?.behavior ?? const BeakModelBehavior();

  /// The validation rules of [model] under the bound definitions.
  ///
  /// Throws a [BeakConfigurationException] naming [model] when nothing is
  /// bound yet. A model the bound set has no entry for has no rules.
  static List<BeakRecordRule> rulesOf(BeakModel model) =>
      _requireBound(model)[model]?.rules ?? const [];

  static BeakDefinitions _requireBound(BeakModel model) =>
      _bound ??
      (throw BeakConfigurationException(
        'No BeakDefinitions are bound, so the behavior and rules of '
        '"${model.table}" cannot be resolved. Bind them before use: pass '
        '`definitions:` to BeakModelRegistry.of, or call '
        'BeakDefinitions.bind(definitions) at startup (BeakDefinitions.none '
        'when the host defines nothing).',
      ));

  bool _sameAs(BeakDefinitions other) {
    if (identical(this, other)) return true;
    if (_byTable.length != other._byTable.length) return false;
    for (final MapEntry(:key, :value) in _byTable.entries) {
      final counterpart = other._byTable[key];
      if (counterpart == null ||
          !identical(value.model, counterpart.model) ||
          !identical(value.behavior, counterpart.behavior) ||
          !_sameRules(value.rules, counterpart.rules)) {
        return false;
      }
    }
    return true;
  }

  static bool _sameRules(
    List<BeakRecordRule> first,
    List<BeakRecordRule> second,
  ) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (!identical(first[index], second[index])) return false;
    }
    return true;
  }

  /// Forgets the bound set, so the next [bind] starts clean.
  ///
  /// For tests that build more than one registry in a process; production code
  /// binds once and never unbinds.
  @visibleForTesting
  static void unbindForTesting() => _bound = null;

  /// Runs [body] with [definitions] bound, then restores what was bound
  /// before, even when [body] throws.
  ///
  /// [body] must finish synchronously; use [withDefinitionsAsync] when it
  /// awaits.
  ///
  /// ```dart
  /// final registry = BeakDefinitions.withDefinitions(
  ///   definitions,
  ///   () => BeakModelRegistry.of(shopModels, definitions: definitions),
  /// );
  /// ```
  @visibleForTesting
  static T withDefinitions<T>(BeakDefinitions definitions, T Function() body) {
    final previous = _bound;
    _bound = definitions;
    try {
      return body();
    } finally {
      _bound = previous;
    }
  }

  /// The asynchronous form of [withDefinitions]: the previous binding comes
  /// back once the future [body] returns completes.
  @visibleForTesting
  static Future<T> withDefinitionsAsync<T>(
    BeakDefinitions definitions,
    Future<T> Function() body,
  ) async {
    final previous = _bound;
    _bound = definitions;
    try {
      return await body();
    } finally {
      _bound = previous;
    }
  }
}
