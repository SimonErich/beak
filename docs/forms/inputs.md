---
title: Inputs
description: Pick the input for a field, from text, numbers, money and dates to choices, tags and objects, with the shop's fulfillment form as the worked example.
type: guide
audience: [beginner]
status: stable
---

# Inputs

After this page you can look at a field, decide which input it needs, and write the one line that places it. Most of the time the answer is `input()`, and the column already knows what to do.

An input is a method on a generated field: `FulfillmentPolicyModel.name.input()`. The field carries the Dart type, so a builder that does not fit the type does not compile. `inputText` on an `int` field is a red squiggle, not a runtime surprise.

## At a glance

| The field is | Write | You get |
| --- | --- | --- |
| Any field | `input()` | The editor the column and its semantic imply |
| `String` | `inputText()` | One line, or several with `maxLines` |
| `int` or `double` | `inputNumber()` | A number input that uses the column's bounds |
| `int` count | `inputQuantity()` | A compact stepper |
| Money as `BeakDecimal` | `input()` or `inputCurrency()` | An exact money editor |
| Money as `int` cents | `inputCurrency(minorUnits: true)` | A currency editor over integer minor units |
| `BeakDate` | `inputDate()` | A calendar date, with optional shortcuts, no time zone |
| `DateTime` | `inputDateTime()` | An instant, shown in the panel's time zone |
| `BeakTime`, `Duration` | `inputTime()`, `inputDuration()` | Time of day, and `hours:minutes:seconds` |
| Two related dates or numbers | `inputDateRange(end:)`, `inputRange(end:)` | A From and To pair with ordering checked |
| `bool` | `inputToggle()` or `inputCheckbox()` | A switch or a checkbox |
| `bool?` | `input()` | Radios: Not set, Yes, No |
| Enum | `inputRadio()` or `inputSelect()` | The enum's values, with their labels |
| A value picked from a list you compute | `inputRadio(options:)`, `inputSelect(options:)` | Choices that can follow other fields |
| `List` of strings, numbers or booleans | `inputTags()`, `inputCheckboxGroup(options:)`, `inputMultiSelect(options:)` | Tags, visible checkboxes or a searchable list |
| A typed object or JSON | `input()`, `inputJson()` | Grouped inputs for an object, a raw editor for JSON |
| A string whose type is decided at runtime | `inputAttribute(...)` | An editor chosen from a live attribute definition |

Related records have their own builders (`inputCombobox`, `inputSearch`, `inputCards`, `inputCode`, `tableForm`). They live in [Related records in forms](related-records.md). Every parameter of every builder is in [Input builders](../reference/input-builders.md).

## Let the column decide

Nothing in the shop's fulfillment form says "money" or "percent". The columns do, and `input()` reads them. Here are the fields:

```dart title="examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart"
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart:FulfillmentMoney"
```

```dart title="examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart"
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart:FulfillmentNumbers"
```

```dart title="examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart"
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart:FulfillmentTimes"
```

And the tab that places them:

```dart title="examples/clean_beak_config/lib/resources/fulfillment/screens/fulfillment_policy_form.dart"
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/screens/fulfillment_policy_form.dart:fulfillmentPricingColumns"
```

What each `input()` does here:

- `deliveryFee` is a `BeakDecimal` with the money semantic. The editor shows the currency code of the `currency` field on the same record (`EUR`) as a suffix, because the column says `currencyFrom: #currency`. Change the select above it and the suffix follows. Typing more decimals than the scale allows is an error, not a rounding.
- `insuranceRate` stores a fraction (`0.025`) and edits as a percentage (`2.5`, with a `%` suffix). `maximumWeight` carries the unit `kg` the same way.
- `effectiveDate` is a `BeakDate`: a calendar day that never passes through a time zone. `promotionStartsAt` is a `DateTime`: an instant, which the editor shows in the panel's configured zone and stores as UTC.
- `dispatchCutoff` is a `BeakTime` and `handlingTime` a `Duration`. The duration editor takes `hours:minutes:seconds`, so `24:00:00` is a day.

The full mapping from column kind to editor is the [automatic editors table](../reference/input-builders.md#automatic-editors).

## Text, numbers and quantities

`inputText` is the builder with the most knobs, and the only one you will reach for with a multi-line field. `maxLines` sets the visible lines and does not change storage. `controlHeightInPixels` sets a minimum editor height, label and hint excluded:

```dart title="examples/foodio-adminpanel/lib/resources/orders/forms/steps/order_delivery_step.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/forms/steps/order_delivery_step.dart:deliveryNoteInput"
```

Quantities and money have their own builders because the plain number input is the wrong tool for a stepper or a currency:

```dart title="examples/foodio-adminpanel/lib/resources/orders/forms/order_items_table.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/forms/order_items_table.dart:orderQuantityInput"
```

```dart title="examples/foodio-adminpanel/lib/resources/orders/forms/steps/order_payment_step.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/forms/steps/order_payment_step.dart:manualDiscountInput"
```

Foodio stores money as integer cents, so the second field says `minorUnits: true`. The draft value stays an `int`, and the editor shows and parses euros. The shop stores exact `BeakDecimal` values and needs no flag, see [A money field](../recipes/a-money-field.md).

## Dates with shortcuts

`inputDate(shortcuts: ...)` puts suggested days beside the calendar. Shortcuts are `BeakInputOption<BeakDate>` values, so each has a label and can be disabled. They suggest, they do not restrict: any other day stays selectable unless a rule rejects it.

```dart title="examples/foodio-adminpanel/lib/resources/orders/forms/steps/order_delivery_step.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/forms/steps/order_delivery_step.dart:deliveryDateInput"
```

Today's shortcut is disabled once the kitchen has closed changes for the day, and a disabled shortcut cannot be selected. Up to four shortcuts appear as presets inside the date picker, exactly five as a segmented control beside it, and more as toggle buttons. The callback receives the tracked draft reader, so shortcuts can follow other fields.

## Choices

`inputRadio` lists a fixed or computed set of values and `inputSelect` searches it. `inputCheckboxGroup` and `inputMultiSelect` do the same for a list field. Without `options`, an enum offers its own values with their labels. The fulfillment form uses all of that:

```dart title="examples/clean_beak_config/lib/resources/fulfillment/screens/fulfillment_policy_form.dart"
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/screens/fulfillment_policy_form.dart:fulfillmentIdentityCard"
```

```dart title="examples/clean_beak_config/lib/resources/fulfillment/screens/fulfillment_policy_form.dart"
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/screens/fulfillment_policy_form.dart:fulfillmentCoverageCard"
```

`speed` is an enum, so `inputRadio()` needs nothing. `tags` is a `List<String>`, and a list of strings renders as tags even without a builder call. `regions` gets a checkbox group over an explicit list. `signatureRequired` is a `bool?`, so plain `input()` draws Not set, Yes and No, and "not set" is a real answer here: the description says it falls back to the carrier default.

Options are `BeakInputOption(value, label)` with `enabled`, `description` and `icon` when you need them. The `options` callback runs against the live draft, which is how a choice follows another field. Foodio's payment step offers the selected profile's own payment mode next to card and payment link, and dresses each choice as a card:

```dart title="examples/foodio-adminpanel/lib/resources/orders/forms/steps/order_payment_step.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/forms/steps/order_payment_step.dart:paymentModeCards"
```

`cards: true` turns `inputRadio` into bordered cards that show the description and icon. Relationship choices have the same treatment under `inputCards`.

## Yes and no

`inputToggle` and `inputCheckbox` bind the same boolean and differ in the control. A checkbox can name its context, and Foodio's says who will get the confirmation mail. The second node in the snippet is not an input: it is a locked checkbox that shows a rule the system applies.

```dart title="examples/foodio-adminpanel/lib/resources/orders/forms/steps/order_payment_step.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/forms/steps/order_payment_step.dart:confirmationCheckboxes"
```

`labelBuilder` reads the draft, and `dependencies` lists the related fields it reads so the form loads them and checks read access before it renders. `BeakCalculated` with the `checkbox` presentation shows a requirement the user cannot change, and it is never submitted.

## Objects and JSON

A column with the object semantic edits as a group of inputs, one per declared child column, and validates each with that child's rules. A plain JSON column edits as text.

```dart title="examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart"
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart:FulfillmentStructures"
```

```dart title="examples/clean_beak_config/lib/resources/fulfillment/screens/fulfillment_policy_form.dart"
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/screens/fulfillment_policy_form.dart:fulfillmentOriginColumns"
```

`origin` is a `DispatchAddress`: four declared columns, no table of their own. `providerOptions` is free-form JSON. `inputJson()` makes the raw editor explicit and keeps a syntax error visible until it is fixed. A field that holds an attribute chosen at runtime uses `inputAttribute`, covered in [Dynamic attributes and variants](../models/dynamic-attributes-and-variants.md).

## When no builder fits

Builders forward the parameters that make sense for their control. When you need a combination none of them offers, construct `BeakInput` yourself. Foodio's cost-centre select needs `dependencies` next to an `options` list, which `inputSelect` does not take:

```dart title="examples/foodio-adminpanel/lib/resources/orders/forms/steps/order_payment_step.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/forms/steps/order_payment_step.dart:costCentreSelect"
```

## The parameters every input shares

| Parameter | Meaning |
| --- | --- |
| `label`, `description` | Override the model's label and add guidance under the input |
| `validate` | Extra `BeakRule`s, run in the form only |
| `validators` | Draft-aware functions that return an error message or null, sync or async, form only |
| `visibleIf`, `enabledIf` | Predicates over the live draft |
| `readOnly` | Disables editing for this placement |
| `derive` | Computes the value from other fields and disables the input |
| `submitWhenHidden` | Keeps a hidden input's value in the submitted record |

## Rules and limits

| Rule | Behavior |
| --- | --- |
| Type-checked builders | A builder exists only on fields of a matching Dart type. The wrong one does not compile |
| Two layers of rules | Column rules run in the form and on the server. `validate:` and `validators:` run in the form only |
| Options are a form check | A value outside the enabled `options` fails with `Choose an available option.` in the form only. Add `BeakInList` to the column when the API must agree, as the fulfillment model does for `currency` |
| Hidden inputs | A `visibleIf` that returns false skips validation and leaves the value out of the submitted record |
| Derived inputs | A `derive:` input is disabled. A cycle between derived inputs throws `Cyclic derived field` |
| Shortcuts suggest | `inputDate` shortcuts never restrict the date. Restrict with a rule |
| Money precision | A money editor rejects more decimal places than the column's scale instead of rounding |
| Tri-state booleans | A `bool?` field always shows Not set, Yes and No, whichever builder you call |
| Custom columns | A `@Custom` column has no input. It is skipped in generated forms |

## Verify it

The shop's fulfillment form and the input tests exercise every builder on this page:

```bash
cd examples/clean_beak_config
flutter test test/fulfillment_form_test.dart
```

```bash
cd packages/beak_frontend
flutter test test/src/form/semantic_inputs_test.dart
```

Both end with `All tests passed!`. To look at the inputs, run the shop and open Fulfillment policies, then create one. Switch between the three tabs.

## Reference

| Symbol | Where it is documented |
| --- | --- |
| Every `input*` builder and its parameters | [Input builders](../reference/input-builders.md) |
| `BeakInput`, `BeakInputPresentation`, `BeakInputOption` | [Input builders](../reference/input-builders.md#types-the-builders-share) |
| Field types and semantics | [Field types](../reference/field-types.md), [Semantic fields](../models/semantic-fields.md) |
| Display formats: `currency()`, `formatted()` | [Input builders](../reference/input-builders.md#display-formats) |

## Continue reading

- [Related records in forms](related-records.md) pickers, table editors and catalogs.
- [Form screens](form-screens.md) where these placements live and how the layout around them works.
- [Semantic fields](../models/semantic-fields.md) the column side of money, dates, objects and lists.
- [Validation](../models/validation.md) the rules that run on both sides of the wire.
