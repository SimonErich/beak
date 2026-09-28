import 'package:beak_core/beak_core.dart';

/// Presentation override for a generated field; the source type stays unchanged.
sealed class BeakFormField {
  /// Targets a typed column instead of a handwritten field-name string.
  const BeakFormField({required this.column});

  /// The generated column configured by this override.
  final BeakColumn column;
}

/// A labeled wire value in a select or multi-select control.
final class BeakFormChoice {
  /// Creates an option, retaining its stable wire value separately from text.
  const BeakFormChoice({required this.value, required this.label});

  /// Stable value, such as a UUID or enum name.
  final String value;

  /// Localized display label.
  final String label;
}

/// Selects one scalar or a list of scalar values without a JSON text editor.
final class BeakFormChoiceField extends BeakFormField {
  /// Creates a choice control. [loadOptions] runs once when the field mounts.
  const BeakFormChoiceField({
    required super.column,
    this.options = const [],
    this.multiple = false,
    this.loadOptions,
    this.clearable = false,
  });

  /// Choices available synchronously.
  final List<BeakFormChoice> options;

  /// Whether the value is a list instead of one scalar.
  final bool multiple;

  /// Optional authenticated lookup; failures render with retry.
  final Future<List<BeakFormChoice>> Function()? loadOptions;

  /// Whether a nullable scalar may be explicitly cleared.
  final bool clearable;
}

/// Overrides text presentation, for example to obscure a create-only password.
final class BeakFormTextField extends BeakFormField {
  /// Creates a text override without changing the generated property's type.
  const BeakFormTextField({required super.column, this.obscureText = false});

  /// Whether to mask the input.
  final bool obscureText;
}
