---
name: beak-frontend-add-detail-screen
description: Shape a record's detail page in a Beak panel with sections, related lists, links and the metadata aside. Use when the show page should present grouped fields or related rows.
---

# Add or shape a detail screen

The detail page uses the same `BeakFormScreen` layout in read mode. Add one to
group fields, show related rows or replace the metadata aside.

## Steps

1. Add the screen for `BeakScreenRole.read`:

   ```dart
   BeakFormScreen(
     roles: const {BeakScreenRole.read},
     layout: BeakFormLayout(children: [
       BeakCard(title: 'Product', children: [
         ProductModel.name.input(),
         ProductModel.status.input(),
       ]),
     ]),
   )
   ```

2. Related rows: `BeakRelatedList(VariantModel(), scope: ..., parent: ...,
   fields: [...])`, or `relation.readOnlyRows(children: [...])`.
3. A related record as a link: `ProductModel.category.link()`.
4. The metadata aside (created, updated, deleted) is on by default. Pass
   `aside:` to replace it or `showMetadataAside: false` to use the full width.
5. Keep the route reachable: the detail route is `<resource.route>/:id`.

## Gate

`flutter analyze`, `flutter test`, and the route sweep over detail at 375 and
1280 pixels.

## Example prompt

> Use the beak-frontend-add-detail-screen skill: show a product's basics in one card, its variants as a read-only table, and its category as a link.
