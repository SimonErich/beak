---
title: Model behavior
description: Declare value lifecycles, edit and delete guards and named commands on the schema, and see which of them the server repeats when a save arrives.
type: guide
audience: [expert]
status: stable
---

# Model behavior

Some facts are about a value at a moment, like the price an order line had when it was placed. Some are about a state: an issued invoice is locked. Some are named transitions: issue, mark paid. Validation cannot say any of that, because a valid record is valid in every state. Behavior can. After this page you can declare each kind, predict what the server does with a value the client sent, and read the error when a guard says no.

## At a glance

Behavior is one static getter on the schema class, `BeakModelBehavior get behavior`. `beak prepare` forwards it to the generated model, so the form, the list and the server all read the same object.

| Part | Declared with | Answers |
| --- | --- | --- |
| Value lifecycles | `values: [BeakValueBehavior.initial / suggested / derived / snapshot]` | What should this field hold, and who may overwrite it |
| Edit and delete guards | `editableWhen`, `deletableWhen` | Which changes this state allows |
| Commands | `actions: [BeakModelAction(...)]` | Which named transitions exist, and when |
| Command input | `BeakModelAction.inputModel` | What a command needs from the user |

Most questions belong to one of the layers below, and picking the right one saves you a rewrite.

| The question | Put it in | Enforced by |
| --- | --- | --- |
| Is this value valid, whatever the state | [Validation](validation.md): column rules, record rules | Client and server |
| What should this field hold, and can the user override it | Value behavior | Client previews, server decides |
| Which edits does this state allow | `editableWhen`, `deletableWhen` | Server; the form disables inputs |
| Which transition is this, and when is it allowed | `BeakModelAction`, `availableWhen` | Server; the panel hides buttons |
| Who may do it | A policy, see [Auth and policies](../backend/auth-and-policies.md) | Server only |
| What does this screen show | Layout, `visibleIf`, `enabledIf`, `validators` | Client only |

Behavior has a price. A model with behavior is saved through graph commits, and the direct `POST`, `PATCH` and `DELETE` routes close. A quick check against the shop:

```text
$ curl -s -X PATCH localhost:8080/api/invoices/x -H 'content-type: application/json' -d '{"status":"paid"}'
{"code":"validation","message":"This resource must be saved through a graph commit.","requestId":"a5d2d0eea5549f99"}
```

Otherwise a caller could write around the rule with one `PATCH`. The panel already saves through commits, so you feel this only when you call the API by hand.

## Value lifecycles

A `BeakValueBehavior` owns one field of the model. It names the field, a `resolve` function and the fields `resolve` reads. The constructor you pick is the lifecycle, and the lifecycle decides when it runs and whether the client may send the field.

| Lifecycle | Runs when | If the client sends the field |
| --- | --- | --- |
| `initial` | On a create, when the field is omitted. An explicit `null` is kept. | Accepted on a create, an ordinary edit afterwards |
| `suggested` | While the value is not overridden | Sending it is the override |
| `derived` | Every save and every preview | Ignored, and the form does not send it |
| `snapshot` | Only while its `onAction` command runs | Rejected with `This field is controlled by the record workflow.` |

### Initial and derived

The Foodio customer keeps a full name that nobody types, and a join date that the create fills in:

```dart
--8<-- "examples/foodio-adminpanel/lib/models/customer.dart:FoodioCustomerBehavior"
```

`name` is derived from two other fields, so it is recomputed on every save and the client cannot forge it. `joinedAt` is initial: it is set when the customer is created and is an ordinary field after that. `resolve` reads a clock here, which is only safe because an `initial` value runs once, on a create. Everything else should be a pure function of its inputs, because the form and the server both call it and must get the same answer.

### Suggested

A suggestion follows its dependencies until someone overrides it. The order line suggests a label and a price from the chosen product and variant:

```dart
--8<-- "examples/clean_beak_config/lib/resources/orders/models/order_item.dart:OrderItemBehavior"
```

The dependencies are typed, and they can reach across relationships: `OrderItemModel.variant.price` is the price of the selected variant. List every field `resolve` reads. The list orders the evaluation among the model's own fields and decides which related rows are loaded with the record; a related field you read without listing is not loaded, and reads as `null`.

Here is the line with a price the user typed, evaluated twice, once as if nobody touched the price and once with the price marked as overridden (output of the scratch script under [Verify it](#verify-it)):

```text
suggestion follows:  18.50
user override kept:  7.00
label:               Ethiopia Yirgacheffe
```

What counts as an override: a field the user edited in the current session (the form tracks that for you), any field the client sends in a save, and, on an update, a stored value that differs from what the calculation gives for the stored record right now. The last rule protects history. A product whose price changes next month does not rewrite old order lines: their stored price no longer matches the suggestion, so it counts as a decision someone made. Suggestions are not triggers either, so changing a product does not re-evaluate suggested fields on the lines that point at it. Only derived values on a parent recompute when something they read changes.

### Keeping a value when the selection has not changed

A suggested value can also protect history. Foodio's option lines copy the option's name, and they keep the copy while the option stays the same:

```dart
--8<-- "examples/foodio-adminpanel/lib/models/order_item_option.dart:FoodioOptionLabel"
```

`state.initial` is the stored record before this edit and `state.original(field)` reads a field from it. If the option id is unchanged, the label stays as it was ordered, even after the menu renames the dish. If the id changed, the label follows the new option. `state.argument(field)` reads the input of the executing command, and `state.read(field)` the proposed record.

### Snapshot

A snapshot freezes a value at the moment a named command runs, then leaves it alone. No example app uses one; the shop copies its invoice snapshots in a graph preparer instead. The package test is the working example. It publishes a note and freezes the title into `body`:

```dart title="packages/beak_backend/test/src/service/beak_model_behavior_service_test.dart"
final _publish = BeakModelAction(
  name: 'publish',
  label: 'Publish',
  allowOnCreate: true,
  availableWhen: (record) => _status.readFrom(record) == NoteStatus.draft,
  values: [
    BeakValueBehavior<NoteStatus>.derived(
      field: _status,
      resolve: (_) => NoteStatus.published,
    ),
  ],
);
// ...
      BeakValueBehavior<String>.snapshot(
        field: _body,
        onAction: _publish,
        dependencies: [_title],
        resolve: (context) => context.read(_title),
      ),
```

`onAction` is the command object itself, never its name, so renaming the command cannot leave a dangling reference. The tests in that file show that a forged `body` on a create is rejected, that the command and its snapshot commit in one transaction, and that replaying the same save id returns the stored receipt without evaluating the callbacks again.

## Guards

`editableWhen` and `deletableWhen` take the stored record and answer yes or no. They describe the lifecycle of the record, which is a different thing from who may act, so they are separate from policies. The invoice is editable only as a draft and never deletable:

```dart
--8<-- "examples/clean_beak_config/lib/resources/invoices/models/invoice.dart:InvoiceBehavior"
```

On a create there is no stored record, so Beak evaluates the guard against the record built from defaults and `initial` values. The form disables inputs that a guard has locked and leaves them out of what it sends. The server checks anyway, against the stored record. Here is the seeded shop, whose demo invoice is issued, receiving one-operation plans through `POST /api/commits`. Each answer is a `200` whose operation is `unapplied`:

| Request | Result |
| --- | --- |
| Change `customer_address` | `The record cannot be edited in this state.`, with `customer_address`: `This field is controlled by the record workflow.` |
| Write `status` directly | The same message, on `status` |
| Delete the invoice | `This record cannot be deleted in its current state.` |

A guard also protects the rows a record owns. Editing, attaching or detaching a child of a locked owner is refused with `The owning record is locked by its workflow.` (the package test `child direct edits and relationship writes respect locked owning workflow` asserts the rejection). Every message is in the [reference](../reference/behavior-and-actions.md#what-the-server-checks).

A field that a `derived` value owns is treated more gently than one an action or snapshot owns. Submitting a model-level `derived` field is harmless: the server recomputes it and the sent value disappears. Submitting a field that a command's `values` or a `snapshot` owns is an error, because that field can only move through the command.

## Commands

A command is a named transition on one stored record. The declaration carries everything the panel and the server need: the label, the state it is allowed in, the field changes it makes and, if it needs them, its typed inputs.

```dart title="examples/clean_beak_config/lib/resources/invoices/models/invoice.dart"
  /// Issues a draft invoice and locks its contents.
  static final issue = BeakModelAction(
    name: 'issue',
    allowOnCreate: true,
    label: 'Issue invoice',
    description:
        'Issue this invoice and lock its customer, prices, discounts and taxes.',
    availableWhen: (record) =>
        InvoiceModel.status.readFrom(record) == InvoiceStatus.draft,
    values: [
      BeakValueBehavior.derived(
        field: InvoiceModel.status,
        resolve: (_) => InvoiceStatus.issued,
      ),
    ],
  );
```

`markPaid` and `cancel` in the same class follow the same shape, each allowed in its own states. Declare a command once, as a static object, and refer to that object from forms, lists and preparers. The `name` is only the identity on the wire; no caller writes it.

`values` is what makes `status` a field the client cannot set: only this command moves it to `issued`. `allowOnCreate: true` lets one plan create the invoice and issue it in the same transaction, and a failure leaves no record behind.

Trying the commands on the issued demo invoice, against a running shop:

| Command | Result |
| --- | --- |
| `issue` on an issued invoice | `unapplied`: `This action is unavailable in the current state.` |
| `markPaid` | `applied` |
| `markPaid` again | `unapplied`: `This action is unavailable in the current state.` |

Panel buttons are the other half: a row action, a form button or a bulk action per command, shown while `availableWhen` holds. That side is in [Actions](../panel/actions.md), and the checks the server runs before a command, in order, are in the [reference](../reference/behavior-and-actions.md#what-the-server-checks).

### Commands with input

A command can ask for typed input with an `inputModel`, an ordinary `BeakModel` with its own columns, defaults and rules. Foodio's "Add note" takes a bounded, non-empty note:

```dart
--8<-- "examples/foodio-adminpanel/lib/domain/order_behavior.dart:FoodioAddNote"
```

```dart
--8<-- "examples/foodio-adminpanel/lib/domain/_order_note_input.dart:FoodioNoteInput"
```

The dialog and the API validate the same columns, so the rules are written once. A value behavior of the command reads the input with `state.argument(field)`, and a graph preparer reads it from `plan.arguments`: Foodio's preparer turns the note into a row of its own. Input models take belongs-to constraints only, and a relationship in the input must arrive as a selected identity.

## What the server does with a save

The preview in the form and the authority on the server run the same function, `BeakModelBehavior.apply`, over different records. The server does not trust the preview. In order:

1. Every operation is authorized (field write access, then `canCreate`, `canUpdate` or `canDelete`) before any behavior code runs.
2. The server builds a candidate graph: the stored records with every proposed write applied in memory.
3. For a command, it checks the caller (`BeakActionPolicy`, when installed), `allowOnCreate`, `availableWhen` on the stored record and the input model.
4. For every changed record, and every parent whose derived values read it: guards, then `validateEdits` (locked fields), then `apply`. The server repeats `apply` while a suggested relationship changes what the next calculation reads, and gives up with `Model values did not stabilize after resolving relationships.` if it never settles.
5. For a command, `apply` runs once more with it: the command's `values` first, then the model's values again, which is where derived fields see the command's changes and snapshots are taken.
6. A custom graph preparer may add operations, see [Transactional business rules](../backend/graph-business-rules.md).
7. The operations are written, then the [validation rules](validation.md) run on the final graph. Any failure rolls the whole save back.

The form is the mirror image. Editing an input marks a suggested field as overridden, and every change re-runs `apply` until nothing moves, up to 64 rounds before it reports `Cyclic derived field values in form.` Fields that a guard or a `derived` value owns are disabled and not sent. Related rows that suggested and derived values read are loaded with the record.

## Sources that cannot do this

Authoritative behavior needs a transaction and a candidate graph, which the Worm-backed server provides. Two other cases are refused loudly rather than half-applied:

- A server built on another data source refuses to boot when a model declares behavior or a rule reads related rows: `Shared relationship validation requires an atomic graph data source.` Custom preparers need a Worm source too.
- A plain CRUD source wrapped by `BeakStagedCommitDataSource` answers a plan that touches a model with behavior, or carries a command, with every operation `unapplied`, reason `unsupportedBehavior` and the message `Model behaviors require an authoritative atomic graph provider.`

## Rules and limits

- Keep `resolve` and `availableWhen` pure and quick. Both run in the form and on the server, `resolve` can run more than once per save, and a receipt replay skips them. A command is a state transition, not an email or a payment: side effects belong in [durable effects](../backend/durable-effects.md).
- A behavior field is a root column of its own model. Dependencies may reach related data through a relationship path, but must start at the same model.
- The declaration is checked when the model is registered, so a mistake stops the server at boot instead of on the first save: a dependency cycle, two behaviors on one field, a snapshot for a command the model does not declare, a dependency from another model.
- A model-level `derived` field is silently overwritten; a field owned by a command or snapshot is rejected. Choose by whether the user should ever see an error for it.
- Derived and snapshot fields are still ordinary columns. They need `visibleOn` and, if they matter, rules like any other.
- `editableWhen` locks ordinary edits, not commands. A command runs on a locked record if `availableWhen` says yes, which is how an issued invoice can still be marked paid.
- Panel permissions hide buttons. The server enforces commands through `BeakActionPolicy`.

## Verify it

Start without a server. This scratch script calls `OrderItem.behavior.apply` on a draft with one product record, twice: once as it stands, once with the price marked as overridden (illustrative, not a file in the repo):

```dart
final behavior = OrderItem.behavior;
final beans = const ProductModel().record([
  ProductModel.name.to('Ethiopia Yirgacheffe'),
  ProductModel.price.to(const BeakDecimal(1850)),
]);
final draft = BeakRecord(
  values: const OrderItemModel().record([
    OrderItemModel.quantity.to(2),
    OrderItemModel.overwritePrice.to(const BeakDecimal(700)),
  ]).values,
  relations: {'product': [beans]},
);

final followed = behavior.apply(draft);
print('suggestion follows:  ${OrderItemModel.overwritePrice.readFrom(followed)}');

final overridden = behavior.apply(
  draft,
  overriddenFields: {OrderItemModel.overwritePrice.key},
);
print('user override kept:  ${OrderItemModel.overwritePrice.readFrom(overridden)}');
print('label:               ${OrderItemModel.label.readFrom(overridden)}');
```

The output is the three lines shown in the suggested section. The relation key `'product'` is the same one `OrderItemModel.product` carries.

Then run the two tests in the shop that exercise the same behavior end to end. The first drives the form session with a price override, the second boots the real host on in-memory SQLite and walks an invoice through `issue`, `markPaid` and a forged status:

```bash
cd examples/clean_beak_config
flutter test test/order_form_test.dart --plain-name "model suggestions follow catalog changes"
flutter test test/shop_api_test.dart --plain-name "invoice named actions"
```

```text
00:00 +1: All tests passed!
```

For your own model, the pattern in `shop_api_test.dart` is the one to copy: start `beakHost` with `DATABASE_URL` set to `sqlite::memory:`, migrate, and post plans through `BeakClient.commit`. Assert on `complete`, on `outcomes.single.error` and on a follow-up read, since a rejected save must leave the stored record as it was.

## Reference

| Symbol | What it is | Details |
| --- | --- | --- |
| `BeakModelBehavior` | `values`, `actions`, `editableWhen`, `deletableWhen`, plus `apply`, `validateEdits`, `canEdit` | [Behavior and actions](../reference/behavior-and-actions.md#beakmodelbehavior) |
| `BeakValueBehavior<T>` | One field, one lifecycle, `resolve`, `dependencies`, `onAction` | [Behavior and actions](../reference/behavior-and-actions.md#value-behavior) |
| `BeakValueLifecycle` | `initial`, `suggested`, `derived`, `snapshot` | [Behavior and actions](../reference/behavior-and-actions.md#value-behavior) |
| `BeakValueContext` | `record`, `initial`, `arguments`; `read`, `original`, `argument` | [Behavior and actions](../reference/behavior-and-actions.md#value-behavior) |
| `BeakModelAction` | `name`, `label`, `description`, `availableWhen`, `inputModel`, `allowOnCreate`, `values` | [Behavior and actions](../reference/behavior-and-actions.md#beakmodelaction) |
| `BeakActionPolicy` | Server-side gate for who may run a command | [Auth and policies](../backend/auth-and-policies.md) |

## Continue reading

- [Actions](../panel/actions.md) puts commands on rows, forms and bulk selections.
- [Transactional business rules](../backend/graph-business-rules.md) covers the server preparer that runs after behavior.
- [Behavior and actions](../reference/behavior-and-actions.md) lists every field, default and server message.
- [Files and storage columns](files-and-storage-columns.md) is the next schema topic: upload columns and their rules.
