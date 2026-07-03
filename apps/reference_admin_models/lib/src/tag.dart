import 'package:beak_core/beak_core.dart';

/// Typed column constants of the tags resource.
abstract final class TagColumns {
  /// Primary key.
  static const id = BeakStringColumn(
    key: 'id',
    label: 'Id',
    visibleOn: {BeakContext.detail},
  );

  /// Display name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(60)],
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [id, name];
}

/// The tags resource: free-form labels attached to products.
final class TagModel extends BeakModel {
  /// Creates the tags model.
  const TagModel();

  @override
  String get table => 'tags';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => TagColumns.values;
}
