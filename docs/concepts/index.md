---
title: Core concepts
description: The seven ideas that make Beak tick, each in a paragraph, with a link to the page that goes deep.
---

# Core concepts

By the end of this section you will hold Beak's whole mental model in your head:
one typed column definition, the surfaces it drives, the layers it travels
through, and the way results and errors come back. Read the pages top to bottom
the first time. After that, this hub is a map you can jump around in.

Every page here quotes the tutorial store, a small coffee roastery
(`examples/store`) whose server runs on port 8080. The models are small on
purpose so the ideas stay in focus.

!!! tip "Reading order"
    The two promises come first because everything else is a consequence of
    them. The four layers and how data flows explain the plumbing. Rendering,
    blocks, and results are where the plumbing surfaces in your UI.

## The one-definition promise

You declare a column once, as a typed `const`, and Beak feeds it to six
consumers: the table cell, the form field, the detail row, the filter, the REST
validator, and the CSV export column. Change the definition in one place and all
six move together. See [The one-definition promise](the-one-definition-promise.md).

## The type-safety promise

You never write a string field reference and you never touch `dynamic`. Columns
and relationships are typed constants, the sealed families (columns, values,
filters, results, exceptions) force you to handle every case, and `BeakValue`
carries filter operands across the wire without losing their type. See
[The type-safety promise](the-type-safety-promise.md).

## The four layers

Each side of Beak has four layers with one job apiece. The backend runs
`Handler -> Service -> DataSource`, with error-mapping middleware as the single
catch boundary. The panel runs `Widget -> ViewModel -> Repository -> DataSource`,
with the Repository as the catch boundary that turns thrown failures into
`BeakResult` values. See [The four layers](the-four-layers.md).

## How data flows

A query is a value. `BeakQuerySpec` is a fully serializable description of what
you want (filters, sorts, search, pagination, relation loads) that the panel
builds with immutable copy-builders and posts to the server, where a translator
turns it into a real database query. See [How data flows](how-data-flows.md).

## Rendering per surface

The same column looks like different things depending on where it appears: a
currency figure in a table cell, a validated input in a form, a read-only row in
a detail view. A column carries a render intent per `BeakContext`, and the panel
picks the matching obers_ui widget. See [Rendering per surface](rendering-per-surface.md).

## The block system

Screens, dashboards, detail layouts, and forms are all trees of `BeakBlock`s
rendered by one host widget. Record blocks are dual-mode: the same block tree
shows read-only values inside a detail scope and editable inputs inside a form
scope. See [The block system](the-block-system.md).

## Results and errors

Failures are values, not surprises. The Repository catches exceptions and returns
`BeakResult<T>` (`BeakOk` or `BeakErr`), and the server maps the sealed
`BeakException` family to HTTP status codes and a stable JSON envelope. See
[Results and errors](results-and-errors.md).

## Continue reading

- [The one-definition promise](the-one-definition-promise.md) one column, six surfaces.
- [The type-safety promise](the-type-safety-promise.md) no strings, no `dynamic`, sealed all the way down.
- [Defining models](../models/defining-models.md) put these ideas to work in a real model.
- [Tutorial: First Flight](../tutorial/index.md) build the coffee roastery from scratch.
