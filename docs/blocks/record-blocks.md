---
title: Record blocks
description: Show fields and related rows of one record with field, field group and relation blocks, and mount the BeakRecordScope they read from.
type: guide
audience: [expert]
status: stable
---

# Record blocks

Three blocks show one record: `BeakFieldBlock`, `BeakFieldGroupBlock` and `BeakRelationBlock`. They have no query. They read the record from the nearest `BeakRecordScope`, and nothing in Beak mounts that scope for you. After this page you can write a record sheet once as a `const` block tree, load the record, hand it over, and you know what happens when you forget to.

## At a glance

| Block | Shows | Takes |
| --- | --- | --- |
| `BeakFieldBlock` | one field: label and value | a `BeakColumn`, an optional `label`, a `layout` (`stacked` or `inline`) |
| `BeakFieldGroupBlock` | several fields in a responsive grid | a list of `BeakColumn`s, `columnCount` (2) |
| `BeakRelationBlock` | the rows of one to-many relationship | a `BeakRelationship`, an optional `title` |

The value is drawn by the same renderer as a table cell, in its detail form, so a badge, a date, an image or a money amount looks here as it does in the list and on the generated show page, with the panel's [formatting](../theming/formatting-and-localization.md) applied.

## Write the sheet once

The Aviary's keeper sheet is a plain function that returns a block tree:

```dart title="examples/showcase/lib/resources/keepers/keeper_sheet.dart"
--8<-- "examples/showcase/lib/resources/keepers/keeper_sheet.dart:keeperSheetBlock"
```

Columns come from the generated model (`KeeperModel.name.column`), so no field is a string. The relation comes from the same place (`KeeperModel.habitats.relation`). The tree names no record, which is why one function serves whichever keeper the route asks for.

## Mount the scope

A scope is an `InheritedWidget` holding a model and one loaded record:

```dart title="packages/beak_frontend/lib/src/detail/beak_record_scope.dart"
--8<-- "packages/beak_frontend/lib/src/detail/beak_record_scope.dart:BeakRecordScope"
```

Something has to load the record and wrap the tree. In the Aviary that is a small `HookWidget`, `KeeperSheet`, which asks the repository for the row named by the route and switches on the result:

```dart title="examples/showcase/lib/resources/keepers/keeper_sheet.dart"
--8<-- "examples/showcase/lib/resources/keepers/keeper_sheet.dart:recordScopeHandOff"
```

The keeper resource then gives that widget the read role, so `/keepers/<id>` shows the sheet instead of the generated page:

```dart title="examples/showcase/lib/resources/keepers/keeper_resource.dart"
--8<-- "examples/showcase/lib/resources/keepers/keeper_resource.dart:keeperReadScreen"
```

`BeakResourceRepository.getOne` returns the row without its relations. That is enough for field blocks. When the sheet shows relations and you want them to paint without a query of their own, load the record with `beakLoadRecordWithRelations(repository, model:, id:, relations: [...])` instead: a `BeakRelationBlock` uses the relation rows already on `scope.record` when they are there, and fetches them itself when they are not.

## What each block does

**`BeakFieldBlock`** looks the value up by the column's key in the scoped record. `stacked` puts a small label above the value, `inline` puts a 160 pixel label column beside it, like a definition list. Without `label` it uses the column's label. It can only show a column of the scoped model: a column of a related record is not reachable from here, so show those through a relation block or load a wider record.

**`BeakFieldGroupBlock`** is a shorthand for a run of stacked field blocks in a grid, with 16 pixel gaps. Its labels are the columns' own, and there is no way to override one. When you need a custom label, use a field block.

**`BeakRelationBlock`** is the relationship manager, not a read-only list. What it shows depends on the relationship:

| Relationship | The block shows |
| --- | --- |
| `HasMany` | The related rows by their display column, a count badge, and a delete button on every row. |
| `BelongsToMany` | The attached rows with a detach button each, and a search box that attaches another. |
| `BelongsTo`, `HasOne` | The text "Unavailable". Only to-many relationships are managed. |

It reads 25 related rows at a time and offers "Load more (n)" for the rest, up to 200, and beyond that it says how many it shows. Buttons act immediately once you confirm: the delete button on a has-many row asks "Delete this record?" and then deletes that related record, and detach unlinks the pivot row without asking. Both go through the panel's data source, so the row's model has to allow the write. A refused write shows the reason in a toast, and the block reloads after every write, refused or not. A failed read keeps the rows on screen and shows an error line with Retry.

## Rules and limits

- **Without a scope, a record block renders nothing.** It does not throw. If a sheet comes up blank, look for the missing `BeakRecordScope` before anything else.
- **The framework never mounts a scope.** The generated show page is a read-mode form and not a block tree ([The block system](../concepts/the-block-system.md)), so a record sheet built from blocks is a screen you write, and you load the record.
- **A relation block is a write surface.** The delete and detach buttons appear for whoever can see the sheet. Whether the write succeeds is decided by the server's policy, not by hiding the button. If a sheet should not offer them, show the related rows with a `BeakTableBlock` and a `baseFilter` instead.
- **`BeakRelationBlock.title` does nothing.** The parameter is accepted, but the manager heads itself with the relationship's own label. The Aviary passes `title: 'Habitats'` and gets "Habitats" because that is the relationship's label anyway.
- **The related row's key column must be called `id`.** The manager reads that key from each related row to detach or delete it, and it does nothing for a row without one. A related model with a differently named primary key shows its rows and silently cannot act on them.
- **One record per scope, nearest wins.** To show two records side by side, give each its own scope around its own subtree.
- **The record is loaded once per id.** A save elsewhere does not reload the sheet, so field blocks keep showing what was loaded. A relation block fetches its rows again after any write through the panel's data source.
- **Composition is free.** Record blocks are ordinary blocks: put them in cards, tabs, grids, or a [`BeakTabsBlock`](layout-blocks.md), with data blocks next to them.

## Verify it

The Aviary has a test that mounts the sheet and reads the values back, and another that fails when the record blocks stop being on the keeper screen:

```console
$ cd examples/showcase
$ flutter test --no-pub test/aviary_resources_test.dart --plain-name "keeper read screen"
00:00 +0: the keeper read screen composes record blocks
00:01 +1: All tests passed!
$ flutter test --no-pub test/block_type_matrix_test.dart
00:00 +2: All tests passed!
```

To see the missing-scope case, render `BeakBlockHost(block: keeperSheetBlock())` without the wrapper. The cards draw with their titles and nothing inside them, and nothing is logged.

## Reference

```dart title="packages/beak_frontend/lib/src/blocks/beak_field_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_field_block.dart:BeakFieldBlock"
```

| Block | Parameters (default) |
| --- | --- |
| `BeakFieldBlock` | `column`* (positional), `label`, `layout` (`BeakFieldLayout.stacked`) |
| `BeakFieldGroupBlock` | `columns`* (positional), `columnCount` (2) |
| `BeakRelationBlock` | `relationship`* (positional), `title` (unused) |
| `BeakRecordScope` | `model`*, `record`*, `child`* |

Every block also takes `span`. Every block class is on [Blocks](../reference/blocks.md), and the scope is explained next to the form-side `BeakDraftScope` in [The block system](../concepts/the-block-system.md).

## Continue reading

- [Detail views](../forms/detail-views.md) the generated read page, which needs no scope.
- [Module blocks](module-blocks.md) blocks that load one record by id instead of reading a scope.
- [Custom screens](../panel/custom-screens.md) where a sheet like this is routed.
- [Custom blocks and widgets](../extending/custom-blocks-and-widgets.md) a widget that reads the scope directly.
