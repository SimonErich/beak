import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

/// The generic worm model every Beak-managed table hydrates into.
///
/// Beak models are metadata-only, so one runtime-configured worm model
/// serves every registered table — no per-model codegen. Rows hydrate into
/// attribute state; eager-loaded relations (also [WormRecordModel]s) convert
/// recursively via [toBeakRecord].
final class WormRecordModel extends Model {
  /// Hydrates a [row] of [table] (keyed by [primaryKeyColumn]).
  WormRecordModel.fromRow(
    this._table,
    this._primaryKeyColumn,
    Map<String, Object?> row,
  ) : _columnNames = List.unmodifiable(row.keys) {
    row.forEach(hydrateAttribute);
    markPersisted();
  }

  final String _table;
  final String _primaryKeyColumn;
  final List<String> _columnNames;

  @override
  String get tableName => _table;

  @override
  String get primaryKeyColumn => _primaryKeyColumn;

  @override
  Object get id => getAttribute(_primaryKeyColumn) ?? '';

  @override
  Map<String, Object?> toRow() => {
    for (final name in _columnNames) name: getAttribute(name),
  };

  /// This row as a typed [BeakRecord], converting the relations loaded for
  /// [loads] recursively (a requested-but-unloaded relation throws, honoring
  /// Beak's no-lazy-loading rule).
  BeakRecord toBeakRecord({List<BeakRelationLoad> loads = const []}) =>
      BeakRecord(
        values: {
          for (final name in _columnNames)
            name: BeakValue.of(getAttribute(name)),
        },
        relations: {
          for (final load in loads) load.relationKey: _relatedRecords(load),
        },
      );

  List<BeakRecord> _relatedRecords(BeakRelationLoad load) {
    final List<Object?>? children;
    try {
      children = getRelation<List<Object?>>(load.relationKey);
    } on RelationNotLoadedException {
      // The load ran, but worm skips installing a relation key when no
      // parent had anything to load (e.g. every foreign key was null) —
      // for a requested load that simply means "empty".
      return const [];
    }
    if (children != null) {
      return [
        for (final child in children)
          if (child is WormRecordModel) child.toBeakRecord(loads: load.nested),
      ];
    }
    final WormRecordModel? single = getRelation<WormRecordModel>(
      load.relationKey,
    );
    return [if (single != null) single.toBeakRecord(loads: load.nested)];
  }
}
