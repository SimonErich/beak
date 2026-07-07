part of 'beak_block.dart';

/// A multi-step flow: each step shows a block body behind a step indicator,
/// with next/previous navigation and optional per-step gating.
///
/// Renders onto `OiWizard`. Unlike a single-page form, a wizard paces a long
/// data-entry flow (seller details → documents → bank → confirm). Step
/// bodies are ordinary blocks, so a step can hold form fields, a review, or
/// any content; collect their values in your own signals and read them in
/// [onComplete].
///
/// ```dart
/// BeakWizardBlock(
///   onComplete: submitApplication,
///   steps: [
///     BeakWizardStep(title: 'Seller', body: sellerFields),
///     BeakWizardStep(title: 'Bank', body: bankFields),
///     BeakWizardStep(title: 'Confirm', body: reviewSummary),
///   ],
/// );
/// ```
final class BeakWizardBlock extends BeakBlock {
  /// Creates a wizard over [steps].
  const BeakWizardBlock({
    required this.steps,
    this.stepperStyle = OiStepperStyle.horizontal,
    this.onComplete,
    super.span,
  });

  /// The steps, in order.
  final List<BeakWizardStep> steps;

  /// The visual style of the step indicator.
  final OiStepperStyle stepperStyle;

  /// Invoked when the user finishes the final step.
  final VoidCallback? onComplete;
}

/// One step of a [BeakWizardBlock].
@immutable
final class BeakWizardStep {
  /// Creates a step titled [title] showing [body].
  const BeakWizardStep({
    required this.title,
    required this.body,
    this.subtitle,
    this.icon,
    this.canAdvance,
  });

  /// The step label shown in the indicator.
  final String title;

  /// Supporting copy under the step title.
  final String? subtitle;

  /// The indicator icon.
  final IconData? icon;

  /// The step content.
  final BeakBlock body;

  /// Gate advancing past this step; returning `false` blocks Next (wire it
  /// to your step's validation). `null` always allows advancing.
  final bool Function()? canAdvance;
}
