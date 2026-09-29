---
title: Recipes
description: Fourteen short, tested recipes for common admin tasks, from a new resource to a kanban board, each quoting the example that does it.
type: index
audience: [beginner, expert, agent]
status: stable
---

# Recipes

A recipe answers one task and stops. You want a status badge, a money field, a bulk button: the page shows the code that does it, quoted from an example that compiles, and says how it behaves and which test proves it.

Each page has the same four parts. `Recipe` is the shortest path, `How it works` says what Beak does with it and where it stops, `Variations` is a table of the changes people ask for next, and `Verify` names the tests and commands that show it works. The recipes assume the shop (`examples/clean_beak_config`, an authored panel) unless they say otherwise. Where a generated panel and an authored one differ, the page has both, in tabs.

## Which page to read

| You want to... | Read | For that |
| --- | --- | --- |
| Give a new model its own section in the panel | [Add a resource](add-a-resource.md) | `beak make:resource`, `beak migrate`, and the one line of registration for an authored panel |
| Show a status as a coloured badge with a readable label | [An enum badge column](an-enum-badge-column.md) | `@Badges` and `@EnumLabels` on a Dart enum, the select filter, and the server-side check of the stored value |
| Store a price exactly and show it in the panel's currency | [A money field](a-money-field.md) | `BeakDecimal`, the currency input, locale-aware display and sums without floating point |
| Pick a related record, with choices that depend on another field | [A belongs-to picker](a-belongs-to-picker.md) | `@BelongsTo`, `BeakExists` with `BeakFieldMatch`, and a picker that clears a stale choice |
| Edit order lines inside the order form | [A nested table editor](a-nested-table-editor.md) | `tableForm` over an owned has-many, staged rows, `minRows`, and one graph commit on Save |
| Add an Issue invoice button that the server enforces | [A row action](a-row-action.md) | `BeakModelAction` with `availableWhen` and `values`, shown in the list, the show page and the form |
| Change one field on many selected rows | [A bulk edit](a-bulk-edit.md) | `BeakBulkAction.edit`, the per-record review, `updated_at` conflict checks and partial results |
| Split a long form into validated steps | [A multi-step form](a-multi-step-form.md) | `BeakFormSections` projected into a wizard and tabs, draft resume and review before save |
| Show records as cards on a board | [A kanban view](a-kanban-view.md) | `BeakKanbanBlock` over an enum field, the page that holds it, and what a dropped card writes |
| Put a live number on a dashboard | [A dashboard KPI](a-dashboard-kpi.md) | `BeakMetricBlock` counts and sums, a shared filter, and exact money in a widget |
| Let people name and reuse a filtered list | [A saved list view](a-saved-list-view.md) | `BeakSavedViewStore`, the model behind it, and the picker you mount because the toolbar has none |
| Load rows from a pasted CSV | [A CSV import](a-csv-import.md) | `BeakImportView`, the field allowlist, row-by-row review and per-row receipts |
| Download what a list is showing | [Export to CSV](export-to-csv.md) | `BeakListExport`, formatted or raw values, and the selection export |
| Keep a model out of the sidebar | [Hide a resource](hide-a-resource.md) | `hidden: true` in `beak.yaml` or a resource left out of the list, and what still works |

## Continue reading

- [Cheatsheet](../reference/cheatsheet.md) lists the names these recipes use on one page.
- [The panel](../panel/index.md) explains resources, lists, actions and dashboards in depth.
- [Forms and records](../forms/index.md) covers the form screens, relations and workflows behind the form recipes.
