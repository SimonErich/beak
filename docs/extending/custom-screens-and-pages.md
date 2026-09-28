---
title: Custom screens and pages
description: Register complete custom screens alongside resource CRUD pages.
---

# Custom screens and pages

A `BeakScreen` declares a route, navigation entry and content tree. Register it in
`BeakPanel.pages` alongside the usual `resources`; no application router or data
transport is needed.

```dart
BeakPanel(
  pages: [shopOverview(), shopOperations()],
  resources: [OrderResource(), InvoiceResource(), ProductResource()],
)
```

The canonical shop includes a live overview and an Operations page. Operations
combines a reusable custom billing widget with fulfillment and replenishment
tables. Typed filters define the queues, and standard resource links open records
for editing. Its category import widget previews and validates CSV before saving.

```dart title="examples/clean_beak_config/lib/operations.dart"
--8<-- "examples/clean_beak_config/lib/operations.dart:shopOperations"
```

| Screen option | Purpose |
| --- | --- |
| `path` | Route, such as `/operations` or `/` for the dashboard. |
| `title` / `label` | Page title and optional distinct navigation label. |
| `icon` | A `BeakIconToken` for navigation. |
| `section` | Optional navigation group. |
| `body` | Composable block tree, including `BeakWidgetBlock`. |
| `showInNav` | Hide a route that is reached through another screen. |
| `framed` | Adds the page header, gutters and scrolling; set false for full-bleed content. |

The page frame is transparent. Cards, charts and other surface blocks paint their
own backgrounds, so the panel canvas stays visible between them. Use one
`BeakCardBlock` around the body when you deliberately want a single shared card.
Generated record details follow the same rule as configured forms: the layout
owns its surfaces, without an additional card enclosing the whole page.

Projects using generated host conventions can still place top-level `BeakScreen`
variables or zero-argument factories in `lib/screens/`; `beak prepare` discovers
those pages. A `beakDashboard()` factory in `lib/dashboard.dart` provides the home
page. Choose explicit panel registration or the generated conventions according
to how the application is bootstrapped.

## Replace one resource route

For a bespoke resource presentation, include `BeakCustomResourceScreen` in the
resource's `screens`. Its `roles` select list/read/create/edit routes, and its
builder receives the record identifier for record routes. Resource routing and
permissions remain in place. Custom rendering does not grant permission to write:
all mutations still pass through the configured backend policies.

Use [custom blocks and widgets](custom-blocks-and-widgets.md) for shared data and
refresh wiring, and [declarative forms](../panel/forms.md) for standard
forms that need only a different layout.

## Continue reading

- [Custom widgets](custom-blocks-and-widgets.md).
- [Forms](../panel/forms.md).
