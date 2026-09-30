import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';

import 'beak_record_template.dart';

/// Placement of an existing action in a record's action area.
enum BeakActionPlacement {
  /// Accessible compact icon button.
  icon,

  /// Visible labelled action beside the record.
  primary,

  /// Entry in the row's overflow menu.
  overflow,

  /// Available to configured action columns without an extra row-menu entry.
  column,
}

/// Changes presentation of an existing action; execution and policy stay shared.
final class BeakActionPresentation {
  /// Names a built-in/resource action, for example `view`, `edit`, or `delete`.
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

  /// Presents a shared model command, run without writing a callback.
  ///
  /// [action] is the command declared on the model's behavior; it is never
  /// named by a string.
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

  /// The runtime identity of the table action running [action].
  static String keyOfModelAction(BeakModelAction action) =>
      'model:${action.name}';

  /// The shared model command this presents, or null for a built-in or
  /// resource action.
  final BeakModelAction? modelAction;

  /// Runtime action identity, checked against configured available actions.
  final String key;

  /// Optional short surface-specific label.
  final String? label;

  /// Optional record-aware label with automatically loaded field dependencies.
  final BeakValueBinding<String>? labelValue;

  /// Optional selected-count label for a bulk action.
  final String Function(int count)? selectionLabel;

  /// Optional surface-specific icon.
  final IconData? icon;

  /// Optional destructive emphasis; execution still uses the shared policy.
  final bool? destructive;

  /// Adjacent menu actions with different groups receive a separator.
  final String? group;

  /// Visible or overflow presentation.
  final BeakActionPlacement placement;
}
