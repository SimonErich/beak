import '../common/beak_exception.dart';
import '../columns/beak_semantic.dart';
import '../query/beak_record.dart';
import '../validation/beak_validation.dart';
import 'beak_definitions.dart';
import 'beak_model.dart';

/// The app-level index of every registered [BeakModel], keyed by table name.
///
/// A single instance is created by the application and handed to
/// `beak_backend` and `beak_frontend`, which resolve models by table when
/// serving or rendering resources.
///
/// ```dart
/// final registry = BeakModelRegistry()
///   ..register(const ProductModel())
///   ..register(const OrderModel())
///   ..register(const TagModel());
///
/// final products = registry.byTableOrThrow('products');
/// ```
final class BeakModelRegistry {
  /// Creates an empty registry.
  BeakModelRegistry();

  /// Builds a registry holding [models], after binding [definitions].
  ///
  /// The generated barrel of a project calls this for its models, so a host
  /// writes one line to get a registry whose generated models resolve their
  /// authored behavior and rules:
  ///
  /// ```dart
  /// final registry = BeakModelRegistry.of(
  ///   shopModels,
  ///   definitions: shopDefinitions,
  /// );
  /// ```
  ///
  /// [definitions] are bound first (see [BeakDefinitions.bind]: binding the
  /// same set again is a no-op, a different set throws) and every model is
  /// registered afterwards, so registration already sees the bound behavior.
  /// Leave [definitions] out when they were bound earlier, or when no model
  /// resolves its behavior through them.
  ///
  /// Throws a [BeakConfigurationException] when [definitions] hold an entry for
  /// a table none of [models] owns (nothing is bound then), when two models
  /// share a table, or when a model fails registration.
  factory BeakModelRegistry.of(
    Iterable<BeakModel> models, {
    BeakDefinitions? definitions,
  }) {
    if (definitions != null) {
      final tables = {for (final model in models) model.table};
      for (final definition in definitions.all) {
        if (!tables.contains(definition.model.table)) {
          throw BeakConfigurationException(
            'A definition names the table "${definition.model.table}", which '
            'is not one of the registered models. Remove it, or add the '
            'model to the registry.',
          );
        }
      }
      BeakDefinitions.bind(definitions);
    }
    final registry = BeakModelRegistry();
    for (final model in models) {
      registry.register(model);
    }
    return registry;
  }

  final Map<String, BeakModel> _modelsByTable = {};

  /// Registers [model] under its table name.
  ///
  /// Throws a [BeakConfigurationException] when a model for the same table
  /// is already registered — every table maps to exactly one model.
  void register(BeakModel model) {
    if (_modelsByTable.containsKey(model.table)) {
      throw BeakConfigurationException(
        'A model for table "${model.table}" is already registered.',
      );
    }
    if (model.columnByKey(model.displayColumnKey)?.semantic.kind ==
        BeakSemanticKind.password) {
      throw BeakConfigurationException(
        'Model "${model.table}" cannot use a password as its display column.',
      );
    }
    model.behavior.validate(model);
    final commands = {for (final action in model.behavior.actions) action.name};
    for (final name in model.permissions.actions.keys) {
      if (!commands.contains(name)) {
        throw BeakConfigurationException(
          'Model "${model.table}" grants access to the action "$name", which '
          'its behavior does not declare.',
        );
      }
    }
    const validation = BeakValidation();
    final defaults = validation.applyDefaults(
      model,
      const BeakRecord(values: {}),
    );
    for (final column in model.columns) {
      if (column.defaultValue == null) continue;
      final errors = validation.columnErrors(column, defaults[column.key]?.raw);
      if (errors.isNotEmpty) {
        throw BeakConfigurationException(
          'Invalid default for ${model.table}.${column.key}: ${errors.join(' ')}',
        );
      }
    }
    _modelsByTable[model.table] = model;
  }

  /// The model registered for [table], or `null` when none is.
  BeakModel? byTable(String table) => _modelsByTable[table];

  /// The model registered for [table].
  ///
  /// Throws a [BeakConfigurationException] when no model is registered —
  /// use this at request-handling boundaries where an unknown table is a
  /// setup error, not a lookup miss.
  BeakModel byTableOrThrow(String table) {
    final model = byTable(table);
    if (model == null) {
      throw BeakConfigurationException(
        'No model registered for table "$table".',
      );
    }
    return model;
  }

  /// Every registered model, in registration order.
  List<BeakModel> get all => List.unmodifiable(_modelsByTable.values);
}
