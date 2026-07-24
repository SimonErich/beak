---
title: Custom screens
description: Add any free-form page to the panel with BeakScreen: a route, a nav entry, and a block-tree body, including replacing the dashboard at the home route.
---

# Custom screens

After this page you can add pages to the panel that are not tied to a resource: an
analytics landing page, a chat app, an invoice document, a pricing table. Each one
is a `BeakScreen`: a route, an optional sidebar entry, and a body made of
[blocks](../blocks/index.md).

Where a `BeakResource` gives you generated list/detail/form pages for a model, a
`BeakScreen` gives you a blank canvas. You compose it from the same block tree
everything else in Beak uses.

## The anatomy of a screen

A screen is data. You declare where it lives, how it shows in the shell, and what
it contains, and Beak turns that into a route and a nav item.

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
| `path` | The route the screen mounts at (e.g. `'/analytics'`, or `'/'` to own the home page). |
| `title` | Shown in the framed header and used as the nav label fallback. |
| `icon` | The sidebar icon, a `BeakIconToken` wrapping an `OiIcons` value. |
| `body` | The screen content: any single `BeakBlock` (usually a column or grid of blocks). |
| `label` | Overrides the nav label; defaults to `title`. |
| `section` | Optional sidebar group heading this screen files under. |
| `showInNav` | Whether the screen appears in the sidebar. Set `false` for detail pages reached only by navigation. |
| `framed` | Whether to wrap the body in the standard page chrome (header + padding). Set `false` for full-bleed screens. |

You register screens on `BeakPanelConfig.pages`. Each becomes a `GoRoute` inside the
panel shell, and (unless `showInNav` is false) an `OiNavItem` in the sidebar.

```dart title="apps/beak_superdashboard/lib/panel/config.dart"
BeakPanelConfig buildSuperdashboardConfig({
  String apiBaseUrl = 'http://localhost:8180',
}) => BeakPanelConfig(
  title: 'Beak Superdashboard',
  apiBaseUrl: apiBaseUrl,
  resources: buildResources(),
  pages: [
    buildDashboardScreen(),
    buildEmailScreen(),
    buildChatScreen(),
    buildInvoiceScreen(),
    // ... more screens
  ],
);
```

## A simple screen

The showcase's starter page is one screen with one block in its body, the smallest
useful shape. Copy it when you begin a new page.

```dart title="apps/beak_superdashboard/lib/screens/starter_screen.dart"
BeakScreen buildStarterScreen() => const BeakScreen(
  path: '/starter',
  title: 'Starter',
  icon: BeakIconToken(OiIcons.filePlus),
  section: 'Showcase',
  body: BeakCardBlock(
    child: BeakMarkdownBlock('''
# Starter page

This is an empty page. Drop any `BeakBlock` into its body to begin.
'''),
  ),
);
```

!!! note "What just happened"
    - `section: 'Showcase'` groups this screen under a "Showcase" heading in the
      sidebar. Screens with the same section string cluster together.
    - The body is a single `BeakCardBlock` wrapping a `BeakMarkdownBlock`. Swap that
      for a `BeakGridBlock` or `BeakColumnBlock` when the page grows past one block.
    - `framed` defaults to `true`, so the page gets the standard header with the
      title and padding. No extra wiring.

## Replacing the dashboard at `/`

A screen whose `path` is `/` claims the home route and replaces Beak's built-in
stats-and-charts dashboard. The showcase does exactly this to ship a designed
landing page.

```dart title="apps/beak_superdashboard/lib/panel/dashboard.dart"
BeakScreen buildDashboardScreen() => BeakScreen(
  path: '/',
  title: 'Dashboard',
  icon: const BeakIconToken(OiIcons.layoutDashboard),
  body: BeakColumnBlock(
    gapInPixels: 20,
    children: [_kpis(), _chartsAndDonut(), _mapAndAudience(), _tables()],
  ),
);
```

When Beak sees a page at `/`, it drops the generated `BeakDashboard` and mounts your
screen instead. You never see both. That trade-off is covered from the dashboard
side on [Dashboards](dashboards.md).

## Module screens and `framed: false`

Some pages want the full viewport with no page chrome: a calendar, a kanban board, a
chat thread, an inbox. Set `framed: false` and Beak renders the body edge to edge.
These "module" screens pair a single high-level block with a model.

```dart title="apps/beak_superdashboard/lib/screens/chat_screen.dart"
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

The invoice screen shows the other reason to reach for a screen: a detail document
built from one module block, wired to a fixed record and its line items through
column constants.

```dart title="apps/beak_superdashboard/lib/screens/invoice_screen.dart"
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
    // ... bill-to and totals fields
  ),
);
```

The module blocks (`BeakChatBlock`, `BeakInvoiceBlock`, `BeakInboxBlock`,
`BeakFileManagerBlock`, and friends) are cataloged in
[Module blocks](../blocks/module-blocks.md).

## Hiding a screen from the sidebar

Set `showInNav: false` for a page you reach by navigation but do not want cluttering
the sidebar: a document opened from a table row, or a detail view behind a "view"
action. The route still exists; only the nav entry disappears. The effective nav
label, when a screen does show, is `label ?? title`:

```dart title="packages/beak_frontend/lib/src/panel/beak_screen.dart"
/// The label shown in navigation and the page header.
String get effectiveLabel => label ?? title;
```

## Reference

`BeakScreen` is immutable and `const`-constructible. Full field docs live in the
source; the load-bearing defaults are `showInNav = true` and `framed = true`. A
screen contributes to two places in the shell: the router (a `GoRoute` at `path`)
and, when `showInNav`, the sidebar and the command bar.

## Continue reading

- [Dashboards](dashboards.md) the home route, and how a screen at `/` replaces the generated dashboard.
- [The navigation shell](the-navigation-shell.md) how sections, the sidebar, and the command bar pick up your screens.
- [Module blocks](../blocks/module-blocks.md) the chat, inbox, invoice, and file-manager blocks screens are built from.
- [Custom screens and pages](../extending/custom-screens-and-pages.md) extending Beak with screens that reach past the built-in blocks.
