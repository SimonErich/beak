---
title: Input builders
description: Look up every input*, tableForm and galleryForm builder, the node it returns, every parameter, and which rules run in the form and on the server.
type: reference
audience: [expert, agent]
status: stable
search: {boost: 2}
---

# Input builders

An input in a Beak form is a typed placement on a generated field, written as a method on that field: `ProductModel.name.inputText()`. This page lists every builder, the field type it exists on, the node it returns and every parameter.

## Import

```dart
import 'package:beak/panel.dart';
```

The builders are extension methods, so the import is what makes `ProductModel.name.inputText()` resolve. `package:beak/panel.dart` re-exports `package:beak/beak.dart`, which supplies `BeakRule`, `BeakDate`, `BeakDecimal` and the field types the signatures name. A field of the wrong type does not offer the builder: `inputText` on an `int` field is a compile error, not a runtime one.

## Summary

Scalar builders return a `BeakInput<T>` (or a `BeakFormLayout` for the two range builders). Relationship builders return a `BeakRelationInput`, and the collection builders return a `BeakRelationTable` or a `BeakGallery`.

| Builder | Defined on | Returns | Editor |
| --- | --- | --- | --- |
| `input` | `BeakScalarField<T>` | `BeakInput<T>` | Chosen from the column and its semantic, see [Automatic editors](#automatic-editors) |
| `inputText` | `BeakScalarField<String>` | `BeakInput<String>` | Text; multi-line when `maxLines` is above 1 |
| `inputNumber` | `BeakScalarField<T extends num>` | `BeakInput<T>` | Number input |
| `inputCurrency` | `BeakScalarField<T extends num>` | `BeakInput<T>` | Localized currency editor over a numeric draft value |
| `inputCurrency` | `BeakScalarField<BeakDecimal>` | `BeakInput<BeakDecimal>` | Exact money editor, currency from the semantic |
| `inputQuantity` | `BeakScalarField<int>` | `BeakInput<int>` | Compact stepper |
| `inputCheckbox` | `BeakScalarField<bool>` | `BeakInput<bool>` | Checkbox |
| `inputToggle` | `BeakScalarField<bool>` | `BeakInput<bool>` | Switch |
| `inputDateTime` | `BeakScalarField<DateTime>` | `BeakInput<DateTime>` | Date-time input |
| `inputDate` | `BeakScalarField<BeakDate>` | `BeakInput<BeakDate>` | Calendar date input with optional shortcuts |
| `inputDateRange` | `BeakScalarField<BeakDate>` | `BeakFormLayout` | Start and end dates with ordering validated |
| `inputTime` | `BeakScalarField<BeakTime>` | `BeakInput<BeakTime>` | Time-of-day input |
| `inputDuration` | `BeakScalarField<Duration>` | `BeakInput<Duration>` | Duration input, `hours:minutes:seconds` |
| `inputRange` | `BeakScalarField<T>` | `BeakFormLayout` | Two inputs, `From` and `To`, with ordering validated |
| `inputSelect` | `BeakScalarField<T>` | `BeakInput<T>` | Searchable single choice |
| `inputRadio` | `BeakScalarField<T>` | `BeakInput<T>` | Radio group, or radio cards |
| `inputMultiSelect` | `BeakScalarField<List<T>>` | `BeakInput<List<T>>` | Searchable multiple choice |
| `inputCheckboxGroup` | `BeakScalarField<List<T>>` | `BeakInput<List<T>>` | Visible checkboxes |
| `inputTags` | `BeakScalarField<List<String>>` | `BeakInput<List<String>>` | Removable tags |
| `inputAttribute` | `BeakScalarField<String>` | `BeakInput<String>` | Editor chosen from a live attribute definition |
| `inputJson` | `BeakScalarField<T>` | `BeakInput<T>` | Raw JSON editor |
| `inputCombobox` | `BeakToOneField` | `BeakRelationInput` | Searchable dropdown |
| `inputSearch` | `BeakToOneField` | `BeakRelationInput` | Search with inline results |
| `inputCards` | `BeakToOneField` | `BeakRelationInput` | Selectable cards |
| `inputCode` | `BeakToOneField` | `BeakRelationInput` | Exact code lookup with Apply and Remove |
| `tableForm` | `BeakToManyField` | `BeakRelationTable` | Editable related rows |
| `galleryForm` | `BeakToManyField` | `BeakGallery` | Ordered image collection |

`BeakRelationAdd`, `BeakRelationCatalog` and `BeakCatalogFilter` have no builder method; they are constructed directly and passed to `tableForm`.

## Shared parameters

Most scalar builders accept the same named parameters. Each builder section below lists the ones it accepts and then only its own.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String?` | field label | Label overriding the model metadata |
| `description` | `String?` | none | Guidance shown with the input |
| `validate` | `List<BeakRule>` | `const []` | Extra rules, run in the form only |
| `validators` | `List<BeakFieldValidator<T>>` | `const []` | Draft-aware validators, sync or async, run in the form only |
| `visibleIf` | `BeakVisibility?` | always visible | Predicate over the live draft; a hidden input is not validated and not submitted |
| `enabledIf` | `BeakVisibility?` | always enabled | Predicate over the live draft; a disabled input keeps its value but cannot be edited |
| `readOnly` | `bool` | `false` | Disables editing for this placement |
| `submitWhenHidden` | `bool` | `false` | Keeps a hidden input's value in the submitted command |
| `derive` | `T? Function(BeakFormReader)?` | none | Reactive calculation; the input is disabled and follows the tracked fields it reads |

### Function types

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
typedef BeakVisibility = bool Function(BeakFormReader state);
```

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
typedef BeakFieldValidator<T extends Object> =
    FutureOr<String?> Function(T? value, BeakFormReader state);
```

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
typedef BeakOptionDisabledReason =
    String? Function(BeakRecord record, BeakFormReader state);
```

```dart title="packages/beak_frontend/lib/src/form/beak_input_presentation.dart"
typedef BeakInputChoices =
    List<BeakInputOption<Object>> Function(BeakFormReader state);
```

`BeakFormReader` is the tracked reader every predicate receives. `state.read(ProductModel.name)` returns the typed value and records the dependency, so the input recomputes when that field changes. Reading a field of another model throws a `BeakConfigurationException`.

## Scalar builders

### input

Places the input the column and its semantic imply. It is also the builder behind a field wrapped with [`currency()` or `formatted()`](#display-formats).

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
BeakInput<T> input({
  String? label,
  String? description,
  List<BeakRule> validate = const [],
  List<BeakFieldValidator<T>> validators = const [],
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
  bool readOnly = false,
  bool submitWhenHidden = false,
  T? Function(BeakFormReader)? derive,
}) => BeakInput<T>(
  // ...
);
```

Accepts all shared parameters. A `BeakFormattedField` with the currency format switches the placement to the currency editor and carries its `minorUnits` and `scale`.

### inputText

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
BeakInput<String> inputText({
  String? label,
  String? description,
  int? maxLines,
  String? placeholder,
  bool? showCounter,
  double? controlHeightInPixels,
  EdgeInsetsGeometry? multilineContentPadding,
  List<BeakRule> validate = const [],
  List<BeakFieldValidator<String>> validators = const [],
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
  bool readOnly = false,
  bool obscureText = false,
  bool submitWhenHidden = false,
  String? Function(BeakFormReader)? derive,
}) => BeakInput(
  // ...
);
```

Accepts all shared parameters, plus:

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `maxLines` | `int?` | none | Visible line count; above 1 the editor is multi-line. Storage is unchanged. Must be above 0 |
| `placeholder` | `String?` | none | Hint text, independent of the accessible label |
| `showCounter` | `bool?` | shown when `maxLines` is above 1 | Overrides the character counter; the model's length limit still applies |
| `controlHeightInPixels` | `double?` | theme height | Minimum editor height, label and supporting text excluded |
| `multilineContentPadding` | `EdgeInsetsGeometry?` | theme padding | Padding of a multi-line editor, scoped to this placement |
| `obscureText` | `bool` | `false` | Conceals the characters |

### inputNumber and inputCurrency on numbers

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
BeakInput<T> inputNumber({
  String? label,
  String? description,
  List<BeakRule> validate = const [],
  List<BeakFieldValidator<T>> validators = const [],
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
  bool readOnly = false,
  bool submitWhenHidden = false,
  T? Function(BeakFormReader)? derive,
}) => input(
  // ...
);
```

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
BeakInput<T> inputCurrency({
  String? label,
  String? description,
  List<BeakRule> validate = const [],
  List<BeakFieldValidator<T>> validators = const [],
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
  bool readOnly = false,
  bool minorUnits = false,
  int scale = 2,
  bool submitWhenHidden = false,
  T? Function(BeakFormReader)? derive,
}) => BeakInput<T>(
  // ...
);
```

`inputNumber` accepts all shared parameters and uses the model's precision and limits. `inputCurrency` accepts all shared parameters, plus:

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `minorUnits` | `bool` | `false` | The stored value is an integer in minor units, for example cents |
| `scale` | `int` | `2` | Decimal places of the stored minor units, independent of the display currency. Must be 0 to 12 |

The draft value stays numeric. The editor shows the panel's currency code and formats through the panel's locale; intermediate text stays in the input until the value is complete.

### inputCurrency on exact decimals

```dart title="packages/beak_frontend/lib/src/form/beak_input_presentation.dart"
BeakInput<BeakDecimal> inputCurrency({
  String? label,
  String? description,
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
  bool readOnly = false,
}) => input(
  // ...
);
```

Accepts `label`, `description`, `visibleIf`, `enabledIf` and `readOnly`. The currency shown beside the input comes from the column's `BeakSemantic.money`: a fixed code, the value of the string column named by `currencyFrom` on the same record, or the panel's currency when neither is set. Parsing uses the panel's decimal separator and rejects excess decimal places instead of rounding.

### inputQuantity

```dart title="packages/beak_frontend/lib/src/form/beak_input_presentation.dart"
BeakInput<int> inputQuantity({
  String? label,
  double? controlWidthInPixels,
  String? description,
  List<BeakRule> validate = const [],
  List<BeakFieldValidator<int>> validators = const [],
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
  bool readOnly = false,
}) => BeakInput(
  // ...
);
```

Accepts `label`, `description`, `validate`, `validators`, `visibleIf`, `enabledIf` and `readOnly`, plus:

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `controlWidthInPixels` | `double?` | control default | Width of the stepper |

The stepper bounds come from the column's `min` and `max` and from `BeakMin` and `BeakMax` rules, the tightest wins. Without a minimum it starts at 0, without a maximum it stops at 2147483647.

### inputCheckbox and inputToggle

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
BeakInput<bool> inputCheckbox({
  String? label,
  String Function(BeakFormReader state)? labelBuilder,
  String? description,
  List<BeakFieldRef<Object>> dependencies = const [],
  List<BeakRule> validate = const [],
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
}) => BeakInput<bool>(
  // ...
);
```

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
BeakInput<bool> inputToggle({
  String? label,
  String? description,
  List<BeakRule> validate = const [],
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
}) => input(
  // ...
);
```

Both bind the same boolean field; only the control differs. `inputToggle` accepts `label`, `description`, `validate`, `visibleIf` and `enabledIf`. `inputCheckbox` accepts those and:

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `labelBuilder` | `String Function(BeakFormReader state)?` | none | Contextual label, for example a confirmation naming its recipient |
| `dependencies` | `List<BeakFieldRef<Object>>` | `const []` | Fields the label reads, loaded and permission checked |

A nullable `bool?` schema field generates a tri-state column. It renders as a radio group with `Not set`, the column's `trueLabel` and its `falseLabel`, whichever builder is used.

### inputDateTime

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
BeakInput<DateTime> inputDateTime({
  String? label,
  String? description,
  List<BeakRule> validate = const [],
  List<BeakFieldValidator<DateTime>> validators = const [],
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
}) => input(
  // ...
);
```

Accepts `label`, `description`, `validate`, `validators`, `visibleIf` and `enabledIf`. The value is an instant; the editor converts through the panel's time zone policy.

### inputDate, inputDateRange, inputTime, inputDuration

```dart title="packages/beak_frontend/lib/src/form/beak_input_presentation.dart"
BeakInput<BeakDate> inputDate({
  String? label,
  String? description,
  List<BeakRule> validate = const [],
  List<BeakInputOption<BeakDate>> Function(BeakFormReader)? shortcuts,
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
}) => BeakInput(
  // ...
);
```

```dart title="packages/beak_frontend/lib/src/form/beak_input_presentation.dart"
BeakFormLayout inputDateRange({
  required BeakScalarField<BeakDate> end,
  String? label,
  BeakVisibility? visibleIf,
}) => inputRange(end: end, label: label, visibleIf: visibleIf);
```

```dart title="packages/beak_frontend/lib/src/form/beak_input_presentation.dart"
BeakInput<BeakTime> inputTime({
  String? label,
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
}) => input(label: label, visibleIf: visibleIf, enabledIf: enabledIf);
```

```dart title="packages/beak_frontend/lib/src/form/beak_input_presentation.dart"
BeakInput<Duration> inputDuration({
  String? label,
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
}) => input(label: label, visibleIf: visibleIf, enabledIf: enabledIf);
```

| Builder | Accepts | Own parameters |
| --- | --- | --- |
| `inputDate` | `label`, `description`, `validate`, `visibleIf`, `enabledIf` | `shortcuts`: `List<BeakInputOption<BeakDate>> Function(BeakFormReader)?`, suggested dates: up to 4 appear as presets in the picker, 5 as a segmented control beside it, more as toggle buttons; any calendar date stays selectable |
| `inputDateRange` | `label`, `visibleIf` | `end`: required `BeakScalarField<BeakDate>` |
| `inputTime` | `label`, `visibleIf`, `enabledIf` | none; keeps seconds and fractional seconds |
| `inputDuration` | `label`, `visibleIf`, `enabledIf` | none; can exceed 24 hours and keeps microseconds |

Calendar dates never pass through a time zone: a `BeakDate` field reads and writes `YYYY-MM-DD`.

### inputRange

```dart title="packages/beak_frontend/lib/src/form/beak_input_presentation.dart"
BeakFormLayout inputRange({
  required BeakScalarField<T> end,
  String? label,
  bool inclusive = true,
  BeakVisibility? visibleIf,
}) => BeakSection(
  // ...
);
```

Returns a `BeakSection` titled `label` (default: the start field's label) with two columns labelled `From` and `To`. Parameters:

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `end` | `BeakScalarField<T>` | required | The field holding the end of the range |
| `label` | `String?` | start field's label | Section title |
| `inclusive` | `bool` | `true` | Whether an equal end is accepted |
| `visibleIf` | `BeakVisibility?` | always visible | Predicate over the live draft |

The end input carries a validator built on `BeakAfterField`, so the ordering error appears under `To` before submission. It compares dates, times, durations and numbers; other types throw a `BeakConfigurationException` when validated.

### inputSelect and inputRadio

```dart title="packages/beak_frontend/lib/src/form/beak_input_presentation.dart"
BeakInput<T> inputSelect({
  BeakInputChoices? options,
  String? label,
  String? description,
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
}) => BeakInput(
  // ...
);
```

```dart title="packages/beak_frontend/lib/src/form/beak_input_presentation.dart"
BeakInput<T> inputRadio({
  BeakInputChoices? options,
  String? label,
  String? description,
  bool cards = false,
  double? minCardWidthInPixels,
  EdgeInsetsGeometry? cardPadding,
  bool groupLabelAsField = false,
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
}) => BeakInput(
  // ...
);
```

Both accept `label`, `description`, `visibleIf` and `enabledIf`, plus `options`. Without `options`, an enum field offers its values with their labels.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `options` | `BeakInputChoices?` | enum values | Choices recomputed from the live draft; reading a typed field inside tracks it |
| `cards` | `bool` | `false` | `inputRadio` only. Bordered radio cards with optional icon and description instead of plain radios |
| `minCardWidthInPixels` | `double?` | one column | `inputRadio` only. Minimum card width; cards wrap into equal-width columns |
| `cardPadding` | `EdgeInsetsGeometry?` | theme padding | `inputRadio` only. Padding of description-bearing cards |
| `groupLabelAsField` | `bool` | `false` | `inputRadio` only. Uses the ordinary input label style for the group label |

`inputSelect` sets `BeakInputPresentation.select`. `inputRadio` sets `radio`, or `radioCards` when `cards` is true.

### inputMultiSelect and inputCheckboxGroup

```dart title="packages/beak_frontend/lib/src/form/beak_input_presentation.dart"
BeakInput<List<T>> inputMultiSelect({
  required BeakInputChoices options,
  String? label,
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
}) => BeakInput(
  // ...
);
```

```dart title="packages/beak_frontend/lib/src/form/beak_input_presentation.dart"
BeakInput<List<T>> inputCheckboxGroup({
  required BeakInputChoices options,
  String? label,
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
}) => BeakInput(
  // ...
);
```

Both exist on a field declared as a `List` of strings, integers, decimals or booleans. They accept `label`, `visibleIf` and `enabledIf`, and a required `options` (`BeakInputChoices`). `inputMultiSelect` is a searchable list, `inputCheckboxGroup` shows every checkbox.

### inputTags

```dart title="packages/beak_frontend/lib/src/form/beak_input_presentation.dart"
BeakInput<List<String>> inputTags({
  BeakInputChoices? options,
  bool allowCustom = true,
  String? label,
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
}) => BeakInput(
  // ...
);
```

Accepts `label`, `visibleIf` and `enabledIf`, plus:

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `options` | `BeakInputChoices?` | none | Suggestions; without `allowCustom` they are also the only accepted values |
| `allowCustom` | `bool` | `true` | Whether values outside the suggestions are accepted |

A `List<String>` field with no builder call renders as tags anyway.

### inputAttribute

```dart title="packages/beak_frontend/lib/src/form/beak_input_presentation.dart"
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
  // ...
);
```

Accepts `label`, `description`, `validators`, `visibleIf` and `enabledIf`, plus:

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `type` | `BeakAttributeType Function(BeakFormReader state)?` | `text` | Storage interpretation: `text`, `number`, `boolean` or `choice` |
| `definition` | `BeakAttributeDefinition? Function(BeakFormReader state)?` | none | Shared definition supplying label, description, choices and validation; its type wins over `type` |
| `version` | `int? Function(BeakFormReader state)?` | none | Revision stored with the value when definition changes are tracked |
| `options` | `BeakInputChoices?` | definition choices | Choices when no definition supplies them |

The value is always persisted as a string. The form checks `Enter a valid number.` for `number` and `Choose Yes or No.` for `boolean`. See [Dynamic attributes and variants](../models/dynamic-attributes-and-variants.md).

### inputJson

```dart title="packages/beak_frontend/lib/src/form/beak_input_presentation.dart"
BeakInput<T> inputJson({
  String? label,
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
}) => BeakInput(
  // ...
);
```

Accepts `label`, `visibleIf` and `enabledIf`. Edits the document as raw JSON and keeps the syntax error visible until it is corrected. The field keeps its typed codec, so an object semantic still validates its declared schema.

## Relationship builders

Every relationship input queries the related model for its options, recomputed when the draft fields it reads change. The four builders differ in the control only; binding, validation and eligibility are the same.

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
BeakRelationInput inputCombobox({
  BeakRecordTemplate? template,
  String? label,
  String? description,
  List<BeakScalarField<Object>> searchSources = const [],
  String? createLabel,
  List<BeakRule> validate = const [],
  BeakOptionQuery Function(BeakFormReader)? options,
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
  bool exclusive = true,
  BeakFormLayout? createForm,
}) => BeakRelationInput(
  // ...
);
```

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
BeakRelationInput inputSearch({
  BeakRecordTemplate? template,
  bool exclusive = true,
  BeakFormLayout? createForm,
  String? label,
  String? description,
  String? Function(BeakFormReader)? descriptionBuilder,
  List<BeakFieldRef<Object>> dependencies = const [],
  List<BeakScalarField<Object>> searchSources = const [],
  String? createLabel,
  String? createDescription,
  IconData? createIcon,
  List<BeakRule> validate = const [],
  BeakOptionQuery Function(BeakFormReader)? options,
  BeakOptionDisabledReason? disabledReason,
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
}) => BeakRelationInput(
  // ...
);
```

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
BeakRelationInput inputCards({
  BeakRecordTemplate? template,
  double minCardWidthInPixels = 260,
  BeakToOneField? defaultOption,
  bool Function(BeakRecord option, BeakFormReader state)? defaultOptionMatch,
  bool selectDefaultOption = false,
  String defaultOptionLabel = 'Default',
  bool compact = false,
  EdgeInsetsGeometry? cardPadding,
  bool exclusive = true,
  BeakFormLayout? createForm,
  String? label,
  String? description,
  String? Function(BeakFormReader)? descriptionBuilder,
  bool descriptionInline = false,
  List<BeakFieldRef<Object>> dependencies = const [],
  bool divider = false,
  List<BeakScalarField<Object>> searchSources = const [],
  String? createLabel,
  String Function(BeakFormReader)? createLabelBuilder,
  List<BeakRule> validate = const [],
  BeakOptionQuery Function(BeakFormReader)? options,
  BeakOptionDisabledReason? disabledReason,
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
}) => BeakRelationInput(
  // ...
);
```

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
BeakRelationInput inputCode({
  required BeakScalarField<String> codeField,
  String Function(String code)? normalizeCode,
  String? label,
  String? description,
  String? Function(BeakFormReader)? descriptionBuilder,
  String? placeholder,
  BeakRecordTemplate? template,
  BeakCalculated? selectionSummary,
  BeakOptionQuery Function(BeakFormReader)? options,
  BeakOptionDisabledReason? disabledReason,
  List<BeakRule> validate = const [],
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
}) => BeakRelationInput(
  // ...
);
```

The constructor holds every parameter; a builder forwards the ones listed in the last column.

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakRelationInput({
  required this.field,
  this.label,
  this.description,
  this.descriptionBuilder,
  this.descriptionInline = false,
  this.dependencies = const [],
  this.divider = false,
  this.validate = const [],
  this.options,
  super.enabledIf,
  this.createForm,
  this.exclusive = true,
  this.presentation = BeakRelationPresentation.combobox,
  this.template,
  this.selectionSummary,
  this.searchSources = const [],
  this.createLabel,
  this.createLabelBuilder,
  this.createDescription,
  this.createIcon,
  this.disabledReason,
  this.minCardWidthInPixels = 260,
  this.defaultOption,
  this.defaultOptionMatch,
  this.selectDefaultOption = false,
  this.defaultOptionLabel = 'Default',
  this.compact = false,
  this.cardPadding,
  this.codeField,
  this.normalizeCode,
  this.placeholder,
  super.visibleIf,
}) : assert(minCardWidthInPixels > 0);
```

| Parameter | Type | Default | Meaning | Builders |
| --- | --- | --- | --- | --- |
| `field` | `BeakToOneField` | required | The generated relationship field | all (the receiver) |
| `label` | `String?` | field label | Label overriding the model metadata | all |
| `description` | `String?` | none | Guidance shown with the input | all |
| `descriptionBuilder` | `String? Function(BeakFormReader)?` | none | Guidance computed from the draft | `inputCards`, `inputSearch`, `inputCode` |
| `descriptionInline` | `bool` | `false` | Places short guidance beside the heading | `inputCards` |
| `dependencies` | `List<BeakFieldRef<Object>>` | `const []` | Fields read by live labels and guidance, loaded with the form | `inputCards`, `inputSearch` |
| `divider` | `bool` | `false` | Separates the group from preceding content | `inputCards` |
| `validate` | `List<BeakRule>` | `const []` | Extra rules, run in the form only | all |
| `options` | `BeakOptionQuery Function(BeakFormReader)?` | related model's default query | Lookup query, recomputed when its draft dependencies change; must query the related table | all |
| `createForm` | `BeakFormLayout?` | none | Layout of the dialog that creates a related option | `inputCombobox`, `inputCards`, `inputSearch` |
| `exclusive` | `bool` | `true` | Whether selection is limited to existing records; `false` offers inline creation | `inputCombobox`, `inputCards`, `inputSearch` |
| `createLabel` | `String?` | none | Label of the inline creation action | `inputCombobox`, `inputCards`, `inputSearch` |
| `createLabelBuilder` | `String Function(BeakFormReader)?` | none | Live creation label | `inputCards` |
| `createDescription` | `String?` | none | Supporting text for the creation row | `inputSearch` |
| `createIcon` | `IconData?` | none | Icon of the creation action | `inputSearch` |
| `searchSources` | `List<BeakScalarField<Object>>` | relationship's search columns (its display column by default) plus searchable template fields | Typed search paths, rooted at the related model | `inputCombobox`, `inputCards`, `inputSearch` |
| `presentation` | `BeakRelationPresentation` | `combobox` | The control: `combobox`, `search`, `cards` or `code` | set by the builder |
| `template` | `BeakRecordTemplate?` | none | Identity, subtitle, avatar and badge of each option | all |
| `selectionSummary` | `BeakCalculated?` | none | Owner-draft calculation beside an applied code | `inputCode` |
| `disabledReason` | `BeakOptionDisabledReason?` | none | Why an option cannot be selected; enforced again at validation | `inputCards`, `inputSearch`, `inputCode` |
| `minCardWidthInPixels` | `double` | `260` | Width before cards wrap. Must be above 0 | `inputCards` |
| `defaultOption` | `BeakToOneField?` | none | Related record on the owner draft marking the recommended card | `inputCards` |
| `defaultOptionMatch` | `bool Function(BeakRecord option, BeakFormReader state)?` | none | Marks the recommended option by predicate; owner fields used must be in `dependencies` | `inputCards` |
| `selectDefaultOption` | `bool` | `false` | Selects a matching default while nothing is selected; a manual choice wins | `inputCards` |
| `defaultOptionLabel` | `String` | `'Default'` | Caption on the recommended option | `inputCards` |
| `compact` | `bool` | `false` | Compact padding and a trailing selection check | `inputCards` |
| `cardPadding` | `EdgeInsetsGeometry?` | presentation default | Inset of a choice card | `inputCards` |
| `codeField` | `BeakScalarField<String>?` | none | Unique string field on the related model; required for `code` | `inputCode` (required) |
| `normalizeCode` | `String Function(String code)?` | none | Canonicalizes the typed code, for example to uppercase | `inputCode` |
| `placeholder` | `String?` | none | Hint for code entry | `inputCode` |
| `visibleIf` | `BeakVisibility?` | always visible | Predicate over the live draft | all |
| `enabledIf` | `BeakVisibility?` | always enabled | Predicate over the live draft | all |

`BeakRelationPresentation` values:

| Value | Control |
| --- | --- |
| `combobox` | Searchable dropdown; clearable when the relation is optional |
| `search` | Search field followed by inline record results |
| `cards` | Rich selectable cards |
| `code` | Exact code lookup with explicit Apply and Remove actions |

Eligibility comes from the model. A `BeakExists` rule on the backing foreign key adds its `where` filter and its `matching` joins to the option query, and the input waits until the fields it matches on have values (the combobox hints `Select <fields> first.`). The same rule runs on the server, so the picker and the API agree on which records are selectable.

`inputCode` looks the code up with an exact match on `codeField` (after `normalizeCode`), asking for two records to detect ambiguity. No match reports `No available record matches this code.`, more than one reports `This code matches more than one record.`.

## Collection builders

### tableForm

Edits the rows of a to-many relationship. Every change belongs to the parent draft and is saved with it in one graph commit.

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
BeakRelationTable tableForm({
  required List<BeakFormNode> children,
  String? label,
  bool showHeading = true,
  bool showAddAction = true,
  bool? showColumnHeadings,
  EdgeInsetsGeometry rowPadding = const EdgeInsets.symmetric(vertical: 12),
  double rowMinHeightInPixels = 0,
  double rowGapInPixels = 16,
  bool reserveActions = false,
  double minRowWidthInPixels = 560,
  double? identityControlHeightInPixels,
  double identityControlWidthInPixels = 140,
  bool showRowDividers = true,
  int identityFlex = 2,
  List<BeakFormNode> identityChildren = const [],
  List<double?> columnWidths = const [],
  List<AlignmentGeometry> columnAlignments = const [],
  BeakFormLayout? advancedForm,
  EdgeInsetsGeometry advancedContentPadding = const EdgeInsets.all(12),
  BeakAdvancedPresentation advancedPresentation =
      BeakAdvancedPresentation.dialog,
  BeakVisibility? advancedReadVisibleIf,
  BeakRelationCatalog? catalog,
  BeakRecordTemplate? rowTemplate,
  BeakRelationTablePresentation presentation =
      BeakRelationTablePresentation.cards,
  bool readOnly = false,
  bool allowAdding = true,
  bool allowEdit = true,
  bool allowRemove = true,
  int minRows = 0,
  BeakRemoveBehavior removeBehavior = BeakRemoveBehavior.detach,
  Object? Function(List<BeakFormReader>)? summary,
  BeakValueFormat summaryFormat = BeakValueFormat.text,
  String? summaryLabel,
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
}) => BeakRelationTable(
  // ...
);
```

`tableForm` forwards every parameter of the `BeakRelationTable` constructor except `field`, which is the receiver.

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakRelationTable({
  required this.field,
  required this.children,
  this.label,
  this.showHeading = true,
  this.showAddAction = true,
  this.showColumnHeadings,
  this.rowPadding = const EdgeInsets.symmetric(vertical: 12),
  this.rowMinHeightInPixels = 0,
  this.rowGapInPixels = 16,
  this.reserveActions = false,
  this.minRowWidthInPixels = 560,
  this.identityControlHeightInPixels,
  this.identityControlWidthInPixels = 140,
  this.showRowDividers = true,
  this.identityFlex = 2,
  this.identityChildren = const [],
  this.columnWidths = const [],
  this.columnAlignments = const [],
  this.advancedForm,
  this.advancedContentPadding = const EdgeInsets.all(12),
  this.advancedPresentation = BeakAdvancedPresentation.dialog,
  this.advancedReadVisibleIf,
  this.catalog,
  this.rowTemplate,
  this.presentation = BeakRelationTablePresentation.cards,
  this.readOnly = false,
  this.allowAdding = true,
  this.allowEdit = true,
  this.allowRemove = true,
  this.minRows = 0,
  this.removeBehavior = BeakRemoveBehavior.detach,
  super.enabledIf,
  this.summary,
  this.summaryFormat = BeakValueFormat.text,
  this.summaryLabel,
  super.visibleIf,
}) : assert(minRows >= 0),
     assert(identityFlex > 0),
     assert(rowMinHeightInPixels >= 0),
     assert(minRowWidthInPixels > 0),
     assert(
       identityControlHeightInPixels == null ||
           identityControlHeightInPixels > 0,
     );
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `children` | `List<BeakFormNode>` | required | Inputs of each row, in column order |
| `label` | `String?` | relation label | Label overriding the model metadata |
| `showHeading` | `bool` | `true` | Repeats the collection heading inside the owning section or card |
| `showAddAction` | `bool` | `true` | Renders the default add control; place it elsewhere with `BeakRelationAdd` |
| `showColumnHeadings` | `bool?` | follows `showHeading` | Column headings of compact rows, independent of the title |
| `rowPadding` | `EdgeInsetsGeometry` | `EdgeInsets.symmetric(vertical: 12)` | Insets around each compact row |
| `rowMinHeightInPixels` | `double` | `0` | Minimum compact-row height. Must not be negative |
| `rowGapInPixels` | `double` | `16` | Space between identity, data columns and actions |
| `reserveActions` | `bool` | `false` | Keeps the action column in read mode so read and edit values align |
| `minRowWidthInPixels` | `double` | `560` | Width below which compact cells stack with their labels. Must be above 0 |
| `identityControlHeightInPixels` | `double?` | theme size | Input height beside identity metadata. Must be above 0 when set |
| `identityControlWidthInPixels` | `double` | `140` | Width of an inline identity control |
| `showRowDividers` | `bool` | `true` | Separator above each compact row |
| `identityFlex` | `int` | `2` | Width of the identity relative to a scalar cell. Must be above 0 |
| `identityChildren` | `List<BeakFormNode>` | `const []` | Compact controls beside the identity, bound like `children` |
| `columnWidths` | `List<double?>` | `const []` | Preferred cell widths in `children` order; null entries share the rest |
| `columnAlignments` | `List<AlignmentGeometry>` | `const []` | Alignment inside each data column, in read and edit mode |
| `advancedForm` | `BeakFormLayout?` | none | Extra row inputs, opened per `advancedPresentation` |
| `advancedContentPadding` | `EdgeInsetsGeometry` | `EdgeInsets.all(12)` | Insets of an inline advanced form |
| `advancedPresentation` | `BeakAdvancedPresentation` | `dialog` | How `advancedForm` opens |
| `advancedReadVisibleIf` | `BeakVisibility?` | none | Shows inline advanced details in read-only compact rows only when true |
| `catalog` | `BeakRelationCatalog?` | none | Searchable catalog that stages new owned rows |
| `rowTemplate` | `BeakRecordTemplate?` | none | Identity shown above each row's fields |
| `presentation` | `BeakRelationTablePresentation` | `cards` | Row geometry |
| `readOnly` | `bool` | `false` | Displays the collection without an edit owner |
| `allowAdding` | `bool` | `true` | New local rows may be added |
| `allowEdit` | `bool` | `true` | Existing row inputs may be edited |
| `allowRemove` | `bool` | `true` | A row may be removed |
| `minRows` | `int` | `0` | Rows required before the form can save. Must not be negative |
| `removeBehavior` | `BeakRemoveBehavior` | `detach` | What removing a persisted row does |
| `summary` | `Object? Function(List<BeakFormReader> rows)?` | none | Reactive summary of the current, non-removed rows |
| `summaryFormat` | `BeakValueFormat` | `text` | Format of the summary result |
| `summaryLabel` | `String?` | none | Heading shown beside the summary |
| `visibleIf` | `BeakVisibility?` | always visible | Predicate over the live draft |
| `enabledIf` | `BeakVisibility?` | always enabled | Predicate over the live draft |

| Enum | Values |
| --- | --- |
| `BeakRelationTablePresentation` | `cards` (independently grouped row cards), `rows` (compact separated rows) |
| `BeakAdvancedPresentation` | `dialog` (checkpointed; Cancel restores the row and its descendants), `inline` (disclosure within the row) |
| `BeakRemoveBehavior` | `detach` (removes membership, keeps the record), `deleteOwned` (deletes the record; only for an owned has-many) |

A minimum shows as `Add at least N row(s).` next to the collection. The computed `rowLayout` getter combines `identityChildren`, `children`, `advancedForm` and, when a catalog is set, the catalog's selection input and quantity input.

Real usage, from the package tests. `_products` is the `BeakToManyField`, `_price` a scalar field of the row model and `_Basket.locked` a `bool` field of the owner:

```dart title="packages/beak_frontend/test/src/form/declarative_layout_and_formatting_test.dart"
_products.tableForm(
  minRows: 1,
  children: [
    _price.inputCurrency(
      minorUnits: true,
      validate: const [BeakRequired()],
    ),
  ],
  summary: (rows) =>
      rows.fold<num>(
        0,
        (sum, row) => sum + (row.read(_price) ?? 0),
      ) /
      100,
  summaryLabel: 'Total',
  summaryFormat: BeakValueFormat.currency,
  enabledIf: (state) => state.read(_Basket.locked) != true,
),
```

### BeakRelationCatalog

Turns a bounded option query into a searchable list that stages one owned row per chosen record. Choosing an option binds `selection` on a new row, and the row model's defaults and behavior fill quantity, prices and other fields.

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakRelationCatalog({
  required this.selection,
  required this.template,
  this.options,
  this.disabledReason,
  this.searchLabel = 'Search catalog',
  this.addLabel = 'Add',
  this.groupBy,
  this.variantLabel,
  this.price,
  this.quantity,
  this.searchSources = const [],
  this.tabs = const [],
  this.filters = const [],
  this.maxOptions,
  this.pageSize,
  this.presentation = BeakCatalogPresentation.cards,
  this.compactToolbar = false,
  this.columnLabels,
  this.notice,
  this.footer,
  this.dependencies = const [],
  this.groupOrder,
  this.controlHeightInPixels,
  this.advancedLabel,
}) : assert(maxOptions == null || maxOptions > 0),
     assert(
       presentation != BeakCatalogPresentation.checkboxes ||
           (groupBy == null && quantity == null && maxOptions != null),
       'Checkbox catalogs require a finite maxOptions and no quantity or grouping.',
     ),
     assert(pageSize == null || pageSize > 0),
     assert(
       pageSize == null || maxOptions != null,
       'Group pagination requires an explicit finite maxOptions.',
     );
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `selection` | `BeakToOneField` | required | Relationship on the new row that receives the chosen catalog record |
| `template` | `BeakRecordTemplate` | required | Presentation of each available catalog record |
| `options` | `BeakOptionQuery Function(BeakFormReader)?` | default options of `selection` | Catalog query, evaluated against the collection owner's draft |
| `disabledReason` | `BeakOptionDisabledReason?` | none | Why a catalog option cannot be added |
| `searchLabel` | `String` | `'Search catalog'` | Search field label |
| `addLabel` | `String` | `'Add'` | Label of the add action |
| `groupBy` | `BeakScalarField<Object>?` | none | Groups options, for example variants by product |
| `variantLabel` | `BeakScalarField<String>?` | none | Option text in a grouped variant selector |
| `price` | `BeakScalarField<Object>?` | none | Formatted price beside the selected variant |
| `quantity` | `BeakScalarField<int>?` | none | Quantity on the staged row; enables increment and decrement |
| `searchSources` | `List<BeakScalarField<Object>>` | `const []` | Typed search paths; searchable template fields are added |
| `tabs` | `List<BeakCatalogFilter>` | `const []` | Mutually exclusive category filters; the first is selected initially |
| `filters` | `List<BeakCatalogFilter>` | `const []` | Independent facets combined with the tab and the query |
| `maxOptions` | `int?` | none | Finite bound for a small catalog. Must be above 0 |
| `pageSize` | `int?` | none | Groups per page; requires `maxOptions`. Staged rows survive paging, search and filter changes |
| `presentation` | `BeakCatalogPresentation` | `cards` | Catalog layout |
| `compactToolbar` | `bool` | `false` | Search beside segmented categories, facets as chips |
| `columnLabels` | `({String item, String variant, String quantity})?` | none | Headings aligned with compact row identity, variant and quantity |
| `notice` | `BeakFormNotice?` | none | Advisory content between the filters and the rows; observes the owner's draft |
| `footer` | `String?` | none | Guidance after the catalog |
| `dependencies` | `List<BeakFieldRef<Object>>` | `const []` | Owner fields used by dynamic facets and group ordering |
| `groupOrder` | `List<Object> Function(BeakFormReader state)?` | none | Preferred group keys in display order |
| `controlHeightInPixels` | `double?` | none | Compact input height |
| `advancedLabel` | `BeakValueBinding<String>?` | none | Metadata link for selected options, with a visibility rule |

| `BeakCatalogPresentation` | Layout |
| --- | --- |
| `checkboxes` | Compact checkbox choices, each staging or removing one row. Requires a finite `maxOptions`, no `quantity`, no `groupBy` |
| `cards` | Spacious cards for rich descriptions |
| `rows` | Compact separated rows with inline variant, price and quantity controls |

#### BeakCatalogFilter

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakCatalogFilter({
  required this.label,
  this.filter,
  this.filterBuilder,
  this.matches,
  this.dependencies = const [],
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String` | required | Visible category or facet name |
| `filter` | `BeakFilter?` | none | Constraint on the catalog model, including typed related paths; null means all options |
| `filterBuilder` | `BeakFilter? Function(BeakFormReader state)?` | none | Extra scope from the owner's live draft; declare related reads in the catalog's `dependencies` |
| `matches` | `bool Function(BeakRecord record)?` | none | Local presentation facet over the fully loaded catalog; requires `maxOptions` and never replaces server policy |
| `dependencies` | `List<BeakFieldRef<Object>>` | `const []` | Fields read by `matches` |

### BeakRelationAdd

Places the managed add action of a collection somewhere other than the table.

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakRelationAdd({
  required this.field,
  this.label,
  this.caption,
  this.presentation = BeakRelationAddPresentation.dashed,
  this.placeholder,
  super.visibleIf,
  super.enabledIf,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `field` | `BeakToManyField` | required | Collection already declared by a `BeakRelationTable` in the same form |
| `label` | `String?` | none | Action label |
| `caption` | `String?` | none | Supporting deadline or hint |
| `presentation` | `BeakRelationAddPresentation` | `dashed` | `dashed` (quiet dashed action) or `search` (outlined, search-shaped action) |
| `placeholder` | `String?` | none | Search-like hint; the accessible action keeps `label` |
| `visibleIf` | `BeakVisibility?` | always visible | Predicate over the live draft |
| `enabledIf` | `BeakVisibility?` | always enabled | Predicate over the live draft |

### galleryForm

Displays owned image records as ordered cards with editable metadata. The first image is the cover.

```dart title="packages/beak_frontend/lib/src/form/beak_gallery.dart"
BeakGallery galleryForm({
  required BeakScalarField<String> image,
  required BeakScalarField<String> caption,
  required BeakScalarField<int> position,
  String? label,
  int minRows = 0,
  List<BeakFormNode> metadata = const [],
  BeakVisibility? visibleIf,
  BeakVisibility? enabledIf,
}) => BeakGallery(
  // ...
);
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `image` | `BeakScalarField<String>` | required | Child field holding the storage key; must be a `BeakImageColumn` |
| `caption` | `BeakScalarField<String>` | required | Child field with the image description |
| `position` | `BeakScalarField<int>` | required | Child field with the zero-based order, rewritten by the move controls |
| `label` | `String?` | relation label | Label overriding the model metadata |
| `minRows` | `int` | `0` | Images required before the form can save |
| `metadata` | `List<BeakFormNode>` | `const []` | Extra inputs on each image card, between the caption and the position |
| `visibleIf` | `BeakVisibility?` | always visible | Predicate over the live draft |
| `enabledIf` | `BeakVisibility?` | always enabled | Predicate over the live draft |

`BeakGallery` extends `BeakRelationTable` with `removeBehavior: BeakRemoveBehavior.deleteOwned`. Its rows carry the image input, the caption input, the `metadata` nodes and a hidden, read-only position input that is submitted anyway. Members:

| Member | Meaning |
| --- | --- |
| `orderedRows(BeakDraftRecord parent)` | Current non-removed rows in saved order, ties broken by insertion order |
| `move(BeakDraftRecord parent, BeakDraftRecord row, int offset)` | Moves a picture locally and rewrites every `position`; ignored while submitting, unresolved, or when editing is not allowed |
| `add(BeakDraftRecord parent)` | Adds an empty slot after the last picture |

`BeakGalleryView` renders a gallery as cards; it is the widget the configured form mounts. Uploading, the picker and storage rules are covered in [Uploads and galleries](../forms/uploads-and-galleries.md).

## Types the builders share

### BeakInput

Every scalar builder builds a `BeakInput`. Construct it directly only for a combination no builder offers.

```dart title="packages/beak_frontend/lib/src/form/beak_form_layout.dart"
const BeakInput({
  required this.field,
  this.label,
  this.labelBuilder,
  this.dependencies = const [],
  this.description,
  this.validate = const [],
  this.validators = const [],
  super.enabledIf,
  this.submitWhenHidden = false,
  this.readOnly = false,
  this.derive,
  this.obscureText = false,
  this.currency = false,
  this.minorUnits = false,
  this.currencyScale = 2,
  this.presentation = BeakInputPresentation.automatic,
  this.choices,
  this.choiceMinWidthInPixels,
  this.choiceCardPadding,
  this.groupLabelAsField = false,
  this.allowCustom = false,
  this.maxLines,
  this.placeholder,
  this.showCounter,
  this.controlHeightInPixels,
  this.multilineContentPadding,
  this.controlWidthInPixels,
  this.dateShortcuts,
  this.attributeType,
  this.attributeDefinition,
  this.attributeVersion,
  super.visibleIf,
}) : assert(currencyScale >= 0 && currencyScale <= 12),
     assert(maxLines == null || maxLines > 0);
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `field` | `BeakScalarField<T>` | required | The generated field; must belong to the form's model |
| `label`, `description`, `validate`, `validators`, `readOnly`, `submitWhenHidden`, `derive`, `visibleIf`, `enabledIf` | | | See the shared parameters |
| `labelBuilder` | `String Function(BeakFormReader state)?` | none | Contextual label |
| `dependencies` | `List<BeakFieldRef<Object>>` | `const []` | Fields read by dynamic presentation, loaded and permission checked |
| `obscureText` | `bool` | `false` | Conceals the characters |
| `currency` | `bool` | `false` | Localized monetary editor and display |
| `minorUnits` | `bool` | `false` | Currency editor stores integer minor units |
| `currencyScale` | `int` | `2` | Decimal places of the minor units. Must be 0 to 12 |
| `presentation` | `BeakInputPresentation` | `automatic` | Control override; the value type is unchanged |
| `choices` | `BeakInputChoices?` | none | Choices recomputed from the live draft |
| `choiceMinWidthInPixels` | `double?` | none | Minimum radio card width |
| `choiceCardPadding` | `EdgeInsetsGeometry?` | none | Padding of description-bearing cards |
| `groupLabelAsField` | `bool` | `false` | Ordinary input label for a radio group |
| `allowCustom` | `bool` | `false` | Whether a tag editor accepts values outside its suggestions |
| `maxLines` | `int?` | none | Visible line count. Must be above 0 |
| `placeholder` | `String?` | none | Hint text |
| `showCounter` | `bool?` | none | Multi-line character counter |
| `controlHeightInPixels` | `double?` | none | Minimum editor height |
| `multilineContentPadding` | `EdgeInsetsGeometry?` | none | Multi-line editor padding |
| `controlWidthInPixels` | `double?` | none | Width of a bounded quantity control |
| `dateShortcuts` | `List<BeakInputOption<BeakDate>> Function(BeakFormReader)?` | none | Suggested calendar dates |
| `attributeType` | `BeakAttributeType Function(BeakFormReader state)?` | none | Dynamic interpretation of a string attribute |
| `attributeDefinition` | `BeakAttributeDefinition? Function(BeakFormReader state)?` | none | Shared attribute definition |
| `attributeVersion` | `int? Function(BeakFormReader state)?` | none | Revision stored with the attribute value |

Builders forward the parameters they declare and leave the rest at their defaults; the constructor is the only place the full set exists.

### BeakInputPresentation

| Value | Control | Set by |
| --- | --- | --- |
| `automatic` | Editor from the column's kind and semantic | `input`, `inputText`, `inputNumber`, `inputDateTime`, `inputDate`, `inputAttribute` |
| `checkbox` | Single checkbox | `inputCheckbox` |
| `quantity` | Compact integer stepper | `inputQuantity` |
| `select` | Searchable single choice | `inputSelect` |
| `radio` | Radio group | `inputRadio` |
| `radioCards` | Bordered radio choices with icon and description | `inputRadio(cards: true)` |
| `multiSelect` | Searchable multiple choice | `inputMultiSelect` |
| `checkboxGroup` | Visible checkboxes for a typed primitive list | `inputCheckboxGroup` |
| `tags` | Removable tags, with optional suggestions | `inputTags` |
| `json` | Raw JSON document editor | `inputJson` |

### BeakInputOption

One typed choice.

```dart title="packages/beak_frontend/lib/src/form/beak_input_presentation.dart"
const BeakInputOption(
  this.value,
  this.label, {
  this.enabled = true,
  this.description,
  this.icon,
});
```

| Member | Type | Default | Meaning |
| --- | --- | --- | --- |
| `value` | `T` | required, positional | Value stored by this option |
| `label` | `String` | required, positional | Option label |
| `enabled` | `bool` | `true` | Whether the option can be selected now |
| `description` | `String?` | none | Explanation for richer presentations |
| `icon` | `IconData?` | none | Decorative icon for a choice card |

### Display formats

A field can carry a display-only format. Queries, sorting, filters and persistence keep the original value type; no formatted string reaches the API.

```dart title="packages/beak_frontend/lib/src/formatting/beak_field_format.dart"
BeakFormattedField<T> currency({
  bool minorUnits = false,
  int scale = 2,
  String? label,
}) => BeakFormattedField<T>(
  // ...
);
```

```dart title="packages/beak_frontend/lib/src/formatting/beak_field_format.dart"
BeakFormattedField<T> formatted(BeakValueFormat format, {String? label}) =>
    BeakFormattedField<T>(field: this, format: format, label: label);
```

`BeakValueFormat` values: `text`, `number`, `currency`, `date`, `dateTime`, `time`, `percent`. `currency()` is defined on numeric fields and sets `minorUnits` and `scale` for tables, read forms and the `input()` that follows.

## Automatic editors

With `presentation: automatic`, the editor comes from the column kind, and from the semantic when the column carries one.

| Column or semantic | Editor |
| --- | --- |
| `BeakStringColumn` | Single-line text; `placeholder` and `maxLength` from the column |
| `BeakTextColumn`, `BeakJsonColumn` | Multi-line text |
| `BeakIntColumn` | Number input without decimals, `min` and `max` from the column |
| `BeakDecimalColumn` | Number input with `precision` decimals |
| `BeakBoolColumn` | Switch; a tri-state column shows `Not set`, `Yes`, `No` |
| `BeakEnumColumn` | Select over the enum values, labelled by `labelFor` |
| `BeakDateTimeColumn` | Date-time input |
| `BeakColorColumn` | Color picker |
| `BeakRichTextColumn` | Rich-text editor |
| `BeakImageColumn`, `BeakFileColumn` | Upload field using the panel's file picker and uploader |
| `BeakCustomColumn` | No input; the column is skipped in generated forms |
| Semantic `calendarDate` | Date input; `shortcuts` add buttons |
| Semantic `password` | Password input |
| Semantic `time`, `duration`, `exactDecimal`, `money`, `percentage` | Text input that parses through the semantic; money shows its currency, percentage shows `%` |
| Semantic `email`, `url`, `phone` | Text input with the matching keyboard type |
| Semantic `primitiveList` | Tags for strings, otherwise a reorderable array editor |
| Semantic `object` | The declared child columns as grouped inputs |

`BeakFormLayout.fromModel` uses exactly this table: one `input()` per form-visible column, a `BeakRelationInput` for each belongs-to whose target is registered, and nothing for the primary key or custom columns.

## Rules and limits

| Rule | Behavior |
| --- | --- |
| Where rules run | Column rules from the schema run in the form and again on the server. `validate:` and `validators:` on a builder run in the form only; put a rule on the schema or in `validationRules` when the API must enforce it |
| Order of form errors | Column type and rules, then `validate` (skipped for a null value unless the rule is `BeakRequired`), then attribute checks, then the choice check, then `validators` |
| Choice check | With `options` and without `allowCustom`, a value outside the enabled options fails with `Choose an available option.` This is a form check; add `BeakInList` to the column when the server must agree |
| Hidden inputs | A `visibleIf` that returns false skips validation and leaves the value out of the submitted record, unless `submitWhenHidden` is true |
| Locked fields | A field the account cannot write, or that model behavior controls (derived, snapshot, `editableWhen` false, action-owned), is disabled and left out of the submitted record |
| `derive` | The input is disabled and takes the computed value. A cycle between derived inputs throws `Cyclic derived field` as a `BeakConfigurationException` |
| Relation options | The `options` query must target the related table, and `searchSources` must be rooted at the related model; both throw a `BeakConfigurationException` otherwise |
| `inputCode` | `codeField` is required and must be a string field of the related model with no path; otherwise a `BeakConfigurationException` |
| Required relations | A non-nullable relationship, or a `BeakRequired` in `validate`, makes the input required and not clearable. The backing foreign key's column rules apply too |
| Owned removal | `deleteOwned` requires an owned has-many; removing a row otherwise throws a `BeakConfigurationException` |
| Collection switches | `allowAdding`, `allowEdit` and `allowRemove` set to false make the operation throw if code still attempts it |
| Catalog | The `checkboxes` presentation needs a finite `maxOptions`, no `quantity` and no `groupBy`; `pageSize` needs `maxOptions`. These are asserts, so they fail in debug builds |
| Catalog | `selection` must belong to the row model, the query must target the model `selection` points at, and a `matches` facet needs `maxOptions`; otherwise a `BeakConfigurationException` when the catalog is queried |
| Gallery | Construction throws a `BeakConfigurationException` unless the relationship is an owned has-many, the three fields belong to the child model, and `image` is a `BeakImageColumn` |
| Ranges | `inputRange` compares dates, times, durations and numbers; anything else throws when validated |

## Source

- `packages/beak_frontend/lib/src/form/beak_form_layout.dart`: `BeakInput`, `BeakRelationInput`, `BeakRelationTable`, the catalog types, and the scalar, relationship and collection builder extensions.
- `packages/beak_frontend/lib/src/form/beak_input_presentation.dart`: `BeakInputPresentation`, `BeakInputOption`, and the choice, list, tag, attribute, range, date, exact-decimal, time, duration and JSON builders.
- `packages/beak_frontend/lib/src/form/beak_gallery.dart`: `BeakGallery`, `galleryForm`, `BeakGalleryView`.
- `packages/beak_frontend/lib/src/formatting/beak_field_format.dart`: `BeakFormattedField`, `currency()`, `formatted()`.
- `packages/beak_frontend/lib/src/form/beak_value_input.dart` and `packages/beak_frontend/lib/src/form/field_widget_mapper.dart`: the automatic editor mapping.
- `packages/beak_frontend/lib/src/form/beak_form_session.dart`: `BeakFormReader`, `BeakDraftRecord`, and the validation and submission rules above.

## Continue reading

- [Screens and form layouts](screens-and-layouts.md) the containers, presentation nodes and screens these inputs are placed in.
- [Inputs](../forms/inputs.md) choosing an input for each field type, with worked examples.
- [Related records in forms](../forms/related-records.md) how comboboxes, table editors and catalogs stage changes.
- [Filter builders](filter-builders.md) the list-side counterpart of these builders.
