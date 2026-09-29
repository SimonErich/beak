---
title: Overlays
description: Open confirmations, modals, dialogs, side sheets and toasts from an action context.
type: guide
audience: [expert]
status: draft
---

# Overlays

After this page you can raise a confirmation, a content modal, a dialog that returns a value, a side sheet, or a toast from anywhere you hold a build context, and you can render a block tree as the body of one.

`BeakOverlays` is a small handle bound to a `BuildContext`. Every method mounts through the panel's overlay stack (so overlays layer correctly over the shell) and renders with obers_ui. You reach it most often from an action, where the context exposes it as a getter, but you can wrap one around any build context yourself.

## Reaching the handle

Inside an action, `context.overlays` gives you the handle bound to that action's build context:

```dart title="packages/beak_frontend/lib/src/actions/beak_action.dart"
BeakOverlays get overlays => BeakOverlays(buildContext);
```

Elsewhere, construct one directly. The constructor takes the context and nothing else:

```dart title="packages/beak_frontend/lib/src/overlays/beak_overlays.dart"
const BeakOverlays(this.context);
```

## The five methods

| Method | Returns | Use it for |
| --- | --- | --- |
| `confirm(...)` | `Future<bool>` | a yes/no gate before a mutation |
| `modal(...)` | `Future<void>` | showing a block body with a single dismiss button |
| `dialog<T>(...)` | `Future<T?>` | a dialog that resolves with a value (a saved record) |
| `sheet<T>(...)` | `Future<T?>` | an offcanvas panel sliding in from an edge |
| `toast(...)` | `void` | a transient status message |

### confirm

`confirm` asks the user and returns `true` only when they accept. The confirm button renders destructively when `destructive` is set (and `destructive` defaults to `true`, since most confirmations gate something irreversible).

```dart title="packages/beak_frontend/lib/src/overlays/beak_overlays.dart"
Future<bool> confirm({
  required String title,
  String? message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = true,
}) async {
  // ...shows an OiDialog.confirm and resolves true on accept
}
```

Omitted messages and button labels use the current `BeakLocalizations`.

An action can call it directly for a tailored prompt, rather than relying on the automatic dialog that `requiresConfirmation` raises. An archive action of your own might read:

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

### modal and dialog

`modal` shows a `BeakBlock` body in a dialog with one dismiss button. It returns `Future<void>`; use it to present information, not to collect a result.

```dart title="packages/beak_frontend/lib/src/overlays/beak_overlays.dart"
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

When you need a value back (the record a form just saved, the option a user chose), use `dialog<T>`. Its `builder` receives a `close([result])` callback; call it with a value to resolve the returned future.

```dart title="packages/beak_frontend/lib/src/overlays/beak_overlays.dart"
Future<T?> dialog<T>({
  required String title,
  required Widget Function(void Function([T? result]) close) builder,
}) => showOiDialog<T>(
  context,
  builder: (dialogContext, close) =>
      OiDialog.standard(label: title, title: title, content: builder(close)),
);
```

`modal` takes a `BeakBlock` (a declarative body rendered through `BeakBlockHost`); `dialog` takes a `Widget` builder because it usually hosts something interactive whose result you want. This is the compose-email and calendar-event dialog primitive.

### sheet

`sheet<T>` slides a `BeakBlock` body in from an edge, the offcanvas or drawer pattern. It too returns a value, and defaults to the right edge.

```dart title="packages/beak_frontend/lib/src/overlays/beak_overlays.dart"
Future<T?> sheet<T>({
  required String title,
  required BeakBlock body,
  OiPanelSide side = OiPanelSide.right,
}) => OiSheet.showAsync<T>(
  context,
  label: title,
  side: side,
  builder: (close) => BeakBlockHost(block: body),
);
```

Because both `modal` and `sheet` take a `BeakBlock`, you compose their bodies from the same blocks the rest of the panel uses. See [The block system](../concepts/the-block-system.md) and the [Blocks](../blocks/index.md) section.

### toast

`toast` shows a transient message. It is fire-and-forget (it returns `void`) and lets you set a level and a screen position.

```dart title="packages/beak_frontend/lib/src/overlays/beak_overlays.dart"
void toast(
  String message, {
  OiToastLevel level = OiToastLevel.info,
  OiToastPosition position = OiToastPosition.bottomRight,
}) {
  OiToast.show(context, message: message, level: level, position: position);
}
```

!!! note "What just happened"
    - You reached `context.overlays` inside an action, no widget plumbing.
    - `confirm` gated the mutation, `toast` reported the result, `refresh` reloaded the surface.
    - `modal` and `sheet` bodies are `BeakBlock` trees; `dialog` builds a widget so it can hand you a value back.

!!! question "What this skipped"
    - The actions that raise overlays: [Actions](actions.md).
    - The blocks that fill a modal or sheet body: [The block system](../concepts/the-block-system.md).

## Continue reading

- [Actions](actions.md) the typed code that reaches overlays through `context.overlays`.
- [The block system](../concepts/the-block-system.md) how a `BeakBlock` body renders in a modal or sheet.
- [Blocks](../blocks/index.md) the block catalog you compose overlay bodies from.
- [Resources](resources.md) where the actions that raise overlays are declared.
