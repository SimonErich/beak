---
name: beak-frontend-build-screens
description: >-
  Arrange what a Beak panel shows: table columns, filters, forms with cards,
  tabs, sections and columns, owned-child editors, pickers, galleries,
  wizards, read and edit in one layout, dashboard pages built from blocks, and
  custom widgets inside forms, all through generated field references
  (ProductModel.name.inputText()) and obers_ui. Use when asked to change a
  form or table layout, add a filter, tab, wizard step, dashboard page or
  custom input, in any Beak panel including Serverpod-backed ones. Not for new
  data or rules: if a field does not exist yet, use beak-add-resource or
  beak-evolve-schema first, and beak-add-business-rule for "must" logic.
---

# Build screens

A screen is configuration on a `BeakResource` (its `screens:` and `filters:`) or
a `BeakScreen` page. The data comes from the generated model, so every reference
is typed: a renamed field stops compiling where the screen used it.

Read first, by path: `.dart_tool/beak/docs/ai-index.md` (the panel rows), then
the page for the job: `.dart_tool/beak/docs/forms/form-screens.md`,
`.dart_tool/beak/docs/panel/tables-and-filters.md`,
`.dart_tool/beak/docs/forms/related-records.md`,
`.dart_tool/beak/docs/forms/multi-step-forms.md`,
`.dart_tool/beak/docs/panel/custom-screens.md` or
`.dart_tool/beak/docs/extending/custom-blocks-and-widgets.md`. Search with
`grep -rn "<term>" .dart_tool/beak/docs`.

## Steps

1. Open the resource file and the generated `<schema>.beak.dart` beside the
   schema class (in a Serverpod admin, in the `<name>_beak` package). Use only
   the statics the generated model declares: `ProductModel.name`,
   `ProductModel.category.name`, `ProductModel.variants`. Never invent a field
   and never write one as a string. A field that is missing means the data
   changes first (`beak-add-resource`, `beak-evolve-schema`).
2. Table: `BeakTableScreen(fields: [ProductModel.name, ProductModel.category.name])`.
   Filters go on the resource: `filters: [ProductModel.name.textFilter(),
   ProductModel.active.boolFilter(), ProductModel.category.relationFilter()]`
   (also `.selectFilter()`, `.numberRangeFilter()`, `.dateRangeFilter()`; add
   `label:` or `advanced: true` as needed).
3. Form: `BeakFormScreen(roles: {read, create, edit}, layout: BeakFormLayout(children:
   [...]))`. One layout serves reading and editing; read mode switches to
   edit in place. Nest `BeakCard(title:, children:)`, `BeakColumns(children:)`,
   `BeakSection(title:, children:)` and `BeakTabs(tabs: [BeakTab(title:,
   children:)])`. Inputs come from the field: `.inputText()`, `.inputNumber()`,
   `.inputCurrency()`, `.inputToggle()`, `.inputSelect()`, `.inputDateTime()`, or
   `.input()` for the model's default. Conditions are `visibleIf: (state) => ...`
   and `enabledIf`; per-field checks are `validators:`.
4. Relations: to-one `Model.rel.inputCombobox()` (also `.inputCards()`,
   `.inputSearch()`); owned children `Model.lines.tableForm(children:
   [Line.label.inputText(), ...])` with
   `removeBehavior: BeakRemoveBehavior.deleteOwned`; images
   `Model.images.galleryForm(image:, caption:, position:)`.
5. Wizard: `BeakWizardScreen(steps: [BeakWizardStep(title:, children:)],
   roles: {BeakScreenRole.create})`. To show the same sections as a wizard,
   tabs and a stacked form, declare them once in `BeakFormSections` and use
   `.steps`, `.form`.
6. Page: a top-level `BeakScreen(path:, title:, icon:, body: BeakColumnBlock(
   children: [BeakMetricBlock(...), BeakCardBlock(child: BeakTableBlock(...))]))`.
   In a project whose `lib/main.dart` is generated, put it in `lib/screens/` as
   a top-level variable or a zero-argument function, then run `beak prepare`;
   with an authored panel add it to `BeakPanel(pages: [...])`.
7. Custom input or card: `BeakFormWidget(showOnRead: false, builder:
   (context, draft) => MyWidget(draft: draft))`. The widget is a `HookWidget`
   (add `flutter_hooks` to `pubspec.yaml` if missing) built from obers_ui
   `Oi*` widgets (`package:beak/ui.dart`). `BeakDraftScope.of(context)` says
   whether it may edit; read values with `draft.read(Model.field)` and change
   them through the draft so they save with the form.
8. Keep the rules: never import `package:flutter/material.dart` or
   `cupertino.dart`, no `StatefulWidget`, no `dynamic`, no `as` casts, and no
   business rule in a widget callback (`beak-add-business-rule`).
9. Test each screen you touched (`references/layout-cheatsheet.md`): a form
   test at 375 and 1280 pixels wide, and a panel test that opens a table over an
   `InMemoryBeakDataSource`.
10. Run `beak prepare` when generated wiring may have changed (standalone apps),
    then the gate.

## Gate

`dart format .`, `flutter analyze` and `flutter test` are clean, plus
`beak doctor` in a standalone or embedded app. In a Serverpod admin, also
`dart analyze` in the schema package.

## Example prompt

```text
Use the beak-frontend-build-screens skill: split the product form into Overview and Pricing tabs, edit variants in an inline table, and add a category filter to the product table.
```
