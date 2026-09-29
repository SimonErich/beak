---
title: Extending Beak
description: Six ways past configuration (cells, widgets, data sources, transports, storage drivers, embedding) and where each plugs in, without forking Beak.
type: index
audience: [expert]
status: stable
---

# Extending Beak

After this page you know which escape hatch to reach for when the declarative config runs out, and why using one never turns your project into a fork of Beak.

A schema class, a resource and a tree of blocks cover most of what an admin panel needs. Most, not all. The last stretch is where a low-code tool either lets you drop to the real platform or traps you in its own runtime. Beak drops you to Flutter and obers_ui, through a typed seam, and picks the wiring back up on the other side.

## Which page to read

| You want to... | Read | For that |
| --- | --- | --- |
| Draw a table or detail cell no built-in column covers | [Custom columns](custom-columns.md) | `@Custom`, a tag, and a registered `BeakCustomCellBuilder` |
| Put your own widget in a page or inside a form | [Custom blocks and widgets](custom-blocks-and-widgets.md) | `BeakWidgetBlock`, `BeakFormWidget`, `BeakDraftScope` and the panel's data, formatting and refresh |
| Back Beak with a store it does not know | [Custom data sources](custom-data-sources.md) | The ten methods of `BeakDataSource`, the optional capabilities and the contract suite |
| Keep an existing backend in charge of its models | [Model-owned transports](model-transports.md) | `BeakModel.dataSource`, `capabilities`, `permissions`, `createModel` and `editModel` |
| Store uploads somewhere Beak has no driver for | [Custom storage drivers](custom-storage-drivers.md) | `BeakStorageDriver`, the transport seam, and how a server picks a driver |
| Use Beak inside an app that already exists | [Using Beak widgets standalone](using-beak-widgets-standalone.md) | `beak init`, `beakPanelRoutes`, and a single form, table or block |

A whole free-form page, or a replacement for one resource route, is the same idea one level up. It lives in [Custom screens](../panel/custom-screens.md).

!!! tip "Try the typed path first"
    Before you open a hatch, check whether config already does it. A [typed column](../models/fields.md), a [typed block](../blocks/index.md) or a [view mode](../panel/view-modes.md) keeps the guarantees a hatch trades away: one definition, server-side validation, the same behaviour on every surface. Open a hatch when the typed path has no entry for what you want, not when it is one line longer.

## What every hatch keeps

A hatch in Beak is not a hole in the wall. Each one holds two invariants the rest of the framework holds.

- **You stay in obers_ui.** A custom cell, a custom block, a custom screen all render `Oi*` widgets, never Material. Beak's guard reads Beak's own source and cannot see inside your builder, so that half of the rule is yours.
- **You plug in without editing Beak.** A custom column is a `@Custom` field plus a builder you register. A custom data source is a class implementing an interface. Nothing you add needs a patch to a Beak package, so upgrading the dependency leaves your extension in place.

## The shape of a hatch

Every hatch is one of three shapes, and the shape tells you where the code lives.

| Shape | Hatches | How it plugs in |
| --- | --- | --- |
| A tag you register | Custom columns | The schema field carries `@Custom('tag')`, `beak prepare` generates a `BeakCustomColumn` holding a `BeakColumnTag`, and the panel registers a builder for that tag at startup. Definition and rendering stay on their sides of the wire, linked by a value. |
| An interface you implement | Data sources, model transports, storage drivers | `BeakDataSource`, `BeakModel` and `BeakStorageDriver` are plain types. You write a class and hand it to the panel or the server, and the rest of the stack calls it through the methods it calls the built-ins with. `beak_serverpod` is built this way. |
| A builder that returns a widget | Widget blocks, form widgets, custom screens | A `WidgetBuilder` or a `BeakFormWidget` builder is Flutter itself, framed by Beak's chrome and given access to the panel's dependencies. |

## Where a hatch is wired in

Nothing here needs an entry in a registration list. `beak prepare` reads the project and generates the wiring, so an extension is picked up by living in the file the convention names. Each generated default compiles and changes nothing until your first edit, and `beak eject` writes the starter:

| You are changing | File | Function or class | Starter |
| --- | --- | --- | --- |
| The whole panel configuration, and anything registered at startup | `lib/panel.dart` | `beakPanel(BeakPanelConfig defaults)` | `beak eject panel` |
| The light and dark themes | `lib/theme.dart` | `beakLightTheme()`, `beakDarkTheme()` | `beak eject theme` |
| Which auth routes exist and what they call | `lib/auth.dart` | `beakAuth()` | `beak eject auth` |
| The server: policy, sessions, middleware, routes | `lib/server.dart` | `beakServer(BeakServerDefaults defaults)` | `beak eject server` |
| The storage drivers a server can resolve | `lib/server.dart` | `beakStorageRegistry()` | by hand |
| One resource's presentation | `lib/resources/<feature>/<name>_resource.dart` | a `BeakResource` subclass | `beak eject resource <table>` |
| The panel entrypoint itself | `lib/main.dart` | an authored `BeakPanel(resources: [...])` | `beak eject main` |

A project whose panel is authored has no `lib/panel.dart` to fill in: what that file would return, `lib/main.dart` passes to `BeakPanel` directly. [Two ways to boot a panel](../start-here/generated-or-authored.md) explains the switch. A hand-written `BeakModel` (for a table another system owns) is found by the same rule as a generated one: a `const` class extending `BeakModel`, anywhere under `lib/`.

```console
$ beak eject
  main       lib/main.dart, composed by you instead of generated
  panel      lib/panel.dart
  resource   lib/resources/<table>/<name>_resource.dart (takes a table name)
  theme      lib/theme.dart
  auth       lib/auth.dart
  server     lib/server.dart

beak eject <main|panel|resource|theme|auth|server>
```

## Continue reading

- [Custom columns](custom-columns.md) render any cell with a registered builder.
- [Custom blocks and widgets](custom-blocks-and-widgets.md) drop a raw obers_ui subtree into a page or a form.
- [Custom screens](../panel/custom-screens.md) add whole free-form pages to the panel.
- [The block system](../concepts/the-block-system.md) the declarative vocabulary the hatches fall back from.
