---
title: Recipes
description: Short, worked answers to the things you do most in Beak — one page each, every snippet lifted from a running example.
---

# Recipes

Small, worked answers to "how do I do that one thing". Each is a few lines of
real code and a link to the page that covers it in depth. Every snippet is
lifted from a running example app or from Beak's own source, and the docs
build fails if one stops matching its file.

Unless a recipe says otherwise, the code is from the store example
(`examples/store`, served on port 8080). Two snippets come from the showcase
app (`examples/superdashboard`, port 8180) and from `beak_core`; both are
labelled where they appear.

## Schema

| Recipe | What it answers |
| --- | --- |
| [Add a resource end-to-end](add-a-resource.md) | What one annotated class buys you |
| [An enum badge column](an-enum-badge-column.md) | A select in the form, a coloured badge everywhere else |
| [A belongs-to picker](a-belongs-to-picker.md) | A searchable picker and a linked label, from one field |

## Panel

| Recipe | What it answers |
| --- | --- |
| [A custom row action](a-row-action.md) | A verb the CRUD basics do not cover |
| [A kanban view](a-kanban-view.md) | A board alongside the table |
| [A KPI on the dashboard](a-dashboard-kpi.md) | A number computed in the database |
| [Split a long form into steps](a-multi-step-form.md) | A wall of inputs, paced |
| [Hide a resource from the sidebar](hide-a-resource.md) | A model with an API but no nav entry |

## Data

| Recipe | What it answers |
| --- | --- |
| [Export to CSV](export-to-csv.md) | The generated export route, honouring the current filters |

## Continue reading

- [Actions](../panel/actions.md) the full action model behind the row-action recipe.
- [Dashboards](../panel/dashboards.md) more on KPI blocks, metrics, and charts.
- [Relationships](../models/relationships.md) all four relation kinds and how they render.
- [beak.yaml](../reference/beak-yaml.md) every key that shapes the panel from outside Dart.
- [Performance](../guides/performance.md) why aggregate KPIs and eager-loaded pickers keep query counts flat.
