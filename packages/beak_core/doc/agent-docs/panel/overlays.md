# Overlays

> Raise a confirmation, modal, dialog, side sheet or toast from an action or any widget with a build context, and know how each one closes.

An action often has to ask, show or report something before it finishes: confirm a delete, show a preview, say that it worked. `BeakOverlays` is the small handle for that. It turns a build context into seven calls, and the panel mounts the result above the shell, so you never touch a `Navigator`.

## At a glance

| Method | Returns | Renders with | Closes when |
| --- | --- | --- | --- |
| `confirm(...)` | `Future<bool>` | `showOiDialog` and `OiDialog.confirm` | `true` on the confirm button, `false` on anything else |
| `ask(...)` | `Future<BeakConfirmResult>` | the same dialog | `confirmed`, `cancelled` on the Cancel button, `dismissed` on anything else |
| `modal(...)` | `Future<void>` | `showOiDialog` and `OiDialog.standard`, body is a `BeakBlock` | The single dismiss button, or a tap outside |
| `dialog<T>(...)` | `Future<T?>` | `showOiDialog` and `OiDialog.standard`, body is a `Widget` | Your content calls `close([result])`, or a tap outside resolves `null` |
| `sheet(...)` | `Future<void>` | `OiSheet.showAsync`, body is a `BeakBlock` | A tap outside the sheet, or Escape |
| `sheetWithResult<T>(...)` | `Future<T?>` | `OiSheet.showAsync`, body is a `Widget` | Your content calls `close([result])`, or a tap outside resolves `null` |
| `toast(...)` | `void` | `OiToast.show` | It times out (four seconds unless you say). Nothing to await |

Inside an action, the handle is `context.overlays`. Anywhere else it is one constructor call:

```dart title="packages/beak_frontend/lib/src/actions/beak_action.dart"
BeakOverlays get overlays => BeakOverlays(buildContext);
```

Beak uses it too: `executeBeakAction` asks with `confirm`, `BeakActionContext.reportError` shows an error `toast`, the command bar (Ctrl-K) and `BeakBulkAction.edit` open a `dialog`, and the sign-out button reports a failed logout with a `toast`.

## confirm

```dart title="packages/beak_frontend/lib/src/overlays/beak_overlays.dart"
/// Asks the user to confirm, returning `true` only when they accept.
///
/// Cancelling and leaving the dialog both answer `false`; [ask] tells them
/// apart. The confirm button renders destructively when [destructive] is set.
Future<bool> confirm({
  required String title,
  String? message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = true,
}) async =>
    await ask(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ) ==
    BeakConfirmResult.confirmed;

/// Asks the user to confirm and says how the question ended: [confirmed],
/// [cancelled] with the Cancel button, or [dismissed] by leaving the dialog.
Future<BeakConfirmResult> ask({
  required String title,
  String? message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = true,
}) async {
  final strings = BeakLocalizations.of(context);
  final bool? result = await showOiDialog<bool>(
    context,
    builder: (dialogContext, close) => OiDialog.confirm(
      label: title,
      title: title,
      content: OiLabel.body(message ?? strings.confirmAction),
      actions: [
        OiButton.ghost(
          label: cancelLabel ?? strings.cancel,
          onTap: () => close(false),
        ),
        if (destructive)
          OiButton.destructive(
            label: confirmLabel ?? strings.confirm,
            onTap: () => close(true),
          )
        else
          OiButton.primary(
            label: confirmLabel ?? strings.confirm,
            onTap: () => close(true),
          ),
      ],
      onClose: close,
    ),
  );
  return switch (result) {
    true => BeakConfirmResult.confirmed,
    false => BeakConfirmResult.cancelled,
    null => BeakConfirmResult.dismissed,
  };
}
```

`confirm` returns `true` only when the user presses the confirm button. Cancel, a tap on the scrim and the dialog's own close all return `false`. When the difference matters, `ask` takes the same arguments and returns a `BeakConfirmResult`: `confirmed`, `cancelled` (the Cancel button, an explicit no) or `dismissed` (Escape or a tap outside, where nothing was decided and asking again is reasonable).

`destructive` defaults to `true`, which draws the confirm button in the destructive style. That default suits the usual reason to ask (something is about to go). For a question that is merely a question, pass `destructive: false` and you get the primary button. Omitted `message`, `confirmLabel` and `cancelLabel` fall back to the panel's localization ("Please confirm this action.", "Confirm", "Cancel", and the German equivalents).

An action can skip `requiresConfirmation` and ask for itself when the wording matters. Illustrative, adapted from the class documentation (`id` and `archived` stand for the record's id and the update you build):

```dart
BeakRecordAction(
  key: 'archive',
  label: 'Archive',
  onExecute: (record, context) async {
    if (!await context.overlays.confirm(title: 'Archive this order?')) {
      return;
    }
    await context.dataSource.update(context.model.table, id, archived);
    context.overlays.toast('Order archived');
    await context.refresh?.call();
  },
);
```

## modal and dialog

Both open a dialog on the root navigator. The difference is who fills it.

`modal` takes a `BeakBlock` and gives you a dismiss button. Use it to show something, not to collect something.

```dart title="packages/beak_frontend/lib/src/overlays/beak_overlays.dart"
/// Shows a content [body] in a modal dialog with a single dismiss button.
///
/// For a dialog that returns a value (a form's saved record), use
/// [dialog].
Future<void> modal({
  required String title,
  required BeakBlock body,
  String? dismissLabel,
}) => showOiDialog<void>(
  context,
  builder: (dialogContext, close) => OiDialog.standard(
    label: title,
    title: title,
    content: BeakBlockHost(block: body),
    actions: [
      OiButton.secondary(
        label: dismissLabel ?? BeakLocalizations.of(context).close,
        onTap: close,
      ),
    ],
  ),
);

```

`dialog<T>` takes a widget builder and gives you a `close([result])` callback and nothing else, no buttons. Whatever you put in it must bring its own way out, and calling `close(value)` resolves the future with `value`. A tap on the scrim resolves `null`.

```dart title="packages/beak_frontend/lib/src/overlays/beak_overlays.dart"
/// Shows a value-returning modal dialog.
///
/// [builder] receives a `close([result])` callback; call it with a value
/// to resolve the returned future (e.g. the record a form just saved).
/// This is the compose-email / calendar-event dialog primitive.
Future<T?> dialog<T>({
  required String title,
  required Widget Function(void Function([T? result]) close) builder,
}) => showOiDialog<T>(
  context,
  builder: (dialogContext, close) =>
      OiDialog.standard(label: title, title: title, content: builder(close)),
);

```

The bulk edit is a real user: it hands the dialog a review widget and waits.

```dart title="packages/beak_frontend/lib/src/actions/beak_action.dart"
await context.overlays.dialog<void>(
  title: label,
  builder: (close) => SingleChildScrollView(
    child: BeakBulkEditView(
```

A `BeakBlock` body means a modal renders with the same blocks the panel uses everywhere else (see [The block system](../concepts/the-block-system.md) and [Blocks](../blocks/index.md)). A widget body is the escape hatch for anything interactive.

## sheet

`sheet` slides a `BeakBlock` in from an edge, right by default (obers_ui's own default is the bottom). `sheetWithResult<T>` does the same for a widget built by your function, which receives `close([result])`.

```dart title="packages/beak_frontend/lib/src/overlays/beak_overlays.dart"
/// Slides a [body] in from an edge — the offcanvas / drawer primitive.
///
/// The future completes when the sheet is dismissed. A block has no way to
/// return a value; use [sheetWithResult] for a sheet that answers a question.
Future<void> sheet({
  required String title,
  required BeakBlock body,
  OiPanelSide side = OiPanelSide.right,
}) => sheetWithResult<void>(
  title: title,
  side: side,
  builder: (close) => BeakBlockHost(block: body),
);

/// Slides in a sheet built by [builder], which receives `close([result])`:
/// call it to end the sheet and resolve the returned future with a value.
/// Dismissing the sheet without it resolves with `null`.
Future<T?> sheetWithResult<T>({
  required String title,
  required Widget Function(void Function([T? result]) close) builder,
  OiPanelSide side = OiPanelSide.right,
}) =>
    OiSheet.showAsync<T>(context, label: title, side: side, builder: builder);

```

Two things to know before you plan around it. The title is the sheet's accessible label, not a visible heading, so put a heading in the body. And a block cannot end the sheet or return a value: the user dismisses a `sheet` by tapping outside it or pressing Escape. If the sheet has to answer a question or carry its own Close button, use `sheetWithResult<T>` and call `close` from your widget.

## toast

```dart title="packages/beak_frontend/lib/src/overlays/beak_overlays.dart"
/// Shows a transient toast message for [duration], with an optional action
/// button labelled [actionLabel] that runs [onAction].
///
/// Give both or neither: an action needs a label to be drawn and a callback
/// to do anything.
void toast(
  String message, {
  OiToastLevel level = OiToastLevel.info,
  OiToastPosition position = OiToastPosition.bottomRight,
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  if ((actionLabel == null) != (onAction == null)) {
    throw const BeakConfigurationException(
      'A toast action needs both an actionLabel and an onAction.',
    );
  }
  OiToast.show(
    context,
    message: message,
    level: level,
    position: position,
    duration: duration,
    action: actionLabel == null
        ? null
        : OiButton.ghost(label: actionLabel, onTap: onAction),
  );
}
```

A toast is fire and forget. The level is `info`, `success`, `warning` or `error`, the position one of six (`topLeft`, `topCenter`, `topRight`, `bottomLeft`, `bottomCenter`, `bottomRight`, which is the default). Toasts stack instead of covering each other, stay for `duration` (four seconds by default) and pause while the pointer is over them. `actionLabel` and `onAction` add a button to the toast; give both or neither, or the call throws a `BeakConfigurationException`.

## Undo instead of ask

A confirmation is the right tool when the answer changes what happens. For a delete the user is likely to want back, an undo window costs less. `BeakOptimistic` wraps obers_ui's `OiOptimisticAction`: apply the change locally now, show an undo snackbar with the message, and call the backend only when the window passes.

```dart title="packages/beak_frontend/lib/src/data/optimistic.dart"
static Future<bool> mutate(
  BuildContext context, {
  required VoidCallback apply,
  required VoidCallback rollback,
  required Future<void> Function() commit,
  required String message,
  Duration undoDuration = const Duration(seconds: 5),
}) => OiOptimisticAction.execute(
```

It resolves `true` when the commit succeeded, and `false` when the user undid it or the commit failed. On failure it calls `rollback` and shows an error toast. Starting a second optimistic action commits the pending one at once. The built-in `BeakDeleteAction` and the data table's own delete button use it, and both catch a `BeakException` themselves, so a refusal restores the row and the toast says why, instead of the generic "Action failed". See [Actions](actions.md).

## Rules and limits

- `BeakOverlays` does not check `context.mounted`. Flutter refuses lookups on a deactivated element, so after any `await` in your own action, check `context.buildContext.mounted` before you open the next overlay. The framework does this in `reportError`, `checkPermission` and the delete actions, which is why a delete that finishes after you navigated away still ends quietly.
- An overlay needs the panel's overlay host above its context. A context from inside `BeakPanel` has one. In a widget test, pump an `OiApp` around the widget, as the package tests do.
- Dialogs open on the root navigator with the obers_ui defaults: dismissible by a tap outside, between 280 and 480 logical pixels wide. `BeakOverlays` exposes neither, so use `showOiDialog` directly for a non-dismissible or wider dialog. The save-view dialog does exactly that.
- `confirm` treats every dismissal as `false`. Use `ask` to tell "cancelled" from "closed".
- An overlay mounts on the root navigator, not under the page that opened it. Panel-wide scopes (dependencies, formatting, theme) reach it, page-level scopes such as `BeakRecordScope` or a list's query scope do not. A block that needs one must bring its own.
- Overlays do not read the resource's permissions. They only present; the caller checks.

## Verify it

The package tests pump a real obers_ui host and drive every method:

```console
$ cd packages/beak_frontend
$ flutter test test/src/overlays/beak_overlays_test.dart --reporter expanded
confirm resolves true when confirmed
confirm resolves false when cancelled
ask reports a confirmation
ask reports the Cancel button as a refusal
ask reports leaving the dialog as a dismissal
modal renders a block body and dismisses
dialog returns the value the content closes with
sheet slides a block body in from the edge
sheet a builder sheet returns the value its content closes with
toast shows a transient message
toast stays for the requested duration
toast offers an action that runs once
All tests passed!
```

## Reference

| Member | Signature | Notes |
| --- | --- | --- |
| `BeakOverlays(context)` | `const BeakOverlays(BuildContext context)` | Cheap to construct; holds only the context |
| `confirm` | `Future<bool> confirm({required String title, String? message, String? confirmLabel, String? cancelLabel, bool destructive = true})` | Localized defaults for the three strings |
| `ask` | `Future<BeakConfirmResult> ask({required String title, String? message, String? confirmLabel, String? cancelLabel, bool destructive = true})` | Same dialog as `confirm`; the enum has `confirmed`, `cancelled`, `dismissed` |
| `modal` | `Future<void> modal({required String title, required BeakBlock body, String? dismissLabel})` | `dismissLabel` defaults to the localized "Close" |
| `dialog<T>` | `Future<T?> dialog<T>({required String title, required Widget Function(void Function([T? result]) close) builder})` | Title is shown; no buttons |
| `sheet` | `Future<void> sheet({required String title, required BeakBlock body, OiPanelSide side = OiPanelSide.right})` | Title is the accessible label |
| `sheetWithResult<T>` | `Future<T?> sheetWithResult<T>({required String title, required Widget Function(void Function([T? result]) close) builder, OiPanelSide side = OiPanelSide.right})` | `close([result])` ends the sheet |
| `toast` | `void toast(String message, {OiToastLevel level = OiToastLevel.info, OiToastPosition position = OiToastPosition.bottomRight, Duration duration = const Duration(seconds: 4), String? actionLabel, VoidCallback? onAction})` | Stacked; action needs both label and callback |
| `BeakOptimistic.mutate` | `Future<bool> mutate(BuildContext, {apply, rollback, commit, message, undoDuration})` | Undo window defaults to five seconds |

## Continue reading

- [Actions](actions.md) the callbacks and model commands that reach overlays through their context.
- [Custom screens](custom-screens.md) pages and widgets to put in a modal body or a sheet.
- [Blocks](../blocks/index.md) the block catalog a modal or sheet renders.
- [Results and errors](../concepts/results-and-errors.md) how a failed action becomes a toast.
