---
title: Custom screens and pages
description: Add whole free-form pages to the panel with BeakScreen, framed or full-bleed, and place them in the sidebar.
---

# Custom screens and pages

After this page you can add a page to the panel that is not a resource: a block
tree or a raw widget, framed by the standard chrome or bled to full width, filed
under any sidebar section you choose.

A [`BeakResource`](../panel/resources.md) turns a model into generated CRUD
pages. A `BeakScreen` is the other kind of page: anything free-form, composed
from [blocks](../blocks/index.md). A dashboard, a profile, an invoice document, a
pricing table, a charts gallery. You register screens on the panel config; each
becomes a route and, by default, a sidebar entry.

## The screen

```dart title="packages/beak_frontend/lib/src/panel/beak_screen.dart"
@immutable
final class BeakScreen {
  /// Creates a custom screen routed at [path].
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

| Parameter | Type | Notes |
| --- | --- | --- |
| `path` | `String` | The route the screen mounts at, e.g. `'/analytics'`. |
| `title` | `String` | Shown in the framed header; the nav-label fallback. |
| `icon` | `BeakIconToken` | The sidebar icon. |
| `body` | `BeakBlock` | The screen content, a single (usually nested) block. |
| `label` | `String?` | Nav-label override; defaults to `title`. |
| `section` | `String?` | Sidebar group heading this screen is filed under. |
| `showInNav` | `bool` | Whether it appears in the sidebar. Default `true`. |
| `framed` | `bool` | Whether to wrap the body in standard page chrome. Default `true`. |

## A screen from a block tree

The body is a `BeakBlock`, so a screen is as simple or as deep as the tree you
give it. A small one is a single module block:

```dart title="apps/beak_superdashboard/lib/screens/faq_screen.dart"
BeakScreen buildFaqScreen() => const BeakScreen(
  path: '/faq',
  title: 'FAQ',
  icon: BeakIconToken(OiIcons.helpCircle),
  section: 'Pages',
  body: BeakFaqBlock(
    model: FaqModel(),
    questionField: FaqColumns.question,
    answerField: FaqColumns.answer,
  ),
);
```

A larger one nests a grid of typed blocks. The charts gallery is one grid with a
card per chart family, all bound to the same seeded tables:

```dart title="apps/beak_superdashboard/lib/screens/charts_screen.dart"
BeakScreen buildChartsScreen() => BeakScreen(
  path: '/charts',
  title: 'Charts',
  icon: const BeakIconToken(OiIcons.barChart2),
  section: 'Showcase',
  body: BeakGridBlock(
    columns: 2,
    gapInPixels: 20,
    children: [
      BeakChartBlock(
        title: 'Revenue (area)',
        type: BeakChartType.area,
        query: const BeakQuerySpec(
          table: 'time_series_points',
          sorts: [BeakSort('sort_index')],
          pagination: analyticsPage,
        ),
        map: seriesPoints('sales_revenue'),
      ),
      // ...more chart cards...
    ],
  ),
);
```

!!! note "What just happened"
    - The screen is a plain function returning a `const` (or nearly const)
      `BeakScreen`. There is no widget code and no `StatefulWidget`.
    - Everything inside `body` is the same [block union](../concepts/the-block-system.md)
      the dashboard and view modes use. A screen is a block tree with a route.

## A screen from a raw widget

When even the block union has no node for what a screen needs, put a
[`BeakWidgetBlock`](custom-blocks-and-widgets.md) at its root. The whole screen
is then your `obers_ui` subtree, still routed and placed in the nav by Beak:

```dart
BeakScreen buildGaugeScreen() => BeakScreen(
  path: '/gauge',
  title: 'Live gauge',
  icon: const BeakIconToken(OiIcons.activity),
  section: 'Showcase',
  body: BeakWidgetBlock((context) => const OiLabel.body('your widget here')),
);
```

The same no-Material rule applies: return `Oi*` widgets from the builder.

## Framed versus full-bleed

`framed` decides the chrome. Left at its default `true`, the body is wrapped in
the standard `OiResourcePage` header and padding, so the screen matches every
resource page. Set it to `false` for a surface that wants the whole canvas: a
calendar, a kanban board, a chat thread.

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
  ),
);
```

## Placing a screen in the nav

Screens share the sidebar with resources, and the same `section` string groups
them. Give a screen `section: 'Apps'` and it lands under the "Apps" heading next
to any resource filed there. The label the sidebar shows comes from
`effectiveLabel`, which falls back to the title:

```dart title="packages/beak_frontend/lib/src/panel/beak_screen.dart"
  /// The label shown in navigation and the page header.
  String get effectiveLabel => label ?? title;
```

Set `showInNav: false` for a page you reach only by navigating to it, not by
clicking the sidebar. An invoice document opened from an orders table is the
classic case: it needs a route, but not a permanent nav entry.

## Registering screens

Screens go on `BeakPanelConfig.pages`. The superdashboard registers all of its
this way:

```dart title="apps/beak_superdashboard/lib/panel/config.dart"
  pages: [
    buildDashboardScreen(),
    buildEmailScreen(),
    buildChatScreen(),
    buildInvoiceScreen(),
    buildProfileScreen(),
    buildChartsScreen(),
    buildUiKitScreen(),
    // ...
  ],
```

Each entry becomes a `go_router` route at its `path` and (unless `showInNav` is
false) a sidebar entry under its `section`. That is the whole wiring: build the
screen, add it to `pages`, and Beak routes and lists it.

## Continue reading

- [Custom screens](../panel/custom-screens.md) the panel-side reference for screen pages.
- [Custom blocks and widgets](custom-blocks-and-widgets.md) put a raw widget at a screen's root.
- [Dashboards](../panel/dashboards.md) the config-driven dashboard, a screen you get for free.
- [Resources](../panel/resources.md) the other kind of page, generated from a model.
