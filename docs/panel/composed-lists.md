---
title: Composed lists and query state
description: Share one typed query across list presets, filters, summaries, saved views and exports.
type: guide
audience: [expert]
status: draft
---

# Composed lists and query state

Attach a `BeakListDefinition` to a `BeakTableScreen` when a resource needs more than the generated table. It defines preset tabs, typed columns, a summary header, filters, action placement and export. Ordinary `BeakTableScreen.fields` remains the shorter configuration for a simple list. Neither approach requires application fetching or table state.

The [Foodio order list](https://github.com/SimonErich/beak/blob/main/examples/foodio-adminpanel/lib/resources/orders/order_list.dart) is the complete example. Its table, charts, capacity summary, filter preview and CSV export consume the same query.

On compact surfaces, overview cards and filters scroll above a bounded table
viewport. Wrapping controls cannot squeeze the rows or pagination out of view.
Preset tabs retain their full width with the chart toggle on a separate line;
pagination stacks its page-size selector and total on narrow screens. This
responsive behavior needs no application layout or state code.

## Permanent scopes, presets and filters

`BeakQueryController` owns the active search, sorts, page length, page, filters, selected columns and header visibility. `BeakQueryScope` makes that controller available to descendant blocks. A list's base query is a permanent application constraint; server authorization adds the authoritative account and field constraints.

`BeakQueryPreset.filter` adds a mandatory constraint while that preset is selected. `defaults` instead associates suggested predicates with typed filter definitions. An explicit value for the same filter replaces its default, so a Today preset can suggest a delivery date without silently discarding a later date range chosen by the user. Clearing an editable filter also clears its suggested default, and that choice survives bookmarks. Mandatory preset and permanent scopes remain enforced. Changing presets retains explicit user filters and resets pagination and the preset's column projection.

Preset badges count the permanent scope and that preset's constraints and defaults. They do not change with the current page or the interactive filters applied to another preset. Summaries use the active filter and search, independent of table pagination. `subtitleBuilder` formats the same framework-owned preset-count map used by tab badges and refreshes after mutations or remote invalidation. Missing entries mean loading or unavailable counts. A failed summary or count stays a visible error or unavailable count; the UI does not substitute page-local totals.

Counts appear as separate tab metadata. A preset can set `countColor` to a semantic
tone, such as `BeakColor.error` for an attention queue, and `rowHeight` when its
columns need extra space. Ordinary rows keep the table theme's height.

`BeakChoiceFilter` accepts named `BeakFilterChoice` predicates. Selected options are OR-ed together; different controls are AND-ed. This supports a status choice that combines an enum value with an attention flag without application state callbacks. Numeric, calendar-date and timestamp ranges retain their typed values.

Choice presentation is independent of the predicate. Use `columns: 2` for a
responsive checkbox grid, `presentation: BeakChoiceFilterPresentation.chips` for
short toggle choices, `combobox` for searchable multi-selection, or `radio` for
one choice with an explicit All option. `select` renders the same single-choice
contract as a compact dropdown; `allLabel` names its unconstrained option.
Single-choice selection replaces the previous choice, and clearing All removes
that control's predicate. Set `showLabel: false` for a self-labelled single checkbox.

Calendar and semantic range helpers accept `inline: true` and typed
`BeakRangePreset` endpoints. Presets update both controls through the model codec;
Custom keeps the current endpoints editable. Date-only bounds stay date-only,
and exact money bounds keep their storage scale. For example:

```dart
OrderModel.deliveryDate.dateRangeFilter(
  inline: true,
  presets: [
    BeakRangePreset(label: 'Today', lower: today, upper: today),
  ],
)
```

Set `advanced: true` on infrequent filter definitions or generated helpers to
place them under More filters. Collapsing the section retains values and parse
errors. `filterSheetWidth` and `filterDescription` configure the staged editor;
the Obers sheet theme controls its inset and corners. Its footer remains visible,
and both applying and saving are disabled while input is invalid.

`showCounts: true` on a choice filter requests authoritative counts through the
source's summary capability, in batches of at most eight measures. In the staged
drawer, each count uses the candidate query with that facet's own editable
predicate excluded; permanent and mandatory preset scopes remain in force.
Loading or unavailable counts display a dash, never an invented zero. An ordinary
filter does not request counts. `addItemLabel: 'Add organization'` gives a
combobox removable selected tags and a labelled row for adding more choices.

`advancedFilterDescription` explains the collapsed group and
`advancedFilterColumns: 2` places advanced fields in a responsive grid.
`recordNoun: 'orders'` supplies the drawer's result action and selection count.
A preset can override `quickFilters` to prioritize the filters appropriate to its
workflow while reusing the same editor definitions.

Integer currency ranges retain their original storage units:

```dart
OrderModel.grossCents.currency(minorUnits: true).numberRangeFilter(
  advanced: true,
  showMaximum: false,
  minimumLabel: 'Order value from (optional)',
  placeholder: 'e.g. 40.00',
)
```

This edits major units and emits integer cents. `showMinimum` and `showMaximum`
configure one-sided bounds; omitted endpoints remain unconstrained. The currency
symbol follows the global formatting policy, and plain amounts omit steppers.

## Review before applying

`header` provides the full overview. With `showHeaderToggle` enabled,
`collapsedHeader` can provide a compact alternative when charts are hidden.
Both render in the same query scope; summaries retain their declared `active`,
`base` or `standalone` population. The visibility choice is part of URL and saved
view state. `BeakSummaryPresentation.strip` displays joined inline metrics and
wraps into rows on narrow screens without another application state controller.

The list presents search and column controls above quick filters. All filters and each quick filter open a staged editor. Editing updates a server count preview without replacing the active table. The action footer stays visible while long filter groups scroll. Apply commits the staged predicates together; closing the sheet leaves the query unchanged. Invalid typed input or a failed preview prevents applying the candidate. Column selection also has Apply and Cancel and requires at least one column.

Quick filters use `OiFilterChip`: inactive controls have an add affordance, while
active controls show their formatted value and a separate accessible clear action.
Choice labels and named ranges come from the same declarations as the drawer.
Use `quickFilterLabels: {slotFilter: 'Slot'}` for a shorter toolbar label while
keeping the full field label in the editor.
`BeakTableColumn.textAlign` aligns both its heading and cells; use `TextAlign.end`
for quantities and monetary values.
`cellPadding` optionally overrides the table theme's insets for both the heading
and cells of one column. Use it for compact numeric or action columns, leaving
room for the heading and its active sort indicator within an explicit `width`.
For sorting, `sortBy` must name a root model column declared `sortable: true`;
the presentation respects the model's sorting capability. Its sort indicator
also reflects initial and restored URL/saved-view sorting before any header tap.
Curating `rowActions` changes the row menu without disabling commands referenced
by action columns. Omitted commands remain column-only, with their original
availability checks. Compact action-column labels retain the full action name as
an accessible label and tooltip.
Small date-preset sets use a segmented control; inline calendar endpoints retain
individual accessible names without repeating visible labels. Advanced callers
can use `previewFilters` to build an unapplied controller state or `removeFilter`
to clear one configured key. Neither operation removes a permanent scope.

The shared `OiPaginationThemeData` controls wide-layout distribution, first/last
shortcuts, neighboring page buttons, typography, active colors and dimensions.
Set `distributed: true` for range-left, pages-center and size-right pagination.
Narrow viewports wrap the same controls; page buttons support keyboard activation.

`fitTableToRows: true` lets short result pages finish at their last row and
pagination controls. Taller pages keep bounded scrolling. This uses
`OiTable.shrinkWrap`, which measures the visible page; leave it disabled for large
virtualized viewports. `floatingBulkActions: true` places the existing commands
in a compact inverse `OiBulkBar` at the bottom of the page without moving rows.
Selection remains page-local, clearing it uses the table controller, and commands
retain the same permission, confirmation and per-record receipt behavior.

Set `searchPlaceholder` to explain the configured search scope, such as order,
customer, company or phone. Row selection uses the shared accessible checkbox,
including checked and mixed header states, keyboard focus, Space and Enter.

With `persistQueryInUrl` enabled, the versioned `list` query parameter restores the same choices on a direct link or browser history navigation. It contains user choices, not permanent scopes or permissions. Invalid state is reported with a reset action. Resource links retain a local `returnTo` URI, so Back returns to the original list context. External return destinations are rejected.

## Saved views

`BeakSavedViewStore.model` maps generated name, resource and serialized-state fields of an ordinary resource. The filter drawer exposes Save as view; the toolbar also lists available saved views. A saved view includes filters, preset, search, sorts, page length, selected column keys and chart visibility. Saving staged filter choices does not first apply them to the table.

Saving uses the normal configured graph form; listing uses the normal query source. Define owner/team sharing and access through that resource's backend policy. A shared flag or owner label alone does not authorize sharing. The provider adds the resource namespace, and restored choices remain constrained by the receiving list's permanent scope and the current server policy. Incompatible or malformed saved state produces a configuration error.

## Scroll ownership

`BeakListDefinition.scrollMode` defaults to `BeakListScrollMode.table`: the rows
own a bounded viewport and pagination remains below it. Existing
`fitTableToRows` still fits short results within that viewport.

Choose `BeakListScrollMode.page` for a content-height list. Beak uses the shared
table's `shrinkWrap` and the page layout's body scroll; all loaded rows occupy
their natural height and pagination follows them, potentially below the initial
viewport. Desktop keeps the page heading outside the body scroll. On compact screens,
page mode scrolls the heading together with intrinsic content so tall headings
cannot consume the entire row viewport. Pagination, query
bookmarks and row selection keep the same behavior in both modes.

```dart
BeakListDefinition(
  scrollMode: BeakListScrollMode.page,
  pageSize: 15,
)
```

## Columns, records and actions

`BeakTableColumn.field` keeps model formatting and sorting. `BeakTableColumn` with a `BeakRecordTemplate` composes titles, secondary text, avatars and badges. Bindings declare their field dependencies; Beak adds relationship loads instead of querying separately for each cell. A custom computed binding must declare all dependencies. Bindings can opt into `monospace`, `strong`, semantic `color`, or `badge: true` with a live `tone` callback. `avatarPalette` supplies coordinated foreground/background pairs; a stable identity hash chooses a color. Composite columns sort only when an explicit scalar `sortBy` is supplied.

Inferred columns keep a 160-pixel minimum width and use synchronized horizontal scrolling on narrow screens. Composite columns can set `minWidth` or an explicit `width` for their content. Header and body share the same widths; actions do not squeeze identity fields into a few characters.

`BeakTableColumn.action` selects an existing action from a typed value binding and a map of `BeakActionPresentation` choices. This supports a Next step column with a different command per record. Unknown values can use a configured fallback; unavailable actions are omitted. Buttons share the ordinary pending state and authoritative command runner. They do not execute application callbacks or bypass policy checks.

`BeakActionPresentation` configures existing actions as icons, primary actions or overflow items. `BeakActionPresentation.model` refers to a named server model command. Presentation never grants permission or replaces a transition guard. `bulkModelActions` offers configured commands for a selection, collects shared arguments once and retains a separate receipt for each record; this is not an all-or-nothing transaction across the selection.

For curated selection commands, use `bulkActions` instead of duplicating a list
of model names. Model presentations automatically register the corresponding
bulk command; the `export` key reuses the list's authorized CSV definition and
adds the selected primary keys to its frozen active query.

```dart
bulkActions: [
  const BeakActionPresentation.model(
    'sendPaymentLink', label: 'Send payment links', icon: OiIcons.send,
  ),
  const BeakActionPresentation(key: 'export', icon: OiIcons.download),
  BeakActionPresentation.model(
    'cancel', destructive: true, icon: OiIcons.circleX,
    selectionLabel: (count) => 'Cancel $count orders',
  ),
],
```

A row presentation can supply `labelValue: BeakValueBinding<String>.computed(...)`
for contextual labels such as Call Paul Gruber. Its dependencies load with the
page, rather than triggering row-by-row requests. `icon` and `destructive`
override visual emphasis, and adjacent differing `group` values add a menu
separator. These overrides leave execution, eligibility and authorization intact.

Bindings can choose a marker through `badgeDotFor` or `iconFor`; icons stay inside
labelled badges. `tone` applies to ordinary text as well as badges and may return
null to inherit the default foreground. Declare every field used by these
callbacks in `dependencies`.

The panel command runner coalesces concurrent invocations and retains uncertain outcomes when navigating between mounted pages. Its pending-action banner recovers the same save identity before another dispatch. A definite rejection can be corrected and retried. Pending commands are isolated by principal. This runner is a mounted-panel queue, not durable storage across browser reloads; configured form draft persistence has its separate [durable recovery contract](../forms/drafts-and-review.md).

With configured navigation, a record’s breadcrumb lives in the shell top bar; the body suppresses its duplicate trail. The current record nests under its resource, and selected ancestors expand automatically.
`BeakNavigation(currentRecordBranch: true)` presents that context as a branch
without repeating the resource icon; its default is false. Resource destinations
can declare `BeakNavigationItem.resource(model, recordLabelMonospace: true)` for
code identifiers in both that child and the current breadcrumb. Names keep the
ordinary text role by default. These presentation options retain the existing
route, permission filtering, selection and keyboard navigation.

At the UI kit level, `OiNavItem` and `OiSidebarItem` expose `contextChild` and
`monospace`, both false by default. Ordinary nested groups keep their icons and
indentation. All-contextual child groups remain visible without an accordion;
mixed groups keep expansion behavior. `OiSidebarThemeData.contextBranchColor`
styles the decorative connector, falling back to the subtle border role.
`OiBreadcrumbs.linkStyle` can override the semantic text link role;
the shell forwards `OiAppShellThemeData.breadcrumbLinkStyle`.
`separatorIcon` and `separatorSpacing` override the ordinary slash and 6px gap;
the shell exposes `breadcrumbSeparatorIcon` and `breadcrumbSpacing`. A 16px icon
with 8px each side occupies 32px between labels. Themes can remove
permanent underlines and keep hover typography stable without changing links.

Configured nonwizard record pages use the loaded display field in the heading and place their existing Edit, Save, Cancel and remaining model commands in the shared page header. Their layouts own card surfaces; the page adds no extra enclosing card. Cancel uses the normal unsaved-change guard and reloads persisted values.

Set `BeakFormScreen.recordHeader` to a `BeakRecordTemplate` when the heading needs status badges or identity metadata. It renders the title, inline badges and secondary values from the existing live draft, with the same formatting and inferred relationship loads as the body. Changing the record or refreshing a read view updates the header without another request or application controller.

Read and wizard screens can use `BeakFormTemplate`, `BeakFormTimeline` and `BeakFormActions` over the same draft and loaded relationships. The timeline formats timestamps through the panel policy. Explicit action placement suppresses the matching automatic commands; other available commands remain accessible.

## Authorized CSV export

`BeakListExport` takes an explicit ordered list of direct generated scalar fields. The button freezes the active query and panel `BeakFormatting` at click time and delegates to `BeakExportDataSource`. HTTP and model-routed sources support this capability. A custom transport can implement it; an unsupported source reports a configuration error.

The server exports every matching row, independent of the currently displayed page, and applies query, row and field authorization. The optional `columns` request projection controls field order; unreadable fields are omitted. Unknown, empty or duplicate projections are rejected. Composite cell templates, computed presentation values and related-path flattening are not CSV fields. Use `raw: true` for physical machine values; formatted exports use the explicit locale, currency and time policy. Typed field overrides such as `.currency(minorUnits: true)` travel as validated `BeakExportFormat` metadata, preserving stored cents without rendering them as major units. Password values remain redacted. Download cancellation does not mutate records.

## Remote refresh

`BeakRefreshPolicy` on the panel enables a shared optional refresh interval and refresh on foreground resume. One timer emits invalidation events while the source has listeners and the panel is in the foreground. Local successful mutations still invalidate immediately. Active list, summary and reference consumers refresh through their existing repositories. Clean forms reload; dirty forms retain their draft and optimistic revision checks. Polling does not merge remote changes into unsaved fields.

## Continue reading

- [Tables and filters](tables-and-filters.md)
- [The navigation shell](navigation.md)
- [Actions](actions.md)
- [Search and export](../backend/search-and-export.md)

Rich choice cards can reuse that identity with `details` and an optional
`footnote`. Each entry is a `BeakValueBinding`, so related metadata and visibility
conditions declare their own eager-load dependencies. Set `icon` for a themed
leading icon, `maxLines: null` for wrapping instructions, `textOverflow` for
deliberate natural overflow of short values, and `visibleIf` to omit
optional metadata without empty placeholders. These bindings work identically in
search results, profile cards, tables, and the current form draft; they do not
introduce another fetcher or state store.
