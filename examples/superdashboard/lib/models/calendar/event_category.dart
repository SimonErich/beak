import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'calendar_event.dart';

part 'event_category.beak.dart';

/// The event-categories resource — colored calendar buckets.
@Resource()
final class EventCategory extends BeakSchema {
  /// Category key, e.g. `business`.
  @Column(searchable: true, rules: [BeakMaxLength(40)])
  late final String name;

  /// Display label.
  @Display()
  @Column(rules: [BeakMaxLength(40)])
  late final String label;

  /// Calendar color for events in this category.
  late final BeakHexColor? color;

  /// Events in this category.
  @HasMany(foreignKey: 'category_id')
  late final List<CalendarEvent> events;
}
