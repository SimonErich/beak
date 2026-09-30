---
title: Detail views
description: Show a record with the generated page, a form screen in read mode, or your own record blocks, and know which of them can edit in place.
type: guide
audience: [beginner, expert]
status: stable
---

# Detail views

After this page you can choose how a record page looks, turn the create form into a read page with an in-place Edit button, and build a read-only sheet from record blocks when a form is the wrong shape.

The page at `/<table>/<id>` is called the show page. It exists for every resource, and you decide how much of it you write.

## At a glance

| You want | Use | Edit |
| --- | --- | --- |
| A sensible page for free | No `read` screen | The Edit button opens the edit route |
| The form's layout, read-only, with editing in place | `BeakFormScreen(roles: {read, ...})` | Edit flips the same page into edit mode |
| A page that is not a form | `BeakCustomResourceScreen(roles: {read})` with record blocks | Whatever you build |

The middle one is what most panels want, and it costs one line: add `BeakScreenRole.read` to the roles of the form screen you already have.

## The generated page

Without a `read` screen, Beak builds the page from the model. A card lists the resource's inputs as values, in the same order as the generated form. A second card has one tab per to-many relationship, with the related rows read-only and up to five of their other columns. The related rows come from the same query as the record, so the page is one round trip.

The header carries the resource's own actions: Edit and Delete when the panel allows them (Edit navigates to the edit route), the model's commands that are available for this record (when editing is allowed), and any `recordActions` whose roles include `read`. That is the whole contract. There is no draft on this page, so there is nothing to stage and nothing to save.

Related rows on this page are read-only. That keeps the page to one query. To change them, edit the record.

## A form screen in read mode

Adding `read` to a form screen's roles makes the show page render that screen's layout with values instead of editors. Cards, columns, tabs and the rest keep their structure. A value is drawn by the same renderer as a table cell, so a badge, a date or an amount looks the same in both places, and the panel's formatting policy applies. Money inputs show the formatted amount, choice inputs their labels, object inputs their grouped values, images the stored picture.

The customer form from [Form screens](form-screens.md) works this way. Foodio's order page goes further: it is one `BeakFormScreen` for `read` and `edit`, with the options that make a detail page:

```dart title="examples/foodio-adminpanel/lib/resources/orders/details/order_detail_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/details/order_detail_screen.dart:orderDetailOptions"
```

These lines are the arguments of `BeakFormScreen(...)`. Reading them top to bottom:

- `roles: {read, edit}` serves the show route and the edit route from one definition.
- `editLabel` and `prominentEdit` rename Edit and make it the primary button in read mode. `compactActions` moves secondary commands into a menu.
- `submitAction` makes Save run the `amend` command instead of a plain save. `showActionsWhileEditing: false` keeps the other commands out of the way while a draft is open.
- `showChangeBar` pins a bar with the number of unsaved changes, the number of fields that need attention, Discard changes and Save.
- `editingLabel` puts an "Editing" badge next to the title while a draft is open. It needs a `recordHeader`.
- `asideFraction: 1 / 3` gives the aside a third of the width, which makes a two-to-one page. On a narrow screen the aside opens in a sheet.

The heading is a record template, so it can carry an icon, a copyable reference, a status badge and secondary lines without a widget:

```dart title="examples/foodio-adminpanel/lib/resources/orders/details/order_detail_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/details/order_detail_screen.dart:orderRecordHeader"
```

[Workflow presentations](workflow-presentations.md) covers `header`, `aside`, metrics, progress and timelines, which is what fills the rest of that page.

### Read, edit, save

Edit is a state change of the page, not a navigation. The form loads once. Pressing Edit turns the values into inputs over a draft of the loaded record. Cancel asks for confirmation when something changed, then discards the draft and returns to values. Save validates, sends one graph commit, and returns to values with the saved record. If someone else changed the record in between, the server refuses the write with "The record changed since it was loaded." and the draft stays open, see [Drafts, review and conflicts](drafts-and-review.md).

The Edit button appears only when the resource allows editing and the model's `editableWhen` accepts the loaded record. Neither is a security boundary. The server enforces `BeakPolicies` on the write.

Two switches help while a draft is open. `showChangeIndicators: true` on the root `BeakFormLayout` marks the fields whose value differs from the loaded record, and rows added in this draft. Foodio's detail layout turns it on. `BeakModeLayout(read: ..., edit: ...)` swaps a subtree by mode, for a notice that changes wording or an add button that becomes a search field.

A `BeakRelationAdd` shown in read mode is a shortcut into editing: tapping it switches the page to edit mode and opens the add dialog, when Edit is available.

### Tabs that share a draft

`BeakTabs(acrossRegions: true)` as the only child of the root layout puts the tab selector above both the body and the aside, and every tab reads the one draft. Foodio's Items tab shows the order's lines read-only with a live count badge:

```dart title="examples/foodio-adminpanel/lib/resources/orders/details/order_detail_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/details/order_detail_screen.dart:orderItemsTab"
```

The overview tab of the same page holds the editable lines, and this tab repeats them as a read-only `tableForm` (Foodio's `orderItems` helper maps its own `allowEditing: false` to `readOnly: true`). Only one placement of a field may be editable, so the second one has to be read-only. [Related records in forms](related-records.md) explains why.

## A page built from record blocks

When the page is not a form, three blocks read a single record: `BeakFieldBlock` for one value, `BeakFieldGroupBlock` for several, and `BeakRelationBlock` for a relationship. They have no query of their own. They read the record from the nearest `BeakRecordScope`, and no built-in page mounts one. You load the record and mount the scope yourself, in a `BeakCustomResourceScreen`. The showcase's keeper sheet is the pattern:

```dart title="examples/showcase/lib/resources/keepers/keeper_sheet.dart"
--8<-- "examples/showcase/lib/resources/keepers/keeper_sheet.dart:keeperSheetBlock"
```

```dart title="examples/showcase/lib/resources/keepers/keeper_sheet.dart"
--8<-- "examples/showcase/lib/resources/keepers/keeper_sheet.dart:recordScopeHandOff"
```

The resource registers it for the read role:

```dart title="examples/showcase/lib/resources/keepers/keeper_resource.dart"
--8<-- "examples/showcase/lib/resources/keepers/keeper_resource.dart"
```

Outside a scope, a record block renders nothing, and it does not throw. If a sheet comes up blank, look for the missing scope first.

`BeakRelationBlock` deserves a warning. It is the relation manager, not a read-only list: each row of a has-many gets a Delete button, and each row of a many-to-many gets Detach and an attach picker. Those act immediately (a delete after a confirmation), through the resource routes, outside any form draft. Use it where that is the intent. For a read-only list of related rows, use the default show page or a `tableForm(readOnly: true)` in a form screen. The block system is described in [The block system](../concepts/the-block-system.md) and [Record blocks](../blocks/record-blocks.md).

## Rules and limits

| Rule | Behavior |
| --- | --- |
| Show page columns | The generated page lists the columns visible in the detail context, so a column with `visibleOn: {BeakContext.detail}` appears there and a form-only column does not. The primary key is never listed. A `BeakFormScreen` for the read role shares its layout with the create and edit forms, so the form columns decide there. Related-row tabs use the related model's detail columns |
| Read role on a form screen | Only when `BeakScreenRole.read` is in `roles`. The default roles are `create` and `edit` |
| No draft on the generated page | Related rows there are read-only. Edit goes to the edit route |
| Record blocks | Need a `BeakRecordScope` that your code mounts. They are for `BeakCustomResourceScreen`, not for a form screen's layout |
| Relation block writes | Delete and Detach buttons write immediately, without a draft. A graph-only model closes the per-record routes, so the server refuses them there |
| Opting out of read mode | `BeakFormWidget(showOnRead: false)` keeps a custom editor off the read page. Inputs always render as values |
| Hidden by permission | A field the account cannot read is left out of the read page like it is left out of the form |
| Wizard chrome | A screen with steps has no generated page frame. `recordHeader` and record actions do not appear there |
| Fields loaded | A value from a related record is shown only if the layout or a binding declares it, see [Workflow presentations](workflow-presentations.md#one-draft-many-readers) |

## Verify it

The generated layout, the read presentation and the record blocks have tests:

```bash
cd packages/beak_frontend
flutter test test/src/pages/beak_default_show_layout_test.dart test/src/form/detail_presentation_test.dart
```

```bash
cd examples/showcase
flutter test test/block_type_matrix_test.dart
```

Each ends with `All tests passed!`. To see the difference in the shop, run it and open a category (generated show page, with a tab for its attributes), then a customer (form screen in read mode, with Edit in place).

## Reference

| Symbol | Where it is documented |
| --- | --- |
| `BeakScreenRole`, `BeakFormScreen`, `BeakCustomResourceScreen` | [Screens and form layouts](../reference/screens-and-layouts.md#roles-and-routes) |
| `BeakModeLayout`, `BeakTabs`, `BeakFormLayout.showChangeIndicators` | [Screens and form layouts](../reference/screens-and-layouts.md#layout-containers) |
| `BeakRecordScope`, `BeakDraftScope` | [Screens and form layouts](../reference/screens-and-layouts.md#beakdraftscope-and-beakrecordscope) |
| `BeakFieldBlock`, `BeakFieldGroupBlock`, `BeakRelationBlock` | [Blocks](../reference/blocks.md) |
| `beakDefaultShowLayout` | `packages/beak_frontend/lib/src/pages/beak_default_show_layout.dart` |

## Continue reading

- [Workflow presentations](workflow-presentations.md) metrics, progress, timelines and record templates for the rest of a detail page.
- [Drafts, review and conflicts](drafts-and-review.md) what happens when an edit meets a newer version.
- [Printable record documents](record-documents.md) a print action for the read page.
- [Actions](../panel/actions.md) the header buttons a detail page carries.
