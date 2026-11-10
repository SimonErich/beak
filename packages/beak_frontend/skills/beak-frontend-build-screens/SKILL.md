---
name: beak-frontend-build-screens
description: The index of the focused Beak screen skills. Use when asked to change what a panel shows and you need to pick the right task - list, form, detail, wizard, action, export, page or theme. Each linked skill has the steps and gate for that job.
---

# Build screens: pick the task

A screen is configuration on a `BeakResource` (its `screens:` and `filters:`) or
a `BeakScreen` page. Every reference is a typed generated field, so a renamed
field stops compiling where the screen used it.

Start with `.dart_tool/beak/docs/ai-index.md`, then read the page for the job
under `.dart_tool/beak/docs/`. Search with
`grep -rn "<term>" .dart_tool/beak/docs`.

| The job | Use |
| --- | --- |
| Show different columns, filters or presets | `beak-frontend-add-list` |
| Shape the create/edit form | `beak-frontend-add-form` |
| Group a record's detail page or show related rows | `beak-frontend-add-detail-screen` |
| Split a long flow into steps | `beak-frontend-add-wizard` |
| Add a record, bulk, global or model-command action | `beak-frontend-add-action` |
| Download the list as CSV | `beak-frontend-add-export` |
| Add a dashboard or custom page | `beak-frontend-add-page` |
| Set the brand look or a built-in theme | `beak-frontend-theme` |

If a field is missing, the data changes first: `beak-add-resource` in a
Beak-owned project, `beak-serverpod-add-model` in a Serverpod admin, and
`beak-add-business-rule` for "must" logic on the server.

## Shared rules

- No `package:flutter/material.dart`, no `StatefulWidget`, no `dynamic`, no
  `as` casts in authored screens.
- Authorization is the server's; the panel only offers what the account may use
  (`BeakPanelAccess`, `BeakVisibilityBlock`, a screen's `canAccess`).
- Test every screen you touch at 375 and 1280 pixels, and use
  `beakRouteSweep` for the whole panel.
- Run `beak prepare` when generated wiring may have changed, then the gate.

## Example prompt

```text
Use the beak-frontend-build-screens skill to decide how to build the product admin screens: a filtered list, a two-tab form, a detail page with variants, and a duplicate action.
```
