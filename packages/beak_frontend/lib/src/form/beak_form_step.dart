import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';

/// One step of a wizard-style [BeakDataForm]: a titled group of the model's
/// [columns] with an optional explanatory [description], paced behind a step
/// indicator. Like a form section, listing a column here both selects and
/// orders it; columns in no step carry no field.
///
/// Passing `steps` to a form (or `formSteps` to a resource) renders the
/// create/edit form as an `OiWizard` — one page per step, with per-step
/// validation gating advance and the final step submitting.
///
/// ```dart
/// BeakFormStep(
///   title: 'Identity',
///   description: 'Who is this person? Their name and role.',
///   icon: OiIcons.user,
///   columns: [UserColumns.name, UserColumns.role],
/// )
/// ```
@immutable
final class BeakFormStep {
  /// Creates a step titled [title] over [columns].
  const BeakFormStep({
    required this.title,
    required this.columns,
    this.subtitle,
    this.description,
    this.icon,
  });

  /// The step label shown in the indicator.
  final String title;

  /// The model columns entered on this step, in order.
  final List<BeakColumn> columns;

  /// Supporting copy under the step title in the indicator.
  final String? subtitle;

  /// A longer explanation rendered at the top of the step body.
  final String? description;

  /// The step's indicator icon.
  final IconData? icon;
}
