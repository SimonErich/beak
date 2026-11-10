---
name: beak-frontend-add-form
description: Add or reshape a create/edit form in a Beak panel with cards, tabs, sections, inputs, validation and owned-child editors. Use when the generated form needs a chosen field order, layout or rule.
---

# Add or shape a form

`BeakResource.standard` already gives the create and edit forms. Supply a
`BeakFormScreen` when the form needs a different order or grouping.

## Steps

1. Build the layout from typed fields:

   ```dart
   BeakFormScreen(
     roles: const {BeakScreenRole.create, BeakScreenRole.edit},
     layout: BeakFormLayout(
       children: [
         BeakCard(title: 'Basics', children: [
           ProductModel.name.input(),
           ProductModel.status.input(),
         ]),
         BeakTabs(tabs: [
           BeakTab(title: 'Pricing', children: [
             ProductModel.netPriceCents.inputCurrency(),
           ]),
         ]),
       ],
     ),
   )
   ```

2. Conditions are `visibleIf:`/`enabledIf:`; per-field checks are `validate:`
   and `validators:`. Server-side rules belong in the definitions package.
3. Owned children use `relation.tableForm(children: [...])`; a translation
   table uses `relation.translationsForm()`.
4. The same layout serves read and edit; read mode switches to edit in place.
5. Run `beak prepare`, then the gate.

## Gate

`flutter analyze`, `flutter test`, and the route sweep over create and edit at
375 and 1280 pixels.

## Example prompt

> Use the beak-frontend-add-form skill: a product form with a Basics card (name, status) and a Pricing tab, with the name required.
