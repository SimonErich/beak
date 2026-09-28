---
title: Custom blocks and widgets
description: Embed custom widgets while sharing Beak's data, formatting, refresh and draft infrastructure.
---

# Custom blocks and widgets

Use `BeakWidgetBlock` when a page needs a bespoke widget. It composes with ordinary
Beak cards, metrics, tables and grids. Import `package:beak/panel.dart` for Beak and
`package:beak/ui.dart` for the `Oi*` widgets.

```dart
BeakWidgetBlock((context) => const ShopReceivablesCard())
```

A custom widget keeps the panel's theme, current data source and display policy.
`beakDependencies(context)<BeakDataSource>()` resolves the nearest panel's source;
`BeakResourceRepository` supplies the normal typed error boundary;
`useBeakDataRevision(source, table: ...)` refreshes on confirmed writes and owns
its subscription. Use `BeakFormatting.of(context)` for numbers and dates.

The shop's reusable receivables card computes the sum of issued invoices, displays
minor-unit money accurately, handles loading and errors, supports retry, and
refreshes after a payment action. The same widget is embedded in its dashboard and
Operations page.

```dart title="examples/clean_beak_config/lib/widgets/receivables_card.dart"
--8<-- "examples/clean_beak_config/lib/widgets/receivables_card.dart:ShopReceivablesCard"
```

This is also the embedding pattern for an existing Flutter application: install
Beak's dependency and formatting scopes around a custom composition, or pass a
data source explicitly to standalone widgets such as `BeakStatCard` and
`BeakConfiguredForm`. See [standalone widgets](using-beak-widgets-standalone.md).

## Custom content inside a form

`BeakFormWidget` receives the existing `BeakDraftRecord`. Read typed fields with
`draft.read(Model.field)`, write them with `draft.set(...)`, and add related drafts
with `draft.addRow(Model.children)`. The normal form still owns validation,
cancellation, persistence and recovery.

Use `BeakDraftScope.of(context).enabled` before offering custom editing actions.
It includes inherited section guards and saving state. Set `showOnRead: false`
when the widget is an editing tool with no useful read presentation.

```dart
BeakFormWidget(
  showOnRead: false,
  builder: (context, draft) => ShopVariantBuilder(draft: draft),
)
```

The shop's [variant builder](../models/dynamic-attributes-and-variants.md) previews
combinations and stages nested attribute rows through this interface. It does not
need a second form controller or a separate save handler.

Prefer the standard data blocks when their presentation fits. Custom widgets own
their accessibility, loading/error presentation and responsive layout. Use the
same `Oi*` controls as Beak, without Material or Cupertino dependencies.

## Continue reading

- [Custom screens](custom-screens-and-pages.md).
- [Dynamic attributes and variants](../models/dynamic-attributes-and-variants.md).
