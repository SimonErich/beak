part of 'beak_block.dart';

/// A data-bound calendar: a model's records rendered as scheduled events on
/// an `OiCalendar`, via typed field bindings.
///
/// Each record becomes one event — [titleField] labels it, [startField] and
/// [endField] bound it, [allDayField] flags all-day entries, and
/// [categoryField] (when a [BeakEnumColumn]) tints it with the value's badge
/// color. Tapping an event calls [onEventTap] with its [BeakRecord]. When the
/// calendar reports a drag (`OiCalendar` exposes an `onEventMove` callback),
/// the block persists the new range through `dataSource.update` and then
/// notifies [onEventMove].
///
/// ```dart
/// BeakCalendarBlock(
///   model: const EventModel(),
///   titleField: EventModel.title.column,
///   startField: EventModel.startsAt.column,
///   endField: EventModel.endsAt.column,
///   categoryField: EventModel.status.column,
///   onEventTap: (record) => selected.value = EventModel.id.readFrom(record),
/// );
/// ```
final class BeakCalendarBlock extends BeakBlock {
  /// Creates a calendar block over [model].
  // --8<-- [start:BeakCalendarBlockConstructor]
  const BeakCalendarBlock({
    required this.model,
    required this.titleField,
    required this.startField,
    this.endField,
    this.allDayField,
    this.categoryField,
    this.mode = OiCalendarMode.month,
    this.label = 'Calendar',
    this.onEventTap,
    this.onEventMove,
    super.span,
  });
  // --8<-- [end:BeakCalendarBlockConstructor]

  /// The model whose records become events.
  final BeakModel model;

  /// Column supplying each event's title.
  final BeakColumn titleField;

  /// Column supplying each event's start instant.
  final BeakColumn startField;

  /// Column supplying each event's end instant; falls back to [startField].
  final BeakColumn? endField;

  /// Boolean column flagging all-day events, when bound.
  final BeakColumn? allDayField;

  /// Column categorizing events; a [BeakEnumColumn] here tints each event
  /// with its value's badge color.
  final BeakColumn? categoryField;

  /// The initial calendar mode (day/week/month).
  final OiCalendarMode mode;

  /// Accessibility label for the calendar.
  final String label;

  /// Invoked with the tapped event's record.
  final void Function(BeakRecord record)? onEventTap;

  /// Invoked after an event is dragged to a new range; the block first
  /// persists the move through the data source.
  final void Function(BeakRecord record, DateTime start, DateTime end)?
  onEventMove;
}
