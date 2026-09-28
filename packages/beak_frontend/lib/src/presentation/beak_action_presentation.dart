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
  });

  /// Names a shared model command without writing a callback.
  const BeakActionPresentation.model(
    String name, {
    this.label,
    this.labelValue,
    this.selectionLabel,
    this.icon,
    this.destructive,
    this.group,
    this.placement = BeakActionPlacement.overflow,
  }) : key = 'model:$name';

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
