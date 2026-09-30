import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../blocks/beak_block.dart';
import '../blocks/beak_block_host.dart';
import '../localization/beak_localizations.dart';

/// How a confirmation ended: the person said yes, said no, or left.
enum BeakConfirmResult {
  /// The confirm button was pressed.
  confirmed,

  /// The cancel button was pressed: an explicit refusal.
  cancelled,

  /// The dialog was closed some other way, for example with Escape. Nothing was
  /// decided, so a caller may ask again instead of treating it as a refusal.
  dismissed,
}

/// A declarative overlay handle bound to a [BuildContext]: confirmations,
/// modals, side sheets (offcanvas), and toasts, all rendered with obers_ui.
///
/// Reach it from an action via `context.overlays`, or construct one directly
/// around any build context. Every method mounts through the panel's overlay
/// stack, so overlays layer correctly over the shell.
///
/// ```dart
/// BeakRecordAction(
///   key: 'archive',
///   label: 'Archive',
///   onExecute: (record, context) async {
///     if (!await context.overlays.confirm(title: 'Archive this order?')) {
///       return;
///     }
///     await context.dataSource.update(context.model.table, id, archived);
///     context.overlays.toast('Order archived');
///     await context.refresh?.call();
///   },
/// );
/// ```
final class BeakOverlays {
  /// Creates a handle mounting overlays from [context].
  const BeakOverlays(this.context);

  /// The build context overlays mount from.
  final BuildContext context;

  // --8<-- [start:BeakOverlaysConfirm]
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
  // --8<-- [end:BeakOverlaysConfirm]

  // --8<-- [start:BeakOverlaysModal]
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

  // --8<-- [end:BeakOverlaysModal]

  // --8<-- [start:BeakOverlaysDialog]
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

  // --8<-- [end:BeakOverlaysDialog]

  // --8<-- [start:BeakOverlaysSheet]
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

  // --8<-- [end:BeakOverlaysSheet]

  // --8<-- [start:BeakOverlaysToast]
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
  // --8<-- [end:BeakOverlaysToast]
}
