import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the card-labels resource.
abstract final class CardLabelColumns {
  /// Label name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(40)],
  );

  /// Label color.
  static const color = BeakColorColumn(key: 'color', label: 'Color');

  /// All columns, in display order.
  static const List<BeakColumn> values = [SharedColumns.id, name, color];
}

/// Typed relationships of the card-labels resource.
abstract final class CardLabelRelations {
  /// Cards carrying this label, via the `card_card_label` pivot.
  static const cards = BeakBelongsToMany(
    key: 'cards',
    label: 'Cards',
    relatedTable: 'cards',
    displayColumnKey: 'title',
    pivotTable: 'card_card_label',
    foreignPivotKey: 'card_label_id',
    relatedPivotKey: 'card_id',
  );
}

/// The card-labels resource — colored kanban tags.
final class CardLabelModel extends BeakModel {
  /// Creates the card-labels model.
  const CardLabelModel();

  @override
  String get table => 'card_labels';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => CardLabelColumns.values;

  @override
  List<BeakRelationship> get relationships => const [CardLabelRelations.cards];
}
