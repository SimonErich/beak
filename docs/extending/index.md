---
title: Extending Beak
description: When config runs out, drop to Flutter through a typed escape hatch without forking Beak.
---

# Extending Beak

After this page you know which escape hatch to reach for when the declarative
config runs out, and why reaching for one never locks you into a fork of Beak.

Beak's bet is that a model definition, a panel config, and a tree of blocks
cover most of what an admin panel needs. Most, not all. The last stretch is
where every low-code tool either lets you drop to the real platform or traps you
in its own runtime. Beak drops you to Flutter and `obers_ui`, through a typed
seam, and picks the wiring back up on the other side.

## The two things every hatch keeps

An escape hatch in Beak is not a hole in the wall. Each one holds two invariants
the rest of the framework holds:

- **You stay in `obers_ui`.** A custom cell, a custom block, a custom screen:
  all render `Oi*` widgets, never Material. The no-Material rule is the house
  style, and the hatches are furnished to match. (Beak's own guard cannot see
  inside your builder, so that last part is on you.)
- **You plug in without editing Beak.** A custom column is a `BeakColumnTag` you
  register. A custom data source is a class that implements an interface in
  `beak_core`. Nothing you add requires a patch to `beak_core`, `beak_backend`,
  or `beak_frontend`. Upgrade the packages and your extension still fits.

## The hatches

| Hatch | Reach for it when | Page |
| --- | --- | --- |
| A custom column | a table or detail cell needs a widget no built-in column renders (a sparkline, a bespoke status pill). | [Custom columns](custom-columns.md) |
| A widget block | a page needs a subtree no block in the union covers. | [Custom blocks and widgets](custom-blocks-and-widgets.md) |
| A custom screen | you want a whole free-form page, not a resource's generated CRUD. | [Custom screens and pages](custom-screens-and-pages.md) |
| A custom data source | your records live behind something other than the worm REST backend. | [Custom data sources](custom-data-sources.md) |
| A custom storage driver | uploaded files belong in a store beyond memory, local disk, S3, or FTP. | [Custom storage drivers](custom-storage-drivers.md) |
| Beak widgets on their own | you want one Beak surface inside an app that is not a full panel. | [Using Beak widgets standalone](using-beak-widgets-standalone.md) |

!!! tip "Try the typed path first"
    Before you open a hatch, check whether config already does it. A
    [rich column type](../models/column-types.md), a
    [typed block](../blocks/index.md), or a
    [view mode](../panel/view-modes.md) keeps the one-definition guarantees the
    hatches trade away. The hatch is the answer when the typed path genuinely has
    no entry for what you want, not when it is one line longer.

## The shape of a hatch

Every hatch is one of two shapes, and knowing which tells you where the code
lives.

- **A tag you register.** Custom columns and custom cell renderers work this
  way. The model declares a `BeakColumnTag`; the panel registers a builder for
  that tag at startup. Definition and rendering stay on their proper sides of
  the wire (`beak_core` and `beak_frontend`), linked by a value.
- **An interface you implement.** Custom data sources and storage drivers work
  this way. `BeakDataSource` and `BeakStorageDriver` are plain interfaces in
  `beak_core`; you write a class, register it, and the rest of the stack calls
  it through the same methods it calls the built-ins with. This is the seam that
  lets a future `beak_serverpod` slot in without a line of change to the
  packages above it.

Widget blocks and screens sit between the two: they take a `WidgetBuilder` or a
`BeakBlock` body, which is Flutter itself, framed by Beak's chrome.

## Continue reading

- [Custom columns](custom-columns.md) render any cell with a registered builder.
- [Custom blocks and widgets](custom-blocks-and-widgets.md) drop a raw `obers_ui` subtree into a block tree.
- [Custom screens and pages](custom-screens-and-pages.md) add whole free-form pages to the panel.
- [The block system](../concepts/the-block-system.md) the declarative vocabulary the hatches fall back from.
