import 'package:beak_core/beak_core.dart';

import 'beak_filter_widget.dart';

/// The filter bar [model] implies: one control per column marked
/// `filterable`, of the kind that column's type calls for.
///
/// `@Column(filterable: true)` already states the intent; without this a
/// project had to say it a second time on the resource, in a file the
/// generator owns — so adding one filter meant ejecting the whole panel.
/// [BeakResource.effectiveFilters] uses this whenever a resource declares no
/// filters of its own.
///
/// Enums become a select, booleans a switch, strings a contains-search, dates
/// a range. A filterable column of any other kind has no obvious control and
/// is skipped rather than guessed at — declare it on the resource.
List<BeakFilterDef> beakDefaultFiltersOf(BeakModel model) => <BeakFilterDef>[
  for (final column in model.columns)
    if (column.filterable)
      if (_filterFor(column) case final BeakFilterDef filter) filter,
];

/// Exhaustive on purpose: a new column kind must decide what filtering it
/// means, rather than silently defaulting to none.
BeakFilterDef? _filterFor(BeakColumn column) => switch (column) {
  BeakEnumColumn() => BeakSelectFilter(column: column, label: column.label),
  BeakBoolColumn() => BeakBoolFilter(column: column, label: column.label),
  BeakStringColumn() ||
  BeakTextColumn() => BeakTextFilter(column: column, label: column.label),
  BeakDateTimeColumn() => BeakDateRangeFilter(
    column: column,
    label: column.label,
  ),
  // No control fits these: a number wants a range input the filter family
  // does not have yet, and the rest are not values a person filters by.
  BeakIntColumn() ||
  BeakDecimalColumn() ||
  BeakRichTextColumn() ||
  BeakJsonColumn() ||
  BeakColorColumn() ||
  BeakCustomColumn() ||
  BeakUploadColumn() => null,
};
