part of 'beak_block.dart';

/// The severity of a [BeakAlertBlock].
enum BeakAlertLevel {
  /// Informational.
  info,

  /// Success.
  success,

  /// Warning.
  warning,

  /// Error.
  error,
}

/// A dismissible inline alert banner. Renders onto `OiBanner`.
final class BeakAlertBlock extends BeakBlock {
  /// Creates an alert showing [message] at [level].
  const BeakAlertBlock(
    this.message, {
    this.level = BeakAlertLevel.info,
    super.span,
  });

  /// The alert text.
  final String message;

  /// The severity.
  final BeakAlertLevel level;
}
