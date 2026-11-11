---
name: beak-frontend-add-action
description: Add a record, bulk, global or model-command action to a Beak resource, with confirmation, typed input and permission handling. Use when the panel needs a button beyond create/edit/delete.
---

# Add an action

Actions never carry their own authorization: the server decides, and the panel
offers only what the account may use.

## Steps

1. A record action:

   ```dart
   BeakRecordAction(
     key: 'duplicate',
     label: 'Duplicate',
     icon: OiIcons.copy,
     onExecute: (record, context) async {
       await context.dataSource.create(context.model.table, record);
       await context.refresh?.call();
     },
   )
   ```

2. A model command is declared once in the definitions package
   (`BeakModelAction`) and run by the server. The panel adds it to a form or the
   list; the server maps it to its use case (`beak-serverpod-bind-write`).
3. A global action (independent of a record) uses `BeakGlobalAction`, or
   `BeakGlobalAction.openList(model, label:, icon:)` to link to a neighbour.
4. Confirmation: `requiresConfirmation: true`. Typed input: give the action an
   `inputModel`.
5. Visibility: an action that needs a role uses `BeakVisibilityBlock` or a
   custom screen's `canAccess`, never a client-only check alone.

## Gate

`flutter analyze`, `flutter test`, and a test that runs the action once and
shows a refusal for an account without the role.

## Example prompt

> Use the beak-frontend-add-action skill: add a confirmed "Archive" record action to the product list that calls our archive use case.
