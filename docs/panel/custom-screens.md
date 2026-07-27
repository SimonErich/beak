---
title: Custom screens
description: Add any free-form page to the panel by dropping a BeakScreen in lib/screens/: a route, a nav entry, and a block-tree body, including the dashboard at the home route.
---

# Custom screens

After this page you can add pages to the panel that are not tied to a resource:
a restock list, an analytics landing page, a chat app, an invoice document. Each
one is a `BeakScreen`: a route, an optional sidebar entry, and a body made of
[blocks](../blocks/index.md).

Where a `BeakResource` gives you generated list/detail/form pages for a model, a
`BeakScreen` gives you a blank canvas. You compose it from the same block tree
everything else in Beak uses, which is why it still gets the panel's data
wiring, theming and empty states.

## Where a screen lives

Put the file in `lib/screens/`. `beak prepare` scans that directory and wires
what it finds into the panel. There is no list to register it on.

```text
lib/
  screens/
    restock_screen.dart     <- discovered
  dashboard.dart            <- the screen at "/"
  beak/
    panel.g.dart            <- generated, lists them for you
```

Beak recognises two shapes, so you can write whichever reads better:

```dart title="packages/beak_cli/lib/src/project/beak_discovery.dart"
/// `BeakScreen` declarations: a top-level variable of that type, or a
/// zero-argument function returning one.
List<BeakDiscoveredSymbol> _scanScreens(List<BeakDiscoveryIssue> issues) {
```

A `const BeakScreen` variable is the simplest. A function is for a screen whose
body is assembled at startup. A function that takes a required argument is an
error at `beak prepare` time, with the reason, rather than a screen that
silently never appears.

The generated panel lists every discovered screen on `BeakPanelConfig.pages`:

```dart title="examples/store/lib/beak/panel.g.dart"
pages: [dashboard.beakDashboard(), restockScreen],
```

Each entry becomes a `GoRoute` inside the panel shell and, unless `showInNav` is
false, an `OiNavItem` in the sidebar and a destination in the command bar.

## The anatomy of a screen

A screen is data. You declare where it lives, how it shows in the shell, and
what it contains.

```dart title="packages/beak_frontend/lib/src/panel/beak_screen.dart"
const BeakScreen({
  required this.path,
  required this.title,
  required this.icon,
  required this.body,
  this.label,
  this.section,
  this.showInNav = true,
  this.framed = true,
});
```

| Field | What it does |
| --- | --- |
| `path` | The route the screen mounts at (e.g. `'/restock'`, or `'/'` to own the home page). |
| `title` | Shown in the framed header and used as the nav label fallback. |
| `icon` | The sidebar icon, a `BeakIconToken` wrapping an `OiIcons` value. |
| `body` | The screen content: any single `BeakBlock` (usually a column or grid of blocks). |
| `label` | Overrides the nav label; defaults to `title`. |
| `section` | Optional sidebar group heading this screen files under. Use a resource's section to file it beside them. |
| `showInNav` | Whether the screen appears in the sidebar. Set `false` for pages reached only by navigation. |
| `framed` | Whether to wrap the body in the standard page chrome (header and padding). Set `false` for full-bleed screens. |

## A simple screen

The store's restock page is a screen the generated pages could not produce:
everything running low, in one list, next to the numbers that matter. Two
metrics, one filtered table, one `const` expression.

```dart title="examples/store/lib/screens/restock_screen.dart"
const BeakScreen restockScreen = BeakScreen(
  path: '/restock',
  title: 'Restock',
  icon: BeakIconToken(OiIcons.packageSearch),
  section: 'Catalog',
  body: BeakColumnBlock(
    gapInPixels: 20,
    children: [
      BeakGridBlock(
        columns: 12,
        children: [
          BeakMetricBlock(
            span: BeakSpan(columns: 6),
            label: 'Out of stock',
            aggregate: BeakAggregateSpec.count(
              table: 'products',
              filter: BeakFieldFilter(
                column: ProductColumns.stock,
                operator: BeakOperator.eq,
                value: BeakIntValue(0),
              ),
            ),
            icon: OiIcons.packageX,
          ),
          BeakMetricBlock(
            span: BeakSpan(columns: 6),
            label: 'Stock on hand',
            aggregate: BeakAggregateSpec.sum(
              table: 'products',
              column: ProductColumns.stock,
            ),
            icon: OiIcons.package,
          ),
        ],
      ),
      BeakCardBlock(
        title: 'Running low',
        child: BeakTableBlock(
          model: ProductModel(),
          columns: [
            ProductColumns.name,
            ProductColumns.sku,
            ProductColumns.stock,
            ProductColumns.status,
          ],
          baseFilter: BeakFieldFilter(
            column: ProductColumns.stock,
            operator: BeakOperator.lt,
            value: BeakIntValue(10),
          ),
          initialSpec: BeakQuerySpec(
            table: 'products',
            sorts: [BeakSort('stock')],
          ),
        ),
      ),
    ],
  ),
);
```

!!! note "What just happened"
    - `ProductColumns` and `ProductModel` came from the `@Resource` class in
      `lib/models/product.dart`, so this screen cannot outlive a renamed field.
    - `section: 'Catalog'` files the screen under the same sidebar heading as
      the catalog resources. Screens and resources sharing a section cluster
      together.
    - The two aggregates are computed by the API, not in the browser.
    - `framed` defaults to `true`, so the page gets the standard header and
      padding. Nothing else was wired.

## Replacing the dashboard at `/`

A screen whose `path` is `/` claims the home route and replaces Beak's built-in
stats-and-charts dashboard. That screen has a fixed home of its own:
`lib/dashboard.dart`, declaring `BeakScreen beakDashboard()`.

```bash
beak eject dashboard
```

The store's says what it is in its own doc comment:

```dart title="examples/store/lib/dashboard.dart"
/// The screen mounted at `/`, replacing the generated dashboard.
///
/// Four numbers, one chart and the two lists a shopkeeper opens the panel to
/// read. Every figure is a [BeakAggregateSpec] the API computes — nothing is
/// counted in the browser, and nothing is hardcoded.
BeakScreen beakDashboard() => const BeakScreen(
  path: '/',
  title: 'Today',
  icon: BeakIconToken(OiIcons.layoutDashboard),
  body: BeakColumnBlock(gapInPixels: 20, children: [_kpis, _revenue, _lists]),
);
```

When a page claims `/`, Beak drops the generated `BeakDashboard` and mounts your
screen instead. You never see both. That trade-off is covered from the other
side on [Dashboards](dashboards.md).

`lib/dashboard.dart` is a convention file, not a screens-directory file. Beak
puts it first in `pages` and every other screen after it, so the home page has
one obvious home. Keep `/` there rather than in `lib/screens/`: two pages
claiming the same path is two routes claiming the same path.

## Module screens and `framed: false`

Some pages want the full viewport with no page chrome: a calendar, a kanban
board, a chat thread, an inbox. Set `framed: false` and Beak renders the body
edge to edge. These "module" screens pair a single high-level block with a
model.

```dart title="examples/superdashboard/lib/screens/chat_screen.dart"
BeakScreen buildChatScreen() => const BeakScreen(
  path: '/chat',
  title: 'Chat',
  icon: BeakIconToken(OiIcons.messageCircle),
  section: 'Apps',
  framed: false,
  body: BeakChatBlock(
    model: ChatMessageModel(),
    authorField: ChatMessageColumns.senderName,
    bodyField: ChatMessageColumns.body,
    timeField: ChatMessageColumns.sentAt,
    composeRecord: _composeMessage,
  ),
);
```

The invoice screen shows the other reason to reach for a screen: a detail
document built from one module block, wired to a fixed record and its line items
through generated column constants.

```dart title="examples/superdashboard/lib/screens/invoice_screen.dart"
BeakScreen buildInvoiceScreen() => const BeakScreen(
  path: '/invoice',
  title: 'Invoice',
  icon: BeakIconToken(OiIcons.fileText),
  section: 'Apps',
  body: BeakInvoiceBlock(
    model: InvoiceModel(),
    recordId: SeedIds.invoice,
    lineItemsModel: InvoiceItemModel(),
    lineItemsForeignKey: InvoiceItemColumns.invoiceId,
    metaFields: [
      InvoiceColumns.number,
      InvoiceColumns.status,
      InvoiceColumns.issueDate,
      InvoiceColumns.dueDate,
    ],
    // ...bill-to and totals fields
  ),
);
```

The module blocks (`BeakChatBlock`, `BeakInvoiceBlock`, `BeakInboxBlock`,
`BeakFileManagerBlock`, and friends) are cataloged in
[Module blocks](../blocks/module-blocks.md).

## Hiding a screen from the sidebar

Set `showInNav: false` for a page you reach by navigation but do not want
cluttering the sidebar: a document opened from a table row, or a detail view
behind a "view" action. The route still exists; only the nav entry disappears.
The effective nav label, when a screen does show, is `label ?? title`:

```dart title="packages/beak_frontend/lib/src/panel/beak_screen.dart"
/// The label shown in navigation and the page header.
String get effectiveLabel => label ?? title;
```

Hiding a *resource* is a different lever, and it lives in `beak.yaml`:

```yaml title="examples/store/beak.yaml"
resources:
  # ...the six navigable resources
  # Lines are always reached through their order, never from the sidebar —
  # but they keep their API, their model and their relationships.
  order_items:
    hidden: true
```

## Reference

`BeakScreen` is immutable and `const`-constructible. Full field docs live in the
source; the load-bearing defaults are `showInNav = true` and `framed = true`. A
screen contributes to two places in the shell: the router (a `GoRoute` at
`path`) and, when `showInNav`, the sidebar and the command bar.

Rendering is one small widget, which is worth knowing when a screen looks wrong:

```dart title="packages/beak_frontend/lib/src/pages/beak_screen_view.dart"
final body = BeakBlockHost(block: screen.body);
if (!screen.framed) {
  return body;
}
return OiResourcePage(
  label: screen.effectiveLabel,
  title: screen.title,
  actions: const [],
  child: SingleChildScrollView(child: body),
);
```

A framed screen scrolls its body for you. An unframed screen owns its viewport,
scrolling included.

## Continue reading

- [Dashboards](dashboards.md) the home route, and how `lib/dashboard.dart` replaces the generated dashboard.
- [The navigation shell](the-navigation-shell.md) how sections, the sidebar, and the command bar pick up your screens.
- [Module blocks](../blocks/module-blocks.md) the chat, inbox, invoice, and file-manager blocks screens are built from.
- [Generated code](../models/generated-code.md) what `beak prepare` writes after it finds your screen.
- [Custom screens and pages](../extending/custom-screens-and-pages.md) extending Beak with screens that reach past the built-in blocks.
