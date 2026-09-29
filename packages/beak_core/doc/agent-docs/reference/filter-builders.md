# Filter builders

> Look up every filter builder and filter definition, the control each renders, the predicate it emits and where a list takes them.

A filter builder is a method on a generated field reference that returns a `BeakFilterDef`: a typed description of one filter control. This page lists every builder and definition class, the control each renders, the `BeakFilter` it contributes to the list query and the places that accept them.

## Import

```dart
import 'package:beak/panel.dart';
```

`package:beak/panel.dart` re-exports `package:beak/beak.dart`, so the model, the field references and the query types come with it.

## Summary

| Builder | Declared on | Returns | Control | Predicate emitted | No predicate when |
| --- | --- | --- | --- | --- | --- |
| `textFilter` | `BeakScalarField<String>` | `BeakTextFilter` | Text input | `contains` with the trimmed text | The trimmed text is empty |
| `numberRangeFilter` | `BeakScalarField<T extends num>` | `BeakNumberRangeFilter` | One or two number inputs | `gte` minimum AND `lte` maximum | Both bounds are empty |
| `boolFilter` | `BeakScalarField<bool>` | `BeakBoolFilter` | Yes / no select with a Clear button | `eq` with the chosen `bool` | The select is cleared |
| `selectFilter` | `BeakScalarField<T extends Enum>` | `BeakSelectFilter` | Select of the enum's values | `eq` with the enum name | The select is cleared |
| `dateRangeFilter` | `BeakScalarField<DateTime>` | `BeakDateRangeFilter` | Date-range picker | `gte` start of the first day AND `lt` start of the day after the last | The picker is cleared |
| `dateRangeFilter` | `BeakScalarField<BeakDate>` | `BeakSemanticRangeFilter` | Two date inputs | `gte` lower AND `lte` upper | Both bounds are empty |
| `rangeFilter` | `BeakScalarField<T extends Object>` | `BeakSemanticRangeFilter` | Two inputs typed for the field (money, exact decimal, date, time, duration, percentage) | `gte` lower AND `lte` upper, in stored units | Both bounds are empty |
| `relationFilter` | `BeakToOneField` | `BeakRelationSelectFilter` | Searchable record picker | `BeakRelationFilter` wrapping `eq` on the target's primary key | Nothing is selected |
| None (constructor only) | `BeakScalarField<Object>` | `BeakChoiceFilter` | Checkboxes, chips, radio, select or multi-select | `BeakOrFilter` of the selected choices' predicates | No choice is selected |

Every builder takes `label` (default: the field's label) and `advanced` (default `false`). Each control stores its state under the field's qualified key, and a field reached through a relationship (`BookModel.author.name`) gives a dotted key that the server expands (see [Queries](queries.md#column-keys-with-dots)).

## Filter definitions

`BeakFilterDef` is the sealed base of every definition. The list and the filter bar switch over it exhaustively.

```dart title="packages/beak_frontend/lib/src/filters/beak_filter_widget.dart"
sealed class BeakFilterDef {
  /// Creates a filter over [field] labelled [label].
  const BeakFilterDef({
    required this.column,
    required this.label,
    required this.field,
    this.advanced = false,
  });

  /// The column the filter constrains.
  final BeakColumn column;

  /// The control label.
  final String label;

  /// Keeps a less frequent filter in the expandable section of a stacked editor.
  final bool advanced;

  /// The typed field the filter addresses, including related paths.
  final BeakFieldRef<Object> field;

  /// Root-qualified identity used for predicates and independent filter state.
  String get key => field.qualifiedKey;
}
```

| Field | Type | Meaning |
| --- | --- | --- |
| `column` | `BeakColumn` | The column the filter constrains. For a relation filter, the target model's primary key |
| `label` | `String` | Control label |
| `field` | `BeakFieldRef<Object>` | The typed field the filter addresses, including related paths |
| `advanced` | `bool` | Places the filter in the collapsible "More filters" section. Takes effect only in a stacked editor such as the list's filter drawer |
| `key` | `String` | `field.qualifiedKey`. Identifies the predicate and the independent state of the filter |

Definitions with a public constructor: `BeakTextFilter`, `BeakBoolFilter`, `BeakSelectFilter`, `BeakDateRangeFilter`, `BeakNumberRangeFilter`, `BeakRelationSelectFilter`, `BeakSemanticRangeFilter`, `BeakChoiceFilter`. The builders are the usual way to make the first seven; `BeakChoiceFilter` has no builder.

### Builder signatures

```dart title="packages/beak_frontend/lib/src/filters/beak_filter_widget.dart"
BeakTextFilter textFilter({String? label, bool advanced = false}) =>
    BeakTextFilter(
// ...
BeakNumberRangeFilter numberRangeFilter({
  String? label,
  bool advanced = false,
  bool showMinimum = true,
  bool showMaximum = true,
  String? minimumLabel,
  String? maximumLabel,
  String? placeholder,
}) => BeakNumberRangeFilter(
// ...
BeakBoolFilter boolFilter({String? label, bool advanced = false}) =>
    BeakBoolFilter(
// ...
BeakSelectFilter selectFilter({String? label, bool advanced = false}) =>
    BeakSelectFilter(
// ...
BeakDateRangeFilter dateRangeFilter({String? label, bool advanced = false}) =>
    BeakDateRangeFilter(
// ...
BeakSemanticRangeFilter dateRangeFilter({
  String? label,
  bool advanced = false,
  bool inline = false,
  List<BeakRangePreset<BeakDate>> presets = const [],
}) => rangeFilter(
// ...
BeakRelationSelectFilter relationFilter({
  String? label,
  BeakOptionQuery? options,
  bool advanced = false,
}) => BeakRelationSelectFilter(
// ...
BeakSemanticRangeFilter rangeFilter({
  String? label,
  bool advanced = false,
  bool inline = false,
  List<BeakRangePreset<T>> presets = const [],
}) => BeakSemanticRangeFilter(
```

The extensions are `BeakTextFieldFilters`, `BeakNumberFieldFilters`, `BeakBooleanFieldFilters`, `BeakEnumFieldFilters`, `BeakDateFieldFilters`, `BeakCalendarDateFieldFilters`, `BeakRelationFieldFilters` and `BeakSemanticFieldFilters`.

### Text, boolean, select and date range

These four definitions take only the base fields. Their constructor is `(field: ..., label: ..., advanced: false)` with `field` a `BeakScalarField<Object>`.

| Definition | Field must address | Behavior |
| --- | --- | --- |
| `BeakTextFilter` | A string-backed column | Case-insensitive substring match through `contains` |
| `BeakBoolFilter` | A `bool` column | Three states: true, false, and all records when cleared. There is no "is null" state |
| `BeakSelectFilter` | A `BeakEnumColumn` | Options and labels come from the column's `values` and `labelFor`. Over any other column the control renders the text "Unavailable" |
| `BeakDateRangeFilter` | A `DateTime` column | Bounds are the picked days at local midnight: `gte` the first day, `lt` the day after the last day, so the last day is included whole |

### Number range

```dart title="packages/beak_frontend/lib/src/filters/beak_filter_widget.dart"
BeakNumberRangeFilter({
  required BeakScalarField<Object> field,
  required super.label,
  super.advanced,
  this.showMinimum = true,
  this.showMaximum = true,
  this.minimumLabel,
  this.maximumLabel,
  this.placeholder,
}) : assert(showMinimum || showMaximum),
     super(column: field.column, field: field);
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `showMinimum` | `bool` | `true` | Whether the lower bound is editable |
| `showMaximum` | `bool` | `true` | Whether the upper bound is editable. At least one of the two must be `true` |
| `minimumLabel` | `String?` | `'<label> ≥'` | Full label of the lower input |
| `maximumLabel` | `String?` | `'<label> ≤'` | Full label of the upper input |
| `placeholder` | `String?` | `null` | Example shown in an empty input |

Both bounds are inclusive. On an integer column the bounds are truncated to `int`; on a decimal column they are sent as `double`. When the field carries a currency presentation (`field.currency(minorUnits: true)`), the inputs edit major units and the predicate carries the stored minor units, so 40.25 becomes `4025`.

```dart title="packages/beak_frontend/test/src/filters/filters_test.dart"
final def = field
    .currency(minorUnits: true)
    .numberRangeFilter(
      showMaximum: false,
      minimumLabel: 'Minimum order',
      placeholder: 'e.g. 40.00',
    );
```

The snippet comes from the filter bar test, where `field` is a `BeakScalarField<int>`.

### Semantic range and presets

`BeakSemanticRangeFilter` is the inclusive range for fields whose values are not plain numbers: exact money and decimals, calendar dates, times, durations and percentages. Its inputs parse and encode through the column's semantic, so the predicate carries the exact stored representation.

```dart title="packages/beak_frontend/lib/src/filters/beak_filter_widget.dart"
BeakSemanticRangeFilter({
  required BeakScalarField<Object> field,
  required super.label,
  super.advanced,
  this.inline = false,
  this.presets = const [],
}) : super(column: field.column, field: field);
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `inline` | `bool` | `false` | Places the two inputs side by side when at least 320 logical pixels are available. Calendar dates also switch to date-picker inputs |
| `presets` | `List<BeakRangePreset<Object>>` | `[]` | Named ranges followed by an editable "Custom" choice. Up to four presets render as a segmented control, more as toggle buttons |

`BeakRangePreset<T>` holds `label` (required), `lower` and `upper` (both `T?`, inclusive, either may be omitted for an open range).

```dart title="packages/beak_frontend/test/src/form/semantic_presentation_test.dart"
field.dateRangeFilter(
  inline: true,
  presets: const [
    BeakRangePreset(
      label: 'Next week',
      lower: BeakDate(2028, 2, 28),
      upper: BeakDate(2028, 3, 5),
    ),
  ],
),
```

The predicate is an AND of `gte` and `lte` (or a single one when a bound is open), for example `field.gte(BeakDate(2028, 2, 28))` and `field.lte(BeakDate(2028, 3, 5))`. A bound that does not parse marks the editor invalid and no predicate is emitted until it does.

### Relation select

```dart title="packages/beak_frontend/lib/src/filters/beak_filter_widget.dart"
BeakRelationSelectFilter({
  required this.relationField,
  String? label,
  this.options,
  super.advanced,
}) : super(
       column: relationField.target.primaryKey,
       label: label ?? relationField.label,
       field: relationField,
     );
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `relationField` | `BeakToOneField` | required | The relationship whose selected target must match |
| `options` | `BeakOptionQuery?` | `null` | Permanent constraint, sorts and includes for the option query. `null` uses `relationField.options()` |

The control is a searchable combo box. Typing runs a query on the target model whose search columns are the relationship's search columns (`searchOn` on the annotation, default the display column), and the first page of results is offered. A selected record is resolved by id and shown with the relationship's display label. The emitted predicate is `relationField.matches(...)` around `eq` on the target's primary key. Only to-one fields have this builder.

## Choice filters

`BeakChoiceFilter` offers named predicates and ORs the selected ones. The predicates are arbitrary `BeakFilter` values, so a choice can be a compound domain condition.

```dart title="packages/beak_frontend/lib/src/filters/beak_filter_widget.dart"
BeakChoiceFilter({
  required BeakScalarField<Object> field,
  required super.label,
  required this.options,
  this.presentation = BeakChoiceFilterPresentation.checkboxes,
  this.columns = 1,
  this.allLabel = 'All',
  this.showCounts = false,
  this.addItemLabel,
  this.showLabel = true,
  super.advanced,
}) : assert(columns > 0),
     super(column: field.column, field: field);
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `field` | `BeakScalarField<Object>` | required | Identifies the filter and its state. The predicates come from `options` |
| `options` | `List<BeakFilterChoice>` | required | The choices |
| `presentation` | `BeakChoiceFilterPresentation` | `checkboxes` | Control style, see below |
| `columns` | `int` | `1` | Maximum checkbox columns; below 360 logical pixels of width the control uses one. Must be above 0 |
| `allLabel` | `String` | `'All'` | Label of the unconstrained option in `radio` and `select` |
| `showCounts` | `bool` | `false` | Shows the number of records per choice: beside each checkbox, and as `Label (12)` in the chips, radio, select and combobox presentations |
| `addItemLabel` | `String?` | `null` | Prompt below the selected values of a `combobox` |
| `showLabel` | `bool` | `true` | Shows the group heading; a single self-labelled checkbox may hide it |

`BeakFilterChoice` has three required fields: `key` (stable identity within the filter), `label` and `filter` (the predicate ORed with the other selected choices).

```dart title="packages/beak_frontend/test/src/filters/filters_test.dart"
final choice = BeakChoiceFilter(
  field: status,
  label: 'Workflow',
  options: [
    BeakFilterChoice(
      key: 'published',
      label: 'Published',
      filter: published,
    ),
    BeakFilterChoice(
      key: 'attention',
      label: 'Needs attention',
      filter: attention,
    ),
  ],
);
```

| `BeakChoiceFilterPresentation` | Control | Selection |
| --- | --- | --- |
| `checkboxes` | Checkboxes, optionally in columns; the only one that shows counts | Several |
| `chips` | Toggle chips for short labels | Several |
| `combobox` | Searchable multi-select with removable chips | Several |
| `radio` | Radio group with an explicit "all" option | One |
| `select` | Dropdown with an explicit "all" option | One |

Counts come from one `BeakSummarySpec` per group of eight choices, each choice a `BeakSummaryMeasure.count` with the choice's predicate, over the list's applied query (see [Queries](queries.md#summaries)). They appear only when the data source implements `BeakSummaryDataSource`; until a count loads the row shows a dash.

## Default filters

A resource that declares no filters gets one per column marked `filterable: true`. `beakDefaultFiltersOf(model)` builds them and `BeakResource.effectiveFilters` calls it.

```dart title="packages/beak_frontend/lib/src/filters/beak_default_filters.dart"
BeakFilterDef? _filterFor(BeakScalarField<Object> field) {
  final column = field.column;
  if (const {
    BeakSemanticKind.calendarDate,
    BeakSemanticKind.time,
    BeakSemanticKind.duration,
    BeakSemanticKind.money,
    BeakSemanticKind.exactDecimal,
    BeakSemanticKind.percentage,
  }.contains(column.semantic.kind)) {
    return BeakSemanticRangeFilter(field: field, label: column.label);
  }
  return switch (column) {
    BeakEnumColumn() => BeakSelectFilter(field: field, label: column.label),
    BeakBoolColumn() => BeakBoolFilter(field: field, label: column.label),
    BeakStringColumn() ||
    BeakTextColumn() => BeakTextFilter(field: field, label: column.label),
    BeakDateTimeColumn() => BeakDateRangeFilter(
      field: field,
      label: column.label,
    ),
    BeakIntColumn() || BeakDecimalColumn() => BeakNumberRangeFilter(
      field: field,
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

```

| Column | Default filter |
| --- | --- |
| Semantic `calendarDate`, `time`, `duration`, `money`, `exactDecimal`, `percentage` | `BeakSemanticRangeFilter` |
| `BeakEnumColumn` | `BeakSelectFilter` |
| `BeakBoolColumn` | `BeakBoolFilter` |
| `BeakStringColumn`, `BeakTextColumn` | `BeakTextFilter` |
| `BeakDateTimeColumn` | `BeakDateRangeFilter` |
| `BeakIntColumn`, `BeakDecimalColumn` | `BeakNumberRangeFilter` |
| `BeakRichTextColumn`, `BeakJsonColumn`, `BeakColorColumn`, `BeakCustomColumn`, image and file columns | None |

The semantic check runs first, so a money column gets a semantic range although it is stored in an integer column. Relationships get no default filter: declare `relationFilter()` for a to-one field. Every default carries the column's label. Declared `filters` replace the defaults completely; they do not merge with them.

## Where filters attach

| Place | Parameter | Effect |
| --- | --- | --- |
| `BeakResource` | `filters` (`List<BeakFilterDef>`, default `[]`) | Filter bar of the generated list page. Empty means the defaults above. `copyWith(filters: ...)` replaces them |
| `BeakListDefinition` | `filters` | Controls in the staged filter drawer of a composed list. Empty inherits the resource's `effectiveFilters` |
| `BeakListDefinition` | `quickFilters`, `quickFilterLabels` | Filters shown as compact buttons beside search; `quickFilterLabels` shortens their toolbar labels |
| `BeakQueryPreset` | `quickFilters`, `defaults` | Quick filters for one preset; `defaults` maps a `BeakFilterDef` to the predicate it starts with |

```dart title="examples/serverpod/bookshop_admin/lib/resources/book_resource.dart"
filters: [
  BookModel.title.textFilter(),
  BookModel.author.relationFilter(),
  BookModel.format.selectFilter(),
  BookModel.priceInCents.numberRangeFilter(label: 'Price'),
],
```

The filter-related members of `BeakListDefinition`:

```dart title="packages/beak_frontend/lib/src/query/beak_list_definition.dart"
this.presets = const [],
this.columns = const [],
this.filters = const [],
this.quickFilters = const [],
this.quickFilterLabels = const {},
this.filterSheetWidthInPixels = 440,
this.filterDescription,
this.advancedFilterDescription,
this.advancedFilterColumns = 1,
// ...
this.initialPreset,
this.persistQueryInUrl = true,
this.showPresetCounts = true,
this.showSearch = true,
this.searchPlaceholder,
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `filters` | `List<BeakFilterDef>` | `[]` | Controls in the staged drawer |
| `quickFilters` | `List<BeakFilterDef>` | `[]` | Compact buttons beside search |
| `quickFilterLabels` | `Map<BeakFilterDef, String>` | `{}` | Shortened toolbar labels; the editor keeps the full label |
| `filterSheetWidthInPixels` | `double` | `440` | Width of the drawer, clamped to the viewport |
| `filterDescription` | `String?` | `null` | Guidance below the drawer title |
| `advancedFilterDescription` | `String?` | `null` | Text beside the collapsed "More filters" heading |
| `advancedFilterColumns` | `int` | `1` | Columns of the expanded advanced group; one below 360 logical pixels |
| `presets` | `List<BeakQueryPreset>` | `[]` | Named views that add a permanent filter |
| `initialPreset` | `BeakQueryPreset?` | `null` | Preset selected before a bookmark or saved view applies |
| `persistQueryInUrl` | `bool` | `true` | Keeps filter state in the route |
| `showPresetCounts` | `bool` | `true` | Fetches an authoritative count per preset |
| `showSearch` | `bool` | `true` | Shows the search field |
| `searchPlaceholder` | `String?` | `null` | Text explaining the searched fields |

`BeakQueryPreset` has `key` and `label` (required), `filter` (added to the permanent scope while the preset is selected), `columns`, `quickFilters`, `defaults`, `rowHeightInPixels` and `countColor` (default `BeakColor.muted`). Presets, saved views and URL state are covered in [Composed lists and query state](../panel/composed-lists.md).

## The filter bar

`BeakFilterBar` renders a list of definitions and reports the combined predicate. The list page builds one from `resource.effectiveFilters`; a hand-built page wires it the same way.

```dart title="packages/beak_frontend/lib/src/filters/beak_filter_widget.dart"
const BeakFilterBar({
  required this.filters,
  required this.onChanged,
  this.dataSource,
  this.initialValues = const {},
  this.onFiltersChanged,
  this.onValidityChanged,
  this.presentation = BeakFilterBarPresentation.chips,
  this.stacked = false,
  this.countQuery,
  this.countQueryFor,
  this.advancedDescription,
  this.advancedColumns = 1,
  super.key,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `filters` | `List<BeakFilterDef>` | required | Controls, in order |
| `onChanged` | `ValueChanged<BeakFilter?>` | required | Called with the combined predicate; `null` when no filter is active |
| `dataSource` | `BeakDataSource?` | `null` | Source for relation choices and counts. A relation filter falls back to the panel's source when this is `null`; counts do not, and the list page and the filter drawer both pass it |
| `initialValues` | `Map<String, BeakFilter>` | `{}` | Applied predicates by `BeakFilterDef.key`, restored when the bar opens |
| `onFiltersChanged` | `ValueChanged<Map<String, BeakFilter>>?` | `null` | Reports each control's predicate separately, for persistence |
| `onValidityChanged` | `ValueChanged<bool>?` | `null` | `false` while an editor holds text that does not parse |
| `presentation` | `BeakFilterBarPresentation` | `chips` | `chips` shows one chip per filter and opens its editor in a popover; `controls` keeps every editor visible |
| `stacked` | `bool` | `false` | Vertical layout for a drawer. Enables the `advanced` section; overrides `presentation` |
| `countQuery` | `BeakQuerySpec?` | `null` | Applied list scope used for choice counts |
| `countQueryFor` | `BeakQuerySpec Function(BeakFilterDef)?` | `null` | Per-filter population for counts, excluding that filter's own predicate |
| `advancedDescription` | `String?` | `null` | Text beside the "More filters" heading |
| `advancedColumns` | `int` | `1` | Columns of the expanded advanced group |

In `chips` presentation an inactive filter is an outlined chip labelled with the filter's label, an active one shows a short summary of its value with a remove action, and a "Clear all" button appears while any filter is active. The summary text comes from `beakFilterSummary(context, definition, filter)`: the selected choice labels for a choice filter, `From x`, `Through x` or both bounds joined by an en dash for a range, the value for a single comparison and `Active` otherwise.

## From controls to a query

Each definition contributes at most one predicate under its `key`. The bar combines them with `BeakFilter.allOf`, which ANDs them, and a `BeakChoiceFilter` ORs only its own choices. In a composed list the map of predicates lives in `BeakQueryState.filters`, and `BeakQueryController.queryFor` places the values after the permanent scope and the preset's filter in the spec's `filter` (see [Queries](queries.md#how-a-list-builds-its-spec)). An empty `BeakAndFilter` stored under a key marks a preset default the user cleared on purpose.

## Rules and limits

- One state slot exists per `key`. Two definitions over the same field would share it, so `BeakPanelConfig` refuses them with a `BeakConfigurationException` when the panel builds. Declare one filter per field.
- A select filter must address an enum column. Elsewhere it renders "Unavailable" and emits nothing.
- A choice restored from a bookmark or saved view is matched by the JSON of its predicate, not by its `key`. Changing a choice's predicate makes saved views stop selecting it.
- A relation filter offers the first page of the option query (25 records unless `options` sets another page size) and searches only the relationship's search columns.
- Number ranges truncate to `int` on integer columns. Use `rangeFilter` for money, exact decimals, dates, times and durations; `numberRangeFilter` accepts `num` fields only.
- Date-range bounds are built as local midnight `DateTime` values and travel as ISO strings without an offset (see [Queries](queries.md#values-on-the-wire)).
- `showCounts` needs a data source that implements `BeakSummaryDataSource`.
- Filters narrow what the panel asks for. The server still applies row policies and field policies to every query, so a filter never reveals a record or a field the caller could not read.

## Source

- `packages/beak_frontend/lib/src/filters/beak_filter_widget.dart`: definitions, builders, `BeakFilterBar`, `beakFilterSummary`.
- `packages/beak_frontend/lib/src/filters/beak_default_filters.dart`: `beakDefaultFiltersOf`.
- `packages/beak_frontend/lib/src/filters/beak_semantic_range_control.dart`: the semantic range editor (internal, not exported).
- `packages/beak_frontend/lib/src/query/beak_list_definition.dart`: `BeakListDefinition`.
- `packages/beak_frontend/lib/src/query/beak_query_controller.dart`: `BeakQueryPreset`, `BeakQueryState`, `BeakQueryController`.
- `packages/beak_frontend/lib/src/panel/beak_resource.dart`: `BeakResource.filters`, `effectiveFilters`.
- `packages/beak_core/lib/src/query/beak_filter.dart`, `beak_operator.dart`: the predicates the controls emit.
- `packages/beak_frontend/test/src/filters/filters_test.dart`: the behavior of every control.

## Continue reading

- [Queries](queries.md) the filter tree, operators and values these controls produce.
- [Tables and filters](../panel/tables-and-filters.md) configure a resource's list page.
- [Composed lists and query state](../panel/composed-lists.md) presets, staged filters, saved views and export.
- [Panel and resource options](panel-options.md) every option of `BeakResource`, including `filters`.
