import '../common/beak_exception.dart';
import '../columns/beak_semantic.dart';
import '../query/beak_record.dart';
import '../validation/beak_validation.dart';
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
