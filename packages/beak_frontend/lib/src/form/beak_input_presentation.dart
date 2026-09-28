import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';

import 'beak_form_layout.dart';
import 'beak_form_session.dart';

/// Optional presentation override; model semantics remain authoritative.
enum BeakInputPresentation {
  /// Selects an editor from the model's semantic and physical types.
  automatic,

  /// A single boolean checkbox; shares binding and validation with a toggle.
  checkbox,

  /// Compact integer stepper using the field's numeric bounds.
  quantity,

  /// A searchable single-value choice list.
  select,

  /// A visible single-value radio group.
  radio,

  /// Bordered radio choices with optional icon and supporting description.
  radioCards,

  /// A searchable multiple-value choice list.
  multiSelect,

  /// Visible checkboxes for a typed primitive list.
  checkboxGroup,

  /// Removable tags, with optional suggestions.
  tags,

  /// A raw JSON document editor, retaining syntax errors until corrected.
  json,
}

/// One typed value offered by a declarative choice input.
final class BeakInputOption<T extends Object> {
  /// Describes an available value without string field references.
  const BeakInputOption(
    this.value,
    this.label, {
    this.enabled = true,
    this.description,
    this.icon,
  });

  /// Value stored by this option.
  final T value;

  /// Human-readable option label.
  final String label;

  /// Whether the option can currently be selected.
  final bool enabled;

  /// Optional explanation shown by richer choice presentations.
  final String? description;

  /// Optional decorative icon for a choice card.
  final IconData? icon;
}

/// Draft-dependent choices; reading typed fields tracks their dependencies.
typedef BeakInputChoices =
    List<BeakInputOption<Object>> Function(BeakFormReader state);

/// Compact quantity controls over generated integer fields.
extension BeakQuantityInputs on BeakScalarField<int> {
  /// Uses the model's minimum/maximum and the normal form validation pipeline.
  BeakInput<int> inputQuantity({
    String? label,
    double? controlWidth,
    String? description,
    List<BeakRule> validate = const [],
    List<BeakFieldValidator<int>> validators = const [],
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
    bool readOnly = false,
  }) => BeakInput(
    field: this,
    label: label,
    controlWidth: controlWidth,
    description: description,
    validate: validate,
    validators: validators,
    presentation: BeakInputPresentation.quantity,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
    readOnly: readOnly,
  );
}

/// Choice layouts for generated fields, including enum metadata by default.
extension BeakChoiceInputs<T extends Object> on BeakScalarField<T> {
  /// Places a selectable list; changing dependencies recomputes its choices.
  BeakInput<T> inputSelect({
    BeakInputChoices? options,
    String? label,
    String? description,
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => BeakInput(
    field: this,
    label: label,
    description: description,
    choices: options,
    presentation: BeakInputPresentation.select,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
  );

  /// Places a visible single-selection group with the same automatic binding.
  BeakInput<T> inputRadio({
    BeakInputChoices? options,
    String? label,
    String? description,
    bool cards = false,
    double? minCardWidth,
    EdgeInsetsGeometry? cardPadding,
    bool groupLabelAsField = false,
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => BeakInput(
    field: this,
    label: label,
    description: description,
    choices: options,
    choiceMinWidth: minCardWidth,
    choiceCardPadding: cardPadding,
    groupLabelAsField: groupLabelAsField,
    presentation: cards
        ? BeakInputPresentation.radioCards
        : BeakInputPresentation.radio,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
  );
}

/// Typed collection choices for generated primitive-list fields.
extension BeakListInputs<T extends Object> on BeakScalarField<List<T>> {
  /// Places a searchable multi-select backed by the typed list codec.
  BeakInput<List<T>> inputMultiSelect({
    required BeakInputChoices options,
    String? label,
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => BeakInput(
    field: this,
    label: label,
    choices: options,
    presentation: BeakInputPresentation.multiSelect,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
  );

  /// Places a visible checkbox group backed by the typed list codec.
  BeakInput<List<T>> inputCheckboxGroup({
    required BeakInputChoices options,
    String? label,
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => BeakInput(
    field: this,
    label: label,
    choices: options,
    presentation: BeakInputPresentation.checkboxGroup,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
  );
}

/// Free-form or constrained tags over a typed string list.
extension BeakTagInputs on BeakScalarField<List<String>> {
  /// Places removable tags with optional draft-dependent suggestions.
  BeakInput<List<String>> inputTags({
    BeakInputChoices? options,
    bool allowCustom = true,
    String? label,
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => BeakInput(
    field: this,
    label: label,
    choices: options,
    allowCustom: allowCustom,
    presentation: BeakInputPresentation.tags,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
  );
}

/// Declarative interpretation of string-backed category or custom attributes.
extension BeakAttributeInputs on BeakScalarField<String> {
  /// Selects the editor from the live definition while persisting a string.
  BeakInput<String> inputAttribute({
    BeakAttributeType Function(BeakFormReader state)? type,
    BeakAttributeDefinition? Function(BeakFormReader state)? definition,
    int? Function(BeakFormReader state)? version,
    BeakInputChoices? options,
    String? label,
    String? description,
    List<BeakFieldValidator<String>> validators = const [],
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => BeakInput(
    field: this,
    label: label,
    description: description,
    attributeType: type,
    attributeDefinition: definition,
    attributeVersion: version,
    choices: options,
    validators: validators,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
  );
}

/// Paired editors whose range ordering is validated before submission.
extension BeakRangeInputs<T extends Object> on BeakScalarField<T> {
  /// Places the start and end together, with an inclusive end by default.
  BeakFormLayout inputRange({
    required BeakScalarField<T> end,
    String? label,
    bool inclusive = true,
    BeakVisibility? visibleIf,
  }) => BeakSection(
    title: label ?? this.label,
    visibleIf: visibleIf,
    children: [
      BeakColumns(
        children: [
          input(label: 'From'),
          end.input(
            label: 'To',
            validators: [
              (value, state) =>
                  (inclusive
                          ? BeakAfterField<T>(end, this, inclusive: true)
                          : BeakAfterField<T>(end, this))
                      .validate(state.draft.snapshot)[end.qualifiedKey]
                      ?.firstOrNull,
            ],
          ),
        ],
      ),
    ],
  );
}

/// Calendar-only editors never convert values through an instant timezone.
extension BeakCalendarInputs on BeakScalarField<BeakDate> {
  /// Places a paired calendar range and validates its ordering automatically.
  BeakFormLayout inputDateRange({
    required BeakScalarField<BeakDate> end,
    String? label,
    BeakVisibility? visibleIf,
  }) => inputRange(end: end, label: label, visibleIf: visibleIf);

  /// Places a calendar date picker inferred from the model codec.
  BeakInput<BeakDate> inputDate({
    String? label,
    String? description,
    List<BeakRule> validate = const [],
    List<BeakInputOption<BeakDate>> Function(BeakFormReader)? shortcuts,
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => BeakInput(
    field: this,
    label: label,
    description: description,
    validate: validate,
    dateShortcuts: shortcuts,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
  );
}

/// Exact money helpers whose storage scale is explicit model metadata.
extension BeakExactInputs on BeakScalarField<BeakDecimal> {
  /// Places a lossless localized money editor with per-record currency support.
  BeakInput<BeakDecimal> inputCurrency({
    String? label,
    String? description,
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
    bool readOnly = false,
  }) => input(
    label: label,
    description: description,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
    readOnly: readOnly,
  );
}

/// Time-of-day controls preserve seconds and fractional seconds.
extension BeakTimeInputs on BeakScalarField<BeakTime> {
  /// Places a time editor independent of the current calendar date.
  BeakInput<BeakTime> inputTime({
    String? label,
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => input(label: label, visibleIf: visibleIf, enabledIf: enabledIf);
}

/// Elapsed durations can exceed 24 hours and retain microsecond precision.
extension BeakDurationInputs on BeakScalarField<Duration> {
  /// Places a duration editor using hours:minutes:seconds notation.
  BeakInput<Duration> inputDuration({
    String? label,
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => input(label: label, visibleIf: visibleIf, enabledIf: enabledIf);
}

/// Structured values retain their declared schema when edited as raw JSON.
extension BeakJsonInputs<T extends Object> on BeakScalarField<T> {
  /// Places a JSON editor without changing the field's typed codec.
  BeakInput<T> inputJson({
    String? label,
    BeakVisibility? visibleIf,
    BeakVisibility? enabledIf,
  }) => BeakInput(
    field: this,
    label: label,
    presentation: BeakInputPresentation.json,
    visibleIf: visibleIf,
    enabledIf: enabledIf,
  );
}
