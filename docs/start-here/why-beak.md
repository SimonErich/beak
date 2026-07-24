---
title: Why Beak?
description: The case for configuration over hand-written admin code, the UX you get for free, and the honest tradeoffs of the approach.
---

# Why Beak?

After this page you will understand the bet Beak makes, what you gain by taking
it, and where it stops being the right tool. It is a short argument in four
parts, followed by the tradeoffs, so you can decide with open eyes.

The admin panel is the part of an app that is most similar between projects and
least fun to build twice. Beak's bet is that you should describe it, not
hand-write it, and still be holding a normal Flutter app at the end.

## Config over code

An admin resource is a database table, a REST surface for it, and a set of
screens over that surface. Written by hand, those three drift: a field gets a
new validation rule in the API but not the form, a column is renamed in the
table but not the export. Beak collapses the three into one typed definition and
reads it from every side.

Adding a resource is four declarations, not four codebases:

1. **Columns and model.** A namespaced `XxxColumns` class of `const` column
   definitions and an `XxxModel extends BeakModel` naming the table, display
   column, and relationships.
2. **Schema.** A worm migration, registered in your `bin/worm.dart`.
3. **Server.** Register the model in the `BeakModelRegistry` you hand to
   `BeakServer`. Every endpoint is generated from it.
4. **Panel.** Add a `BeakResource(model: XxxModel(), icon: …)` to your
   `BeakPanelConfig`. List, create, show, and edit pages, plus filters, actions,
   and dashboard cards, are generated from it.

There is no fifth step where you wire the pieces together. The wiring is what
Beak does.

## Optimized UX out of the box

Because Beak generates the UI, it generates a *good* UI, once, and every resource
inherits it. Server-side sort, filter, and pagination in tables. Forms with
client-side validation that mirrors the server rule for rule. Detail views,
relation managers, global search, CSV export, and dashboards. You do not opt
into these per resource; they come with the model.

File handling is a fair example. You describe the rules on the column and Beak
enforces them on the client (for fast feedback) and again on the server (because
the server never trusts the client), then runs your transform pipeline and
returns a typed result with its variants:

```dart title="README.md"
static const image = BeakImageColumn(
  key: 'image', label: 'Image', storagePath: 'products',
  maxSizeInBytes: 5 * 1024 * 1024,
  allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
  transforms: [
    BeakThumbnailTransform(size: BeakDimensions(widthInPixels: 160, heightInPixels: 160)),
    BeakFormatTransform.webp(),
  ],
);
```

You wrote a description. You received size limits, type checks, a thumbnail, a
webp rendition, and an upload endpoint that validates before it stores.

## Consistent, and hard to get wrong

The type system does the enforcing, so a whole category of admin bugs cannot
compile. You never write a string field reference, so a typo in a column name is
a missing symbol, not a runtime surprise. You never touch `dynamic`. Filter
operands travel as a typed `BeakValue`, results come back as a sealed
`BeakResult`, and errors are a sealed `BeakException` family the server maps to
stable HTTP status codes. Every resource in your panel behaves the same way
because they are all rendered by the same code from the same shape of
definition.

This is also why Beak reads well to an AI agent. A resource is a schema an agent
can generate correctly, because there is one right way to describe it and the
compiler checks the result.

## Still a normal Flutter app, so never locked in

The tradeoff people fear with a framework like this is the ceiling: the day the
generated thing is not what you need. Beak is designed so that day is a small
step down, not a wall.

- **Drop to a custom widget.** Any block tree can host a plain `HookWidget`
  through the widget escape hatch, so a bespoke chart or a one-off control lives
  right next to generated blocks.
- **Add a custom screen or page.** A `BeakScreen` is any block tree (or any
  widget) mounted in the panel shell with its own route and nav entry, next to
  your generated resources.
- **Use the widgets standalone.** obers_ui is a normal widget library. You can
  render a single `Oi*` widget, or Beak's `BeakBlockHost`, inside an ordinary
  Flutter screen with no panel at all.
- **Swap the data source.** `BeakDataSource` is an interface. worm is today's
  implementation, not a marriage; a future `beak_serverpod` can supply a
  `ServerpodDataSource` without your models or `beak_backend` changing.

You are always one step away from ordinary Flutter code, because that is all
Beak ever was.

## The honest tradeoffs

No approach is free. Here is where the bet costs you something.

| Tradeoff | What it means |
| --- | --- |
| A learning curve up front | You trade writing familiar hand code for learning Beak's vocabulary (columns, blocks, the registry). The payoff arrives on the second resource, not the first line. |
| Convention over total control | Generated pages follow Beak's layout choices. Deep bespoke layouts mean reaching for custom screens and widgets, which is supported but is more code than a config line. |
| The obers_ui and worm dependency | Beak commits you to obers_ui for UI and (today) worm for data. Both are siblings of Beak, referenced by path; the data side is behind an interface, the UI side is not. |
| Pre-1.0 | Beak is `0.0.x`. The design is settled and tested end to end, but the surface can still move before 1.0. |
| Admin-shaped, not everything-shaped | Beak is sharp for internal tools and dashboards. It is the wrong tool for a consumer-facing app, where you want full control of every pixel. |

If those tradeoffs read as acceptable for the back office you are about to build,
Beak will save you the three-times-over work. If you need total layout control
over a public app, use Flutter directly.

## Continue reading

- [What is Beak?](what-is-beak.md) the definition, the name, and the package
  family.
- [The one-definition promise](../concepts/the-one-definition-promise.md) the
  mechanism that makes config-over-code hold together.
- [Using Beak widgets standalone](../extending/using-beak-widgets-standalone.md)
  the escape hatch to plain Flutter.
- [Custom screens and pages](../extending/custom-screens-and-pages.md) mount your
  own screens in the panel shell.
