/// A semantic color token used by badges, actions, and status indicators.
///
/// `beak_core` never imports `dart:ui`: columns and actions reference colors
/// only by semantic role, and `beak_frontend` resolves each token against the
/// active obers_ui theme (`context.colors`).
enum BeakColor {
  /// The theme's primary accent color.
  primary,

  /// The theme's secondary accent color.
  secondary,

  /// Positive/confirming states (published, paid, active).
  success,

  /// Cautionary states (pending, low stock).
  warning,

  /// Destructive or failing states (rejected, out of stock).
  error,

  /// Neutral informational states.
  info,

  /// De-emphasized/disabled states.
  muted,
}
