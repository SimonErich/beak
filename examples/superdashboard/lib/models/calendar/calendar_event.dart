import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../people/user.dart';
import 'event_category.dart';

part 'calendar_event.beak.dart';

/// The calendar-events resource — a scheduled event.
@Resource()
final class CalendarEvent extends BeakSchema {
  /// Event title.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(160)])
  late final String title;

  /// Long-form description.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? description;

  /// The category.
  @BelongsTo()
  late final EventCategory? category;

  /// The organizer.
  @BelongsTo()
  late final User? organizer;

  /// Start moment.
  @Column(label: 'Starts', sortable: true)
  late final DateTime startAt;

  /// End moment.
  @Column(label: 'Ends')
  late final DateTime? endAt;

  /// Whether the event spans whole days.
  @Column(label: 'All day', filterable: true)
  late final bool? allDay;

  /// Event color (overrides the category color when set).
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakHexColor? color;

  /// Location text.
  @Column(rules: [BeakMaxLength(160)])
  late final String? location;

  /// Related URL.
  @Column(
    label: 'URL',
    visibleOn: {BeakContext.form, BeakContext.detail},
    rules: [BeakUrl()],
  )
  late final String? url;

  /// The invited guests, via the `event_user` pivot.
  @BelongsToMany(pivotTable: 'event_user', foreignPivotKey: 'event_id')
  late final List<User> guests;
}
