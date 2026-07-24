import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../blocks/beak_block.dart';

/// One selectable presentation of a resource's records on its list page.
///
/// A resource always has a table view; declaring extra view modes (calendar,
/// board, …) puts an `OiSegmentedControl` above the list so users switch
/// between them. Each mode [build]s a [BeakBlock] from the resource's
/// [BeakModel], which `BeakBlockHost` renders — so a view mode is pure typed
/// configuration, not a hand-written widget.
///
/// ```dart
/// BeakResource(
///   model: const EventModel(),
///   icon: const BeakIconToken(OiIcons.calendar),
///   viewModes: const [
///     BeakTableView(),
///     BeakCalendarView(
///       titleField: EventColumns.title,
///       startField: EventColumns.startsAt,
///     ),
///   ],
/// );
/// ```
sealed class BeakResourceView {
  /// Enables `const` subclasses.
  const BeakResourceView();

  /// Stable identifier of this mode, unique within a resource.
  String get key;

  /// The label shown on the mode's segmented-control segment.
  String get label;

  /// The icon shown on the mode's segmented-control segment.
  IconData get icon;

  /// Builds the block that renders [model]'s records in this mode.
  BeakBlock build(BeakModel model);
}

/// The default view mode: the resource's records in a data table.
final class BeakTableView extends BeakResourceView {
  /// Creates the table view, optionally seeding sort/page and a base scope.
  const BeakTableView({this.initialSpec, this.baseFilter});

  /// Seeds sort order and page size on first load.
  final BeakQuerySpec? initialSpec;

  /// A filter AND-merged into every query.
  final BeakFilter? baseFilter;

  @override
  String get key => 'table';

  @override
  String get label => 'Table';

  @override
  IconData get icon => OiIcons.table;

  @override
  BeakBlock build(BeakModel model) => BeakTableBlock(
    model: model,
    initialSpec: initialSpec,
    baseFilter: baseFilter,
  );
}

/// A calendar view mode: the resource's records as scheduled events.
final class BeakCalendarView extends BeakResourceView {
  /// Creates a calendar view bound to the date/title columns.
  const BeakCalendarView({
    required this.titleField,
    required this.startField,
    this.endField,
    this.allDayField,
    this.categoryField,
    this.mode = OiCalendarMode.month,
    this.label = 'Calendar',
  });

  /// Column supplying each event's title.
  final BeakColumn titleField;

  /// Column supplying each event's start instant.
  final BeakColumn startField;

  /// Column supplying each event's end instant, when bound.
  final BeakColumn? endField;

  /// Boolean column flagging all-day events, when bound.
  final BeakColumn? allDayField;

  /// Column categorizing (and coloring) events, when bound.
  final BeakColumn? categoryField;

  /// The initial calendar mode.
  final OiCalendarMode mode;

  @override
  final String label;

  @override
  String get key => 'calendar';

  @override
  IconData get icon => OiIcons.calendar;

  @override
  BeakBlock build(BeakModel model) => BeakCalendarBlock(
    model: model,
    titleField: titleField,
    startField: startField,
    endField: endField,
    allDayField: allDayField,
    categoryField: categoryField,
    mode: mode,
    label: label,
  );
}

/// A Kanban view mode: the resource's records grouped into columns by an
/// enum field.
final class BeakKanbanView extends BeakResourceView {
  /// Creates a Kanban view grouped by [groupField].
  const BeakKanbanView({
    required this.groupField,
    required this.titleField,
    this.subtitleField,
    this.sortField,
    this.sortDescending = false,
    this.label = 'Board',
  });

  /// The enum column whose values define the board's columns.
  final BeakEnumColumn<Enum> groupField;

  /// Column supplying each card's title.
  final BeakColumn titleField;

  /// Column supplying each card's subtitle, when bound.
  final BeakColumn? subtitleField;

  /// Column ordering the cards within each column, when bound.
  final BeakColumn? sortField;

  /// Whether [sortField] orders descending.
  final bool sortDescending;

  @override
  final String label;

  @override
  String get key => 'kanban';

  @override
  IconData get icon => OiIcons.columns;

  @override
  BeakBlock build(BeakModel model) => BeakKanbanBlock(
    model: model,
    groupField: groupField,
    titleField: titleField,
    subtitleField: subtitleField,
    sortField: sortField,
    sortDescending: sortDescending,
    label: label,
  );
}
