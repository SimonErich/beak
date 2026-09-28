---
title: Declarative resources and forms
description: Separate model behavior, resource navigation and presentation while Beak owns the runtime.
---

# Declarative resources and forms

Define shared models, register resources and arrange their screens. Beak supplies fetching, typed binding, validation, relationship drafts, save plans and refresh. The maintained shop demonstrates the same configuration for CRUD, invoice workflows and custom content.

```dart title="examples/clean_beak_config/lib/main.dart"
--8<-- "examples/clean_beak_config/lib/main.dart"
```

## Separate responsibilities

| Definition | Responsibility |
| --- | --- |
| Schema | Types, relationships, constraints and value lifecycles |
| `BeakResource` | Model, navigation, search, filters and route screens |
| Screen/layout | Cards, tabs, columns, sections and input placement |
| `BeakFormSession` | Draft graph, validation, conflicts and save state |
| Data-source capabilities | Queries, persistence, receipts, uploads and permissions |

A resource inherits standard list, create, read and edit routes. Configure a screen to replace those route roles. The panel discovers referenced models recursively, including related models without navigation entries. Each panel owns its dependency scope, so custom widgets resolve the correct source through `beakDependencies(context)`.

## One typed vocabulary

`beak prepare` emits scalar and relationship descriptors, typed query helpers and record readers beside each schema. Use the generated fields for inputs, table columns, search, filters and comparisons. The `fields` namespace is always available; direct shortcuts are omitted when they conflict with existing model members.

Shared column and record rules run on both sides. Relationship eligibility declared with `BeakExists` and `BeakFieldMatch` also supplies picker filters, prerequisites and invalidation. Optional custom queries remain available for specialized searches.

## Layout without state plumbing

Use `BeakFormScreen` or `BeakWizardScreen`, with cards, columns, tabs, sections and generated field inputs. `BeakFormSections` can project the same section definitions into a wizard, tabs or a plain layout. Groups can share visibility and enabled conditions. Resource relationship presentation supplies defaults for reused editors.

To-many editors stage additions, edits, removals and nested creation until Save. An advanced form can expose occasional options in a modal. Cancellation restores the draft checkpoint. Read mode uses the same structure with formatted values.

## Behavior and recovery

Model behavior centralizes initial values, suggestions, derivations, snapshots and named transitions. Configured forms and tables discover those actions. Draft storage, review, conflict resolution and a diagnostic inspector are opt-in configuration on the same runtime. Duplication and batch editing reuse the graph protocol.

## Custom content

A `BeakScreen` can host declarative blocks or a `BeakWidgetBlock`. A custom input can use `BeakDraftScope` to stage typed changes while Beak retains validation and saving. A custom dashboard can query the panel source and listen to its mutation stream. The shop's Operations page, receivables widget and variant builder demonstrate these three boundaries.

See [Custom screens](../extending/custom-screens-and-pages.md) and [Custom blocks and widgets](../extending/custom-blocks-and-widgets.md) for compiling examples.

## Continue reading

- [Model behavior](../models/behavior.md)
- [Forms](../panel/forms.md)
- [Drafts and review](../panel/drafts-and-review.md)
