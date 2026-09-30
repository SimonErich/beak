---
title: Behavior and actions
description: Model behavior, value lifecycles and named commands in beak_core, plus the panel action types, with fields, defaults and server messages.
type: reference
audience: [expert, agent]
status: stable
search: {boost: 2}
---

# Behavior and actions

Two families share the word action. A `BeakModelAction` is a named command on one record, declared once on the model and enforced by the server. A `BeakAction` is a panel button (view, edit, delete, your own) that runs in the browser. This page lists the types of both, with their fields, defaults and the messages the server sends when a rule refuses.

## Import

```dart
import 'package:beak/beak.dart';
import 'package:beak/panel.dart';
```

The behavior types (`BeakModelBehavior`, `BeakValueBehavior`, `BeakModelAction`) are in `package:beak/beak.dart` and are safe to import from server code. The panel action types (`BeakAction`, `BeakRecordAction`, `BeakActionPresentation`) are in `package:beak/panel.dart`, which pulls in Flutter.

## Summary

| Type | Library | What it is |
| --- | --- | --- |
| `BeakModelBehavior` | core | Everything a model does on write: value calculations, commands, edit and delete guards |
| `BeakValueBehavior<T>` | core | One field's value definition, with a lifecycle |
| `BeakValueLifecycle` | core | `initial`, `suggested`, `derived`, `snapshot` |
| `BeakValueContext` | core | The read-only inputs a calculation receives |
| `BeakModelAction` | core | A named, transactional command on one record |
| `BeakAction` | panel | A button: `BeakRecordAction`, `BeakBulkAction`, `BeakGlobalAction` |
| Built-in actions | panel | `BeakViewAction`, `BeakEditAction`, `BeakCreateAction`, `BeakDeleteAction`, `BeakArchiveAction` |
| `BeakActionContext` | panel | What an executing action may reach for |
| `BeakActionPresentation` | panel | Where and how an existing action is drawn |
| `BeakModelActionRunner` | panel | Runs a model command through a form session and keeps unresolved ones recoverable |

Behavior is declared once on the schema class as a `static` getter and forwarded to the generated model, see [Annotations](annotations.md#beakschema).

```dart title="examples/clean_beak_config/lib/resources/orders/models/order_item.dart"
  /// Catalog suggestions follow selection changes until explicitly overridden.
  static BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior.suggested(
        field: OrderItemModel.overwritePrice,
        dependencies: [
          OrderItemModel.variant.price,
          OrderItemModel.product.price,
        ],
        resolve: (state) =>
            state.read(OrderItemModel.variant.price) ??
            state.read(OrderItemModel.product.price),
      ),
```

## BeakModelBehavior

```dart title="packages/beak_core/lib/src/behavior/beak_model_behavior.dart"
const BeakModelBehavior({
  this.values = const [],
  this.actions = const [],
  this.editableWhen,
  this.deletableWhen,
});
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `values` | `List<BeakValueBehavior<Object>>` | `[]` | Default, suggested, calculated and historical fields |
| `actions` | `List<BeakModelAction>` | `[]` | Commands the model supports |
| `editableWhen` | `bool Function(BeakRecord)?` | `null` (always editable) | Whether ordinary fields can change, evaluated on the stored record |
| `deletableWhen` | `bool Function(BeakRecord)?` | `null` (always deletable) | Whether the record can be removed, evaluated on the stored record |

| Member | Returns | Meaning |
| --- | --- | --- |
| `isEmpty` | `bool` | No values, actions or guards. The server skips graph preparation for models with an empty behavior. |
| `relationLoads` | `List<BeakRelationLoad>` | Related data the `derived` and `suggested` values depend on. Also identifies inverse records affected by a related edit. |
| `action(String name)` | `BeakModelAction` | Resolves a command received over the wire. Throws `Unknown action "x".` for an undeclared name. Application code holds the action object and never calls this. |
| `canEdit(String key, BeakRecord record)` | `bool` | Whether an ordinary editor may author the field: `editableWhen` allows it, no `derived` or `snapshot` value owns it, and no action's `values` own it |
| `initialize(BeakRecord)` | `BeakRecord` | Supplies only the `initial` values |
| `apply(BeakRecord, {initial, overriddenFields, action, arguments})` | `BeakRecord` | Evaluates the dependency graph without mutating its input |
| `validateEdits(BeakRecord, {initial, actionName, isCreate})` | `void` | Rejects direct edits to locked fields and action-controlled state |
| `validate(BeakModel model)` | `void` | Checks the declaration at registration |

`apply` runs the named action's `values` first, then the model's, each set in dependency order. `validateEdits` throws a `BeakValidationException` with the message `The record cannot be edited in this state.` and, per rejected field, `This field is controlled by the record workflow.`

`validate` throws a `BeakConfigurationException` for these declaration errors:

| Message | Cause |
| --- | --- |
| `Action names must be nonempty and unique.` | Two actions share a `name`, or one is empty |
| `Behavior field "x" must belong to <table>.` | A `field` is not a root column of this model |
| `Behavior dependencies must be rooted at <table>.` | A dependency belongs to another model |
| `Snapshot refers to unknown action "x".` | A `snapshot` names an action not in `actions` |
| `Duplicate behavior for "x".` | Two values own the same field |
| `Value dependency cycle at "x".` | Values depend on each other in a loop |

## Value behavior

```dart title="packages/beak_core/lib/src/behavior/beak_model_behavior.dart"
const BeakValueBehavior.initial({
  required this.field,
  required this.resolve,
  this.dependencies = const [],
}) : lifecycle = BeakValueLifecycle.initial,
     onAction = null;
const BeakValueBehavior.suggested({
  required this.field,
  required this.resolve,
  this.dependencies = const [],
}) : lifecycle = BeakValueLifecycle.suggested,
     onAction = null;
const BeakValueBehavior.derived({
  required this.field,
  required this.resolve,
  this.dependencies = const [],
}) : lifecycle = BeakValueLifecycle.derived,
     onAction = null;
const BeakValueBehavior.snapshot({
  required this.field,
  required this.resolve,
  required BeakModelAction this.onAction,
  this.dependencies = const [],
}) : lifecycle = BeakValueLifecycle.snapshot;
```

| Field | Type | Meaning |
| --- | --- | --- |
| `field` | `BeakScalarField<T>` | The field whose value this declaration owns. A root column of the declaring model. |
| `resolve` | `T? Function(BeakValueContext)` | Pure calculation. Must not read anything but the context. |
| `dependencies` | `List<BeakFieldRef<Object>>` | Fields `resolve` reads, in any order. Used to load related data and to order evaluation. |
| `lifecycle` | `BeakValueLifecycle` | Set by the named constructor |
| `onAction` | `BeakModelAction?` | The command that triggers a `snapshot`. The object itself, never its name. |

`evaluate(BeakValueContext)` returns the result encoded as a `BeakValue`.

| Lifecycle | Constructor | Applied when | Client can author it |
| --- | --- | --- | --- |
| `initial` | `.initial` | On a create, when the value is omitted. An explicit `null` is kept. | Yes |
| `suggested` | `.suggested` | While the user has not overridden it. A stored value that differs from what the calculation would have produced counts as an override, as does a manual edit in an unsaved session, a deliberate `null` included. | Yes |
| `derived` | `.derived` | Every save and every preview. A submitted value is ignored. | No |
| `snapshot` | `.snapshot` | Only while `onAction` executes. Freezes a historical value. | No |

`BeakValueContext` is what `resolve` receives:

```dart title="packages/beak_core/lib/src/behavior/beak_model_behavior.dart"
const BeakValueContext({
  required this.record,
  this.initial,
  this.arguments = const BeakRecord(values: {}),
});
```

| Member | Meaning |
| --- | --- |
| `record` | The proposed record, including dependencies already evaluated |
| `initial` | The stored record before this edit, `null` for a new record |
| `arguments` | The validated input of the executing action |
| `read(field)` | Typed value from `record` |
| `original(field)` | Typed value from `initial`, `null` without one |
| `argument(field)` | Typed value from the action's input model |

The same calculation runs in the form preview and on the server, so the two cannot disagree. The server re-evaluates on every write and repeats the pass while a suggested relationship changes what the next calculation reads. If the values do not settle, the write fails with `Model values did not stabilize after resolving relationships.`

```dart title="examples/foodio-adminpanel/lib/models/customer.dart"
      BeakValueBehavior.derived(
        field: CustomerModel.name,
        dependencies: [CustomerModel.firstName, CustomerModel.lastName],
        resolve: (state) => [
          state.read(CustomerModel.firstName),
          state.read(CustomerModel.lastName),
        ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' '),
      ),
      BeakValueBehavior.initial(
        field: CustomerModel.joinedAt,
        resolve: (_) => const FoodioClock().now,
      ),
```

## BeakModelAction

A named command on one record. The same declaration supplies the label, the allowed states and the typed input. Declare each command once as a static object and refer to that object everywhere: a form's submit action, a list's row and bulk actions, a snapshot's trigger and a preparer's `plan.runs(...)`.

```dart title="packages/beak_core/lib/src/behavior/beak_model_behavior.dart"
const BeakModelAction({
  required this.name,
  required this.label,
  this.description,
  this.availableWhen,
  this.inputModel,
  this.allowOnCreate = false,
  this.values = const [],
});
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | `String` | required | Identity on the wire. Unique within the model. No caller writes it. |
| `label` | `String` | required | Button and dialog title |
| `description` | `String?` | `null` | Text on confirmation and input surfaces |
| `availableWhen` | `bool Function(BeakRecord)?` | `null` (always available) | Allowed-state predicate on the stored record |
| `inputModel` | `BeakModel?` | `null` | Typed command inputs, using ordinary columns, defaults and rules |
| `allowOnCreate` | `bool` | `false` | Whether a create graph may execute the command in the same transaction |
| `values` | `List<BeakValueBehavior<Object>>` | `[]` | Field changes applied before the model's calculations and snapshots |

`isAvailable(BeakRecord record)` returns `availableWhen?.call(record) ?? true`.

```dart title="examples/clean_beak_config/lib/resources/invoices/models/invoice.dart"
abstract final class InvoiceActions {
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

### What the server checks

A command travels with the graph commit (`POST /api/commits`) as a root update operation. The server resolves the action, checks the caller and the state, validates the input and only then runs the calculations.

| Order | Check | Message on failure |
| --- | --- | --- |
| 1 | The action name is declared on the model | `Unknown action "x".` |
| 2 | The caller passes `BeakActionPolicy.canExecuteAction` when the app installed one | an authorization error |
| 3 | An action on a not-yet-saved record needs `allowOnCreate` | `Save the record before executing this action.` |
| 4 | `availableWhen` holds for the stored record | `This action is unavailable in the current state.` |
| 5 | The commit has a root update (or, with `allowOnCreate`, create) operation | `A command needs a root update operation.` |
| 6 | Input relations arrive as identities only | `Action relationships are resolved from their selected identities.` |
| 7 | `inputModel` defaults, column rules, record rules and async rules pass | A validation error with `fieldErrors`. Uniqueness and existence failures read `Invalid action inputs.` |
| 8 | An action without `inputModel` gets no input | `This action does not accept inputs.` |
| 9 | Input requires an action name | `Action inputs require a named action.` |

Guards apply outside commands too:

| Message | Guard |
| --- | --- |
| `The relationship is locked by its record workflow.` | Attaching or detaching a relation on a record whose `editableWhen` is false |
| `The owning record is locked by its workflow.` | Changing a child whose owner's `editableWhen` is false |
| `This record cannot be deleted in its current state.` | Deleting a record whose `deletableWhen` is false |
| `This field is controlled by the record workflow.` | Editing a `derived` or `snapshot` field or an action-controlled field directly |

A command's `inputModel` supports belongs-to relationship constraints only.

## Panel actions

`BeakAction` is sealed into three target shapes, so a surface switches over them exhaustively.

```dart
--8<-- "packages/beak_frontend/lib/src/actions/beak_action.dart:BeakAction"
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `key` | `String` | required | Stable identifier for test hooks and telemetry |
| `label` | `String` | required | Button label |
| `icon` | `IconData?` | `null` | Button icon |
| `color` | `BeakColor?` | `null` | `BeakColor.error` renders destructively, `BeakColor.primary` prominently |
| `requiresConfirmation` | `bool` | `false` | A dialog gates execution |

### BeakRecordAction

An action over one record (a table row or the record on a read page).

```dart title="packages/beak_frontend/lib/src/actions/beak_action.dart"
const BeakRecordAction({
  required super.key,
  required super.label,
  required this.onExecute,
  this.roles = const {
    BeakScreenRole.list,
    BeakScreenRole.read,
    BeakScreenRole.edit,
  },
  super.icon,
  super.color,
  super.requiresConfirmation,
});
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `onExecute` | `Future<void> Function(BeakRecord, BeakActionContext)` | required | Runs the action |
| `roles` | `Set<BeakScreenRole>` | list, read, edit | Generated surfaces that show the action. Presentation only. A create page has no saved record, so it draws no record action and `create` is not in the default |

Two factories cover common cases.

```dart title="packages/beak_frontend/lib/src/actions/beak_action.dart"
factory BeakRecordAction.link({
  required String key,
  required String label,
  required Uri? Function(BeakRecord record) uri,
  IconData? icon,
  Set<BeakScreenRole> roles = const {
    BeakScreenRole.list,
    BeakScreenRole.read,
  },
  BeakUriLauncher? launcher,
}) {
  // ...
}
```

```dart title="packages/beak_frontend/lib/src/actions/beak_action.dart"
factory BeakRecordAction.document({
  required String key,
  required String label,
  required BeakRecordDocument document,
  Set<BeakScreenRole> roles = const {
    BeakScreenRole.list,
    BeakScreenRole.read,
    BeakScreenRole.edit,
  },
  IconData? icon,
  BeakDocumentDelivery Function() beginDelivery = beginBeakDocumentDelivery,
}) {
  // ...
}
```

| Factory | Does |
| --- | --- |
| `.link` | Opens a website, email composer, phone dialer or SMS composer. Only `http`, `https`, `mailto`, `tel` and `sms` are accepted. `uri` returning `null` fails with `No contact address is available.` |
| `.document` | Prints a fresh authorized persisted snapshot of the record, never an unsaved draft. An unsaved record fails with `Save the record before printing.` Icon defaults to a printer. |

### BeakBulkAction

An action over the current selection. `onExecute` receives every selected record at once.

```dart title="packages/beak_frontend/lib/src/actions/beak_action.dart"
const BeakBulkAction({
  required super.key,
  required super.label,
  required this.onExecute,
  super.icon,
  super.color,
  super.requiresConfirmation,
});
```

```dart title="packages/beak_frontend/lib/src/actions/beak_action.dart"
factory BeakBulkAction.edit({
  required String key,
  required String label,
  required List<BeakFieldChange<Object>> changes,
  IconData? icon,
}) => BeakBulkAction(
  // ...
);
```

`.edit` applies a typed patch through a validation preview and per-record receipts. The built-in review handles progress, cancellation and interrupted saves. Each `BeakFieldChange(field, value)` is checked against the field's Dart type.

### BeakGlobalAction

A page-level action independent of any record.

```dart title="packages/beak_frontend/lib/src/actions/beak_action.dart"
const BeakGlobalAction({
  required super.key,
  required super.label,
  required this.onExecute,
  super.icon,
  super.color,
  super.requiresConfirmation,
});
```

### Built-in actions

| Class | Key | Label | Target | Behavior |
| --- | --- | --- | --- | --- |
| `BeakViewAction` | `view` | View | record | Navigates to the read page |
| `BeakEditAction` | `edit` | Edit | record | Navigates to the edit page |
| `BeakCreateAction` | `create` | Create | global | Navigates to the create page. Colour `primary`. |
| `BeakDeleteAction` | `delete` | Delete | record | Hides the record at once and offers an undo toast (`Record deleted`). The delete reaches the data source when the undo window passes, then returns to the list. Colour `error`. |
| `BeakDeleteAction.confirmed()` | `delete` | Delete | record | Asks first, waits for the server, then refreshes and returns to the list. No undo, and a refusal keeps you on the record. |
| `BeakArchiveAction` | `archive` | Archive | record | The confirmed delete under another key and label, through the resource's configured deletion operation. No restore is implied. |

`BeakResource.deleteAction` defaults to `const BeakDeleteAction()`. View, edit, delete and create appear where the resource flags, the model permissions and the server capabilities allow them, and `recordActions`, `bulkActions` and `globalActions` on the resource add to them, see [Panel and resource options](panel-options.md).

### BeakActionContext

What Beak hands to every action's `onExecute`.

```dart
--8<-- "packages/beak_frontend/lib/src/actions/beak_action.dart:BeakActionContext"
```

| Member | Meaning |
| --- | --- |
| `checkPermission(BeakAction action)` | Checks live presentation authorization and reports a denial without executing. Server authorization still applies. |
| `reportError(BeakException error)` | Sends a typed failure to `onError`, or shows an error toast |
| `overlays` | Confirmations, dialogs, sheets and toasts bound to `buildContext`, see [Overlays](../panel/overlays.md) |

### BeakActionPresentation

Changes how an existing action is drawn. Execution and policy stay shared.

```dart title="packages/beak_frontend/lib/src/presentation/beak_action_presentation.dart"
const BeakActionPresentation({
  required this.key,
  this.label,
  this.labelValue,
  this.selectionLabel,
  this.icon,
  this.destructive,
  this.group,
  this.placement = BeakActionPlacement.overflow,
}) : modelAction = null;
```

```dart title="packages/beak_frontend/lib/src/presentation/beak_action_presentation.dart"
BeakActionPresentation.model(
  BeakModelAction action, {
  this.label,
  this.labelValue,
  this.selectionLabel,
  this.icon,
  this.destructive,
  this.group,
  this.placement = BeakActionPlacement.overflow,
}) : key = keyOfModelAction(action),
     modelAction = action;
```

| Field | Type | Meaning |
| --- | --- | --- |
| `key` | `String` | Identity of a built-in or resource action (`view`, `edit`, `delete`, your own). `.model` derives `model:<name>`. |
| `label` | `String?` | Short surface-specific label |
| `labelValue` | `BeakValueBinding<String>?` | Record-aware label with automatically loaded dependencies |
| `selectionLabel` | `String Function(int count)?` | Label of a bulk action with the selected count |
| `icon` | `IconData?` | Surface-specific icon |
| `destructive` | `bool?` | Destructive emphasis |
| `group` | `String?` | Adjacent menu actions with different groups get a separator |
| `placement` | `BeakActionPlacement` | `overflow` (default), `icon`, `primary`, `column` |

`BeakActionPlacement.icon` is a compact icon button, `primary` a visible labelled action beside the record, `overflow` an entry in the row menu, and `column` an action for configured action columns with no menu entry. `BeakActionPresentation.keyOfModelAction(action)` returns `model:<name>`.

### Model commands in the panel

| Surface | How a model command appears |
| --- | --- |
| List rows | A `model:<name>` row action when the resource allows editing, visible while `isAvailable` holds |
| List bulk | Listed in `BeakListDefinition.bulkModelActions` or given as `BeakActionPresentation.model` in `bulkActions`. Asks once, then runs record by record, each saved independently. |
| Forms | `BeakFormActions(actions:)` places commands, `BeakFormActionInput(action:)` places a command's typed input inline. See [Screens and form layouts](screens-and-layouts.md). |

`BeakModelActionRunner.execute(model:, source:, recordId:, action:, prepare:, principal:, registry:)` runs a command through a form session and returns a `BeakModelActionOutcome`.

| `BeakModelActionOutcome` field | Meaning |
| --- | --- |
| `receipt` | The authoritative `BeakSaveResult`, when dispatch or recovery returned one |
| `error` | Validation, transport or configuration failure |
| `cancelled` | The user closed the input step before dispatch |
| `complete` | Every write completed |

A second invocation of a command whose outcome is unknown checks the original receipt and never submits again. Such commands stay in `runner.unresolved` (a `ReadonlySignal<List<BeakPendingModelAction>>`), keyed by principal, table, record and action name, and stay recoverable from any route. The message is `The outcome is not yet known. Run this action again to check its existing receipt; it will not be submitted twice.`

## Rules and limits

- Behavior fields are root columns of the declaring model. A dependency may reach related data through a relationship path such as `OrderItemModel.variant.price`.
- `resolve` and `availableWhen` run in the form and on the server, and the source requires them to be pure. Foodio's `initial` value reads a clock, which is only safe because `initial` runs once, on create.
- `derived` and `snapshot` fields are read-only to editors. Submitting a value for them is harmless, since the server recomputes it.
- Snapshot and derived fields are still ordinary columns, so they need `visibleOn` and validation like any other.
- Custom graph preparation may add writes beside a command's `values`. Those keep ordinary per-record authorization, see [Transactional business rules](../backend/graph-business-rules.md).
- Panel permissions hide buttons. The server enforces commands through `BeakActionPolicy`, see [Auth and policies](../backend/auth-and-policies.md).
- `roles` on a record action is presentation. It does not authorize.

## Source

- `packages/beak_core/lib/src/behavior/beak_model_behavior.dart` holds the behavior types and `BeakModelAction`.
- `packages/beak_backend/lib/src/service/beak_graph_commit_service.dart` prepares behavior and commands on the server.
- `packages/beak_backend/lib/src/auth/beak_action_policy.dart` declares `BeakActionPolicy`.
- `packages/beak_frontend/lib/src/actions/beak_action.dart` and `built_in_actions.dart` hold the panel actions.
- `packages/beak_frontend/lib/src/actions/beak_model_action_runner.dart` holds the command runner.
- `packages/beak_frontend/lib/src/presentation/beak_action_presentation.dart` holds `BeakActionPresentation`.

## Continue reading

- [Behavior](../models/behavior.md) walks through value lifecycles in a worked model.
- [Actions](../panel/actions.md) covers row, bulk and global actions on a resource.
- [Validation rules](validation-rules.md) lists the rules a command's input model can carry.
- [Transactional business rules](../backend/graph-business-rules.md) covers graph preparation on the server.
