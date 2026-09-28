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
/// Enums and booleans become selects, strings a contains-search, dates and
/// numbers a range. Structured/binary columns require an explicit custom filter.
// --8<-- [start:beakDefaultFiltersOf]
List<BeakFilterDef> beakDefaultFiltersOf(BeakModel model) => <BeakFilterDef>[
  for (final column in model.columns)
    if (column.filterable)
      if (_filterFor(column) case final BeakFilterDef filter) filter,
];
// --8<-- [end:beakDefaultFiltersOf]

/// Exhaustive on purpose: a new column kind must decide what filtering it
/// means, rather than silently defaulting to none.
// --8<-- [start:filterFor]
BeakFilterDef? _filterFor(BeakColumn column) {
  if (const {
    BeakSemanticKind.calendarDate,
    BeakSemanticKind.time,
    BeakSemanticKind.duration,
    BeakSemanticKind.money,
    BeakSemanticKind.exactDecimal,
    BeakSemanticKind.percentage,
  }.contains(column.semantic.kind)) {
    return BeakSemanticRangeFilter(column: column, label: column.label);
  }
  return switch (column) {
    BeakEnumColumn() => BeakSelectFilter(column: column, label: column.label),
    BeakBoolColumn() => BeakBoolFilter(column: column, label: column.label),
    BeakStringColumn() ||
    BeakTextColumn() => BeakTextFilter(column: column, label: column.label),
    BeakDateTimeColumn() => BeakDateRangeFilter(
      column: column,
      label: column.label,
    ),
    BeakIntColumn() || BeakDecimalColumn() => BeakNumberRangeFilter(
      column: column,
      label: column.label,
    ),
    // Structured, binary and rich presentation values have no generic filter.
    BeakRichTextColumn() ||
    BeakJsonColumn() ||
    BeakColorColumn() ||
    BeakCustomColumn() ||
    BeakUploadColumn() => null,
  };
}

// --8<-- [end:filterFor]
