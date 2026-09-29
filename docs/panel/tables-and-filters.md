---
title: Tables and filters
description: Configure typed list projections, permanent scopes and interactive filters.
type: guide
audience: [beginner]
status: draft
---

# Tables and filters

`BeakTableScreen.fields` selects and orders columns. Generated fields retain semantic formatting; `.formatted(...)` overrides a particular projection. The table supplies loading, empty and error states, sorting and pagination.

Resource filters use typed field builders such as `.boolFilter()`, `.numberRangeFilter()` and `.relationFilter()`. A table's base query remains in force as user filters change. Global search sources can include scalar fields and related paths. Account and field policies still constrain all server queries.

Resource filter bars use compact chips by default: inactive filters appear as
outlined `+` chips, and active filters show their selected value with a remove
action. Selecting a chip opens its typed editor in a popover, so filters do not
push the table down with a stack of empty inputs. Active bars include a clear
action. This default is shared by inferred filters and explicitly configured
resource filters. For a custom screen that needs editors permanently visible,
set `presentation: BeakFilterBarPresentation.controls`; the staged filter
drawer remains vertically arranged regardless of this setting.

Standard mutations publish data-change events so lists and dependent views refresh after a form or another screen saves. Model actions appear on eligible rows, and `BeakBulkAction.edit` supplies a typed selection workflow.

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart"
```

For coordinated preset tabs, summary charts, staged filters, saved views, column choices and authorized CSV downloads, use [Composed lists and query state](composed-lists.md).

Numeric range filters can show a minimum, a maximum, or both. Formatted currency
fields edit major units while retaining exact integer minor units in predicates.
Choice filters can render checkboxes, chips, radio buttons, a single dropdown,
or a multi-select with individually removable tags. Their predicates remain
shared across toolbar controls, staged drawers and saved views.

## Continue reading

- [Resources](resources.md)
- [Imports and bulk edits](../forms/imports-and-bulk-edits.md)
