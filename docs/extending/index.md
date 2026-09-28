---
title: Extending Beak
description: When config runs out, drop to Flutter through a typed escape hatch without forking Beak.
---

# Extending Beak

After this page you know which escape hatch to reach for when the declarative
config runs out, and why reaching for one never locks you into a fork of Beak.

Beak's bet is that a schema class, a `beak.yaml`, and a tree of blocks cover
most of what an admin panel needs. Most, not all. The last stretch is where
every low-code tool either lets you drop to the real platform or traps you in
its own runtime. Beak drops you to Flutter and `obers_ui`, through a typed
seam, and picks the wiring back up on the other side.

## The two things every hatch keeps

An escape hatch in Beak is not a hole in the wall. Each one holds two invariants
the rest of the framework holds:

- **You stay in `obers_ui`.** A custom cell, a custom block, a custom screen:
  all render `Oi*` widgets, never Material. The no-Material rule is the house
  style, and the hatches are furnished to match. (Beak's own guard cannot see
  inside your builder, so that last part is on you.)
- **You plug in without editing Beak.** A custom column is a `@Custom` field
  plus a builder you register. A custom data source is a class that implements
  an interface in `package:beak/beak.dart`. Nothing you add requires a patch to
  the Beak packages. Upgrade the dependency and your extension still fits.

## The hatches

| Hatch | Reach for it when | Page |
| --- | --- | --- |
| A custom column | a table or detail cell needs a widget no built-in column renders (a sparkline, a bespoke status pill). | [Custom columns](custom-columns.md) |
| A widget block | a page needs a subtree no block in the union covers. | [Custom blocks and widgets](custom-blocks-and-widgets.md) |
| A custom screen | you want a whole free-form page, not a resource's generated CRUD. | [Custom screens and pages](custom-screens-and-pages.md) |
| A model-owned transport | resources use an existing backend and share live permissions or separate write commands. | [Model-owned transports](model-transports.md) |
| A custom data source | your records live behind something other than the generated REST API. | [Custom data sources](custom-data-sources.md) |
| A custom storage driver | uploaded files belong in a store beyond memory, local disk, S3, or FTP. | [Custom storage drivers](custom-storage-drivers.md) |
| Beak widgets on their own | you want one Beak surface inside an app that is not a full panel. | [Using Beak widgets standalone](using-beak-widgets-standalone.md) |

!!! tip "Try the typed path first"
    Before you open a hatch, check whether config already does it. A
    [rich column type](../models/column-types.md), a
    [typed block](../blocks/index.md), or a
    [view mode](../panel/view-modes.md) keeps the one-definition guarantees the
    hatches trade away. The hatch is the answer when the typed path genuinely has
    no entry for what you want, not when it is one line longer.

## Where a hatch is wired in

Nothing on this page needs an entry in a registration list, because there are no
registration lists left. `beak prepare` reads the project and generates the
wiring, so an extension is picked up by living in the file the convention names.

| You are changing | The file |
| --- | --- |
| One resource's filters, actions, view modes, detail layout, form steps | `lib/resources/<table>.dart` |
| A custom page, with its own route and nav entry | `lib/screens/<name>.dart` |
| The whole panel config, including anything registered at startup | `lib/panel.dart` |
| The server: middleware, policy, auth sessions, the storage registry | `lib/server.dart` |

Each of those files receives what Beak derived and returns what you want, so it
compiles and changes nothing until your first edit. `beak eject <part>` writes
the starter for you. [Escape hatches](../models/escape-hatches.md) covers the
narrower ones (a single resource, a hand-written `BeakModel`, a table another
system owns) in full.

## The shape of a hatch

Every hatch is one of two shapes, and knowing which tells you where the code
lives.

- **A tag you register.** Custom columns and custom cell renderers work this
  way. The schema field carries `@Custom('stock_bar')`, which generates a
  `BeakCustomColumn` holding a `BeakColumnTag`; the panel registers a builder
  for that tag at startup. Definition and rendering stay on their proper sides
  of the wire, linked by a value.
- **An interface you implement.** Custom data sources and storage drivers work
  this way. `BeakDataSource` and `BeakStorageDriver` are plain interfaces in
  `package:beak/beak.dart`; you write a class, register it, and the rest of the
  stack calls it through the same methods it calls the built-ins with. This is
  the seam used by `beak_serverpod` to keep backend-specific transport out of
  the packages above it.

Widget blocks and screens sit between the two: they take a `WidgetBuilder` or a
`BeakBlock` body, which is Flutter itself, framed by Beak's chrome.

## Continue reading

- [Custom columns](custom-columns.md) render any cell with a registered builder.
- [Custom blocks and widgets](custom-blocks-and-widgets.md) drop a raw `obers_ui` subtree into a block tree.
- [Custom screens and pages](custom-screens-and-pages.md) add whole free-form pages to the panel.
- [Escape hatches](../models/escape-hatches.md) the four convention files, narrowest first.
- [The block system](../concepts/the-block-system.md) the declarative vocabulary the hatches fall back from.
