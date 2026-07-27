---
title: The shell
description: The app shell around every route: the collapsible sidebar, and framed versus full-bleed screens.
---

# The shell

After this page you can control the panel's sidebar behavior and decide whether a
screen gets the standard page chrome or renders edge to edge.

Every route in a Beak panel is wrapped in the same shell: an `OiAppShell` with a
sidebar on one edge, a top bar with search and the theme toggle, and your page in
the middle. Two `beak.yaml` keys shape the sidebar, and one field per screen
decides whether the page inside sits in a frame or fills the viewport.

## The sidebar

The sidebar is generated from your resources and pages, grouped by their optional
`section` headings. You never assemble it. Two booleans control how it behaves,
and they are scalars, so they live in `beak.yaml`:

```yaml title="beak.yaml"
theme:
  sidebar:
    collapsible: true
    startCollapsed: false
```

Those are the defaults, so the panel opens with a full labelled sidebar that the
user can collapse to an icon rail. Set `startCollapsed: true` to open narrow, or
`collapsible: false` to pin the sidebar open.

| Key | Default | Effect |
| --- | --- | --- |
| `theme.sidebar.collapsible` | `true` | Whether the user can collapse the sidebar to an icon rail at all. |
| `theme.sidebar.startCollapsed` | `false` | Whether the panel opens with the sidebar already collapsed. |

`beak prepare` emits them as two fields on the generated `BeakPanelConfig`:

```dart title="packages/beak_frontend/lib/src/panel/beak_panel_config.dart"
/// Whether the sidebar can collapse to an icon rail.
final bool sidebarCollapsible;

/// Whether the sidebar starts collapsed (an icon-only rail).
final bool sidebarDefaultCollapsed;
```

Both flow straight into the `OiAppShell` that wraps every page:

```dart title="packages/beak_frontend/lib/src/panel/beak_router.dart"
child: OiAppShell(
  label: config.title,
  title: config.title,
  sidebarCollapsible: config.sidebarCollapsible,
  sidebarDefaultCollapsed: config.sidebarDefaultCollapsed,
  currentRoute: currentPath,
  onNavigate: (route) => context.go(route),
  // ... actions: search, notifications, theme toggle.
  // ... navigation: one OiNavItem per resource and per screen.
  child: child,
),
```

The shell builds one navigation entry per resource and per screen, keyed by each
one's `icon` and `section`. You do not assemble the sidebar yourself; you declare
resources and screens, and the shell lays them out.

Where each entry comes from:

| Entry | Declared in | Icon, label and section from |
| --- | --- | --- |
| A resource | An `@Resource` class in `lib/models/<name>.dart` | `resources.<table>` in `beak.yaml` |
| A screen | A `BeakScreen` in `lib/screens/<name>.dart` | The screen's own `icon`, `label` and `section` |

A resource marked `hidden: true` in `beak.yaml` keeps its model, its API and its
relationships; it only loses its sidebar entry. That is how the showcase
files 32 of its 49 tables away while keeping them reachable through the resources
that own them. The [navigation shell](../panel/the-navigation-shell.md) page
covers the command bar and notification bell that share this top bar.

## Framed versus full-bleed screens

Inside the shell, a screen can render two ways. A **framed** screen gets the
standard page chrome: a titled header and padding, wrapped in an `OiResourcePage`
and made scrollable. A **full-bleed** screen skips all of that and owns its whole
viewport, which is what a calendar or a kanban board wants. The switch is one
field on `BeakScreen`:

```dart title="packages/beak_frontend/lib/src/panel/beak_screen.dart"
/// Whether to wrap the body in the standard page chrome (`OiResourcePage`
/// header + padding). Set false for full-bleed screens like a calendar or
/// kanban board.
final bool framed;
```

It defaults to `true`, so every screen is framed unless you say otherwise. The
renderer is a two-line decision: an unframed screen returns its block body
directly; a framed one wraps it in the page chrome.

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

!!! note "When to go full-bleed"
    Reach for `framed: false` when the screen's own content already provides its
    header and manages its own scrolling: a full-height calendar, a kanban board
    with its own columns, an email client, a chat view. For a dashboard, a
    profile page, or a settings form, leave `framed` at its default so the screen
    gets a consistent titled header and comfortable padding.

Here is a framed screen (the default), so the block body sits inside a titled,
padded page. The whole file is one function under `lib/screens/`, which
`beak prepare` discovers, routes at `/typography` and files under the "Showcase"
heading:

```dart title="examples/superdashboard/lib/screens/typography_screen.dart"
BeakScreen buildTypographyScreen() => const BeakScreen(
  path: '/typography',
  title: 'Typography',
  icon: BeakIconToken(OiIcons.heading),
  section: 'Showcase',
  body: BeakCardBlock(
    title: 'Type scale',
    child: BeakColumnBlock(
      // ... one BeakTextBlock per size in the ramp ...
    ),
  ),
);
```

Because `framed` is not set, it defaults to `true`, and the type-scale card
renders under a "Typography" header with the shell's standard padding.

The showcase's chat screen is the other half of the pair. `OiChat` wants the
whole viewport and brings its own header, so the screen opts out of the frame:

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

The sidebar and top bar stay exactly where they are. `framed` decides only what
happens inside them.

## Continue reading

- [The navigation shell](../panel/the-navigation-shell.md) the command bar, search, and notification bell in the top bar.
- [Custom screens](../panel/custom-screens.md) building the block bodies these frames wrap.
- [Maintenance and coming soon](../panel/maintenance-and-coming-soon.md) the full-screen states that replace the shell.
- [Theming basics](theming-basics.md) the theme this shell paints.
