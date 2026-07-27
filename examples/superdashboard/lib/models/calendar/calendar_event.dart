import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the calendar-events resource.
abstract final class CalendarEventColumns {
  /// Event title.
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(160)],
  );

  /// Long-form description.
  static const description = BeakTextColumn(
    key: 'description',
    label: 'Description',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// The category.
  static const categoryId = BeakStringColumn(
    key: 'category_id',
    label: 'Category',
    visibleOn: {BeakContext.form},
  );

  /// The organizing user.
  static const organizerId = BeakStringColumn(
    key: 'organizer_id',
    label: 'Organizer',
    visibleOn: {BeakContext.form},
  );

  /// Start moment.
  static const startAt = BeakDateTimeColumn(
    key: 'start_at',
    label: 'Starts',
    sortable: true,
    rules: [BeakRequired()],
  );

  /// End moment.
  static const endAt = BeakDateTimeColumn(key: 'end_at', label: 'Ends');

  /// Whether the event spans whole days.
  static const allDay = BeakBoolColumn(
    key: 'all_day',
    label: 'All day',
    filterable: true,
  );

  /// Event color (overrides the category color when set).
  static const color = BeakColorColumn(
    key: 'color',
    label: 'Color',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Location text.
  static const location = BeakStringColumn(
    key: 'location',
    label: 'Location',
    rules: [BeakMaxLength(160)],
  );

  /// Related URL.
  static const url = BeakStringColumn(
    key: 'url',
    label: 'URL',
    visibleOn: {BeakContext.form, BeakContext.detail},
    rules: [BeakUrl()],
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    title,
    description,
    categoryId,
    organizerId,
    startAt,
    endAt,
    allDay,
    color,
    location,
    url,
  ];
}

/// Typed relationships of the calendar-events resource.
abstract final class CalendarEventRelations {
  /// The category.
  static const category = BeakBelongsTo(
    key: 'category',
    label: 'Category',
    relatedTable: 'event_categories',
    displayColumnKey: 'label',
    foreignKey: 'category_id',
  );

  /// The organizer.
  static const organizer = BeakBelongsTo(
    key: 'organizer',
    label: 'Organizer',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'organizer_id',
    searchColumnKeys: ['name'],
  );

  /// The invited guests, via the `event_user` pivot.
  static const guests = BeakBelongsToMany(
    key: 'guests',
    label: 'Guests',
    relatedTable: 'users',
    displayColumnKey: 'name',
    pivotTable: 'event_user',
    foreignPivotKey: 'event_id',
    relatedPivotKey: 'user_id',
    searchColumnKeys: ['name'],
  );
}

/// The calendar-events resource — a scheduled event.
final class CalendarEventModel extends BeakModel {
  /// Creates the calendar-events model.
  const CalendarEventModel();

  @override
  String get table => 'calendar_events';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => CalendarEventColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    CalendarEventRelations.category,
    CalendarEventRelations.organizer,
    CalendarEventRelations.guests,
  ];
}
