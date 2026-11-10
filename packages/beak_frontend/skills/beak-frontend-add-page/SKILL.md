---
name: beak-frontend-add-page
description: Add a dashboard or custom page to a Beak panel from blocks, or a screen with role-based access. Use when the panel needs an overview, a report or a page that is not a resource list.
---

# Add a page

A page is a `BeakScreen` with a block tree. Blocks describe what to show; the
host renders them.

## Steps

1. Say the route, title and body:

   ```dart
   BeakScreen(
     path: '/overview',
     title: 'Overview',
     icon: const BeakIconToken(OiIcons.gauge),
     body: BeakColumnBlock(children: [
       BeakMetricBlock(model: const OrderModel(), ...),
       BeakCardBlock(title: 'Latest orders', child: BeakTableBlock(
         model: const OrderModel(),
         fields: [OrderModel.reference, OrderModel.status],
         enableDelete: false,
         initialSpec: const OrderModel().query().paginate(perPage: 5),
       )),
     ]),
   )
   ```

2. Use only blocks; a `BeakWidgetBlock`/`BeakFormWidget` is the escape hatch,
   built from obers_ui `Oi*` widgets.
3. Access: `canAccess: (access) => access.has('finance')`; a section can use
   `BeakVisibilityBlock`.
4. A `BeakTableBlock` opens a record on tap by default; pass `onRowTap:` to
   navigate elsewhere.
5. Register the page in `BeakPanel(pages: [...])` or under `lib/screens/` for a
   generated panel, then run `beak prepare`.

## Gate

`flutter analyze`, `flutter test`, and the route sweep over the page at 375 and
1280 pixels.

## Example prompt

> Use the beak-frontend-add-page skill: an overview page with three metrics and a latest-orders table, visible only to accounts with the finance role.
