import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the event-categories resource.
abstract final class EventCategoryColumns {
  /// Category key, e.g. `business`.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(40)],
  );

  /// Display label.
  static const label = BeakStringColumn(
    key: 'label',
    label: 'Label',
    rules: [BeakRequired(), BeakMaxLength(40)],
  );

  /// Calendar color for events in this category.
  static const color = BeakColorColumn(key: 'color', label: 'Color');

  /// All columns, in display order.
  static const List<BeakColumn> values = [SharedColumns.id, name, label, color];
}

/// Typed relationships of the event-categories resource.
abstract final class EventCategoryRelations {
  /// Events in this category.
  static const events = BeakHasMany(
    key: 'events',
    label: 'Events',
    relatedTable: 'calendar_events',
    displayColumnKey: 'title',
    foreignKey: 'category_id',
  );
}

/// The event-categories resource — colored calendar buckets.
final class EventCategoryModel extends BeakModel {
  /// Creates the event-categories model.
  const EventCategoryModel();

  @override
  String get table => 'event_categories';

  @override
  String get displayColumnKey => 'label';

  @override
  List<BeakColumn> get columns => EventCategoryColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    EventCategoryRelations.events,
  ];
}
