---
name: beak-add-business-rule
description: >-
  Add a rule that must hold whichever screen or API call saves a record:
  cross-field validation, values that are computed, suggested or frozen,
  eligibility of a related record, locked states, or named actions such as
  issue, approve or cancel. The rule goes on the schema class
  (validationRules, behavior, BeakExists with BeakFieldMatch), so the panel
  previews it and the server re-checks it on every save, and it gets a unit,
  a server and a widget test. Use for "must", "cannot", "only allow",
  "calculate", "default to", "freeze" or status workflows in a Beak app that
  runs Beak's own server. Not for who may do what (beak-secure-api), and not
  for Serverpod-backed panels, where the rule belongs in the Serverpod
  endpoint.
---

# Add a business rule

A rule that lives in a widget callback is a suggestion: the API accepts the
same write from anything else. Beak evaluates rules declared on the schema
class in the form (as a preview) and again on the server against stored data.

Read first, by path: `.dart_tool/beak/docs/models/validation.md`,
`.dart_tool/beak/docs/models/behavior.md`,
`.dart_tool/beak/docs/backend/graph-business-rules.md` and
`.dart_tool/beak/docs/panel/actions.md`. Search with
`grep -rn "<term>" .dart_tool/beak/docs`.

## Steps

1. Pick the home of the rule:

| The rule says | It goes in |
| --- | --- |
| a value is required, bounded or shaped | `@Column(rules: [BeakMin(0), BeakMaxLength(120), BeakPattern(...), BeakEmail()])` |
| fields depend on each other, or rows are counted, summed, compared | `static List<BeakRecordRule> get validationRules`: `BeakRequiredIf`, `BeakSameAs`, `BeakBeforeField`, `BeakAfterField`, `BeakCount`, `BeakDistinct`, `BeakSum`, `BeakUnique` |
| a related record must exist and qualify | `BeakExists(field, Target.id, where: ..., matching: [BeakFieldMatch(...)])` in `validationRules` |
| a value is computed, defaulted, suggested or frozen | `static BeakModelBehavior get behavior` with `BeakValueBehavior.initial`, `.suggested`, `.derived` or `.snapshot` |
| a record locks in some states | `editableWhen` and `deletableWhen` in that behavior |
| a named transition (issue, approve, cancel) | a `BeakModelAction`, declared once in an `abstract final class <Name>Actions` and listed in `behavior.actions` |
| it spans several records or needs data the record lacks | a server graph preparer: `beak eject server`, then `preparePlan:` in `lib/server.dart` |

2. Write it as pure Dart next to the fields, using generated references
   (`TicketModel.status`), never strings. No Flutter imports, deterministic, no
   side effects: a commit can be retried or replayed. Email, webhooks and
   payments are not rules; enqueue them as durable effects
   (`.dart_tool/beak/docs/backend/durable-effects.md`).
3. Run `beak prepare`. The generator forwards `validationRules` and `behavior`
   to the model. Fix what it reports. Snippets to copy from:
   `references/rule-cookbook.md`.
4. Know what changes. A model with behavior (values, actions or guards) is
   written only through graph commits (`POST /api/commits`). Direct create and
   update answer 422 "must be saved through a graph commit". Panel forms already
   save that way. When a hand-written preparer guards a model, list it in
   `graphOnly: [XModel()]` in `lib/server.dart` so its per-record routes close.
5. Wire the action into the UI if it needs a control: a `BeakFormScreen` shows
   the actions a record can run on its own; `submitAction:` makes one the
   primary button. Nothing else is needed for availability: `availableWhen` is
   checked on the server too.
6. Write three tests (recipes in the cookbook):
   - Unit: `<Schema>.validationRules.first.validate(BeakRecord(...))` returns
     the field errors, empty when valid.
   - Server: the rule refuses a bad write. A plain rule: `BeakClient.create`
     throws `BeakValidationException` whose `fieldErrors` name the field. A
     model with behavior: a `BeakSavePlan` through `client.commit`, with
     `result.complete` false, and true once the action's inputs are right.
   - Widget: open the form with `BeakConfiguredForm`, set values through the
     session, tap Save, and expect the message text.
7. Say in your answer which tests prove the client and the server side.

## Gate

`beak doctor`, `dart format .`, `flutter analyze` and `flutter test` are clean,
and the server test fails without the rule: remove the rule temporarily, watch
the test go red, restore it.

## Example prompt

```text
Use the beak-add-business-rule skill: an invoice can only be issued with at least one line, and issuing freezes each line's price and tax rate.
```
