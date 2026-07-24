import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../blocks/beak_block.dart';
import '../blocks/beak_block_host.dart';

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

  /// Asks the user to confirm, returning `true` only when they accept.
  ///
  /// The confirm button renders destructively when [destructive] is set.
  Future<bool> confirm({
    required String title,
    String message = 'Please confirm this action.',
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = true,
  }) async {
    final bool? result = await showOiDialog<bool>(
      context,
      builder: (dialogContext, close) => OiDialog.confirm(
        label: title,
        title: title,
        content: OiLabel.body(message),
        actions: [
          OiButton.ghost(label: cancelLabel, onTap: () => close(false)),
          if (destructive)
            OiButton.destructive(label: confirmLabel, onTap: () => close(true))
          else
            OiButton.primary(label: confirmLabel, onTap: () => close(true)),
        ],
        onClose: close,
      ),
    );
    return result == true;
  }

  /// Shows a content [body] in a modal dialog with a single dismiss button.
  ///
  /// For a dialog that returns a value (a form's saved record), use
  /// [dialog].
  Future<void> modal({
    required String title,
    required BeakBlock body,
    String dismissLabel = 'Close',
  }) => showOiDialog<void>(
    context,
    builder: (dialogContext, close) => OiDialog.standard(
      label: title,
      title: title,
      content: BeakBlockHost(block: body),
      actions: [OiButton.secondary(label: dismissLabel, onTap: close)],
    ),
  );

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

  /// Slides a [body] in from an edge — the offcanvas / drawer primitive.
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

  /// Shows a transient toast message.
  void toast(
    String message, {
    OiToastLevel level = OiToastLevel.info,
    OiToastPosition position = OiToastPosition.bottomRight,
  }) {
    OiToast.show(context, message: message, level: level, position: position);
  }
}
