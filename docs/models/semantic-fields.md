---
title: Semantic fields
description: Define a field's meaning once for typed generation, inputs, validation, storage, filtering and display.
type: guide
audience: [expert]
status: draft
---

# Semantic fields

A Dart type selects physical storage. `@Column(semantic: ...)` adds meaning:
email, exact money, units, structured values and more. Generated references retain
the domain type, while codecs translate it to portable database and wire values.
Use `.input()` to select the appropriate control automatically.

```dart
@Column(semantic: BeakSemantic.email())
late final String? supportEmail;

@Column(semantic: BeakSemantic.money(scale: 2), currencyFrom: #currency)
late final BeakDecimal deliveryFee;

@Column(defaultValue: 'EUR')
late final String currency;

late final BeakDate? effectiveDate;
late final BeakTime? dispatchCutoff;
late final Duration handlingTime;
late final List<String> tags;
late final bool? signatureRequired;
```

```dart
FulfillmentPolicyModel.deliveryFee.input(),
FulfillmentPolicyModel.effectiveDate.input(),
FulfillmentPolicyModel.tags.inputTags(),
FulfillmentPolicyModel.signatureRequired.input(),
```

The generated model drives validation and encoding. Changing a label or moving an
input into a tab never changes its storage behavior. Defaults apply to new drafts
and API creates; an existing explicit null is not replaced by a default.

## Supported meanings

| Definition | Domain value | Stored value / behavior |
| --- | --- | --- |
| `BeakSemantic.email()` | `String` | Email input and validation |
| `url()` | `String` | Absolute HTTP(S) URL |
| `phone()` | `String` | Telephone input and conservative syntax validation |
| `slug()` | `String` | Lowercase hyphen-separated identifier |
| `uuid()` | `String` | UUID syntax validation |
| `password()` | `String` | Obscured editor and masked output; authentication services own hashing |
| `BeakDate` | Calendar date | ISO date string, no timezone conversion |
| `BeakTime` | Time of day | ISO time string, no calendar date or timezone |
| `Duration` | Elapsed time | Integer microseconds |
| `BeakDecimal` / `exactDecimal(scale: ...)` | Exact fixed-scale number | Integer units |
| `money(scale: ..., currency: ...)` | `BeakDecimal` | Integer units plus explicit fixed or record currency |
| `percentage(scale: ...)` | `double` | Scale is the stored value representing 100% |
| `quantity(unit: 'kg')` | Numeric | Numeric storage with a display unit |
| `fileSize()` | `int` | Byte count |
| `List<String/int/double/bool>` | Typed immutable list | JSON with checked primitive items |
| `BeakJsonObject` with `object(schema)` | Typed JSON object | JSON with declared child properties |
| `bool?` | True / false / null | Three-state editor and nullable storage |

`DateTime` remains an instant. Configure the panel's display timezone policy
separately; use `BeakDate` for birthdays, due dates and other calendar-only values.
A time such as a warehouse dispatch cutoff needs an application-defined warehouse
location; a time-only value does not silently infer one.

## Exact amounts and percentages

`const BeakDecimal(12345, scale: 2)` means **123.45**. Arithmetic, comparison and
encoding operate on integer units. Values exceeding the exact portable integer
range or requiring unsupported fractional precision fail validation. Do not
convert exact values to doubles for financial arithmetic.

Currency display precision and storage scale are independent. Changing EUR to
JPY, changing the locale or overriding display precision never changes a stored
amount. `currencyFrom: #currency` resolves a schema member into a typed generated
column reference; misspelled members fail generation.

Percentage semantics are explicit:

```dart
// 0.2 means 20%.
@Column(semantic: BeakSemantic.percentage(scale: 1))
late final double fraction;

// 20 means 20%.
@Column(semantic: BeakSemantic.percentage(scale: 100))
late final double percentagePoints;
```

## Choices and structured values

Enums supply labels and values automatically. `inputSelect()` and `inputRadio()`
change the control. Primitive lists support `inputTags()`, `inputMultiSelect()` and
`inputCheckboxGroup()`. Options can read the live typed draft; unavailable current
selections remain visible and fail validation rather than disappearing.

```dart
FulfillmentPolicyModel.regions.inputCheckboxGroup(
  options: (_) => const [
    BeakInputOption('AT', 'Austria'),
    BeakInputOption('DE', 'Germany'),
  ],
)
```

Declare embedded object properties with ordinary columns, then reuse the schema:

```dart
abstract final class Address {
  static const city = BeakStringColumn(
    key: 'city', label: 'City', rules: [BeakRequired()],
  );
  static const schema = BeakObjectSchema(columns: [city]);
}

@Column(semantic: BeakSemantic.object(Address.schema))
late final BeakJsonObject? address;
```

The editor renders child fields recursively. JSON syntax errors remain associated
with the input and block submission; invalid editor text never replaces the last
valid structured value. Primitive repeaters and object editors share the same
model rules as top-level fields.

## Constraints and extension points

`min`, `max`, `maxLength`, numeric precision and semantic validity are enforced in
forms and API writes. Add scalar rules with `rules:` and shared record rules with
the schema's static `validationRules` getter. See [validation rules](validation.md).

Placement `validate:` and custom callbacks can add workflow-specific feedback.
They are not transmitted as executable server rules. Put authoritative constraints
in model metadata or shared model rules. Custom widgets, custom columns and custom
transports remain available for controls outside these conventions.

The complete example lives in
`examples/clean_beak_config/lib/resources/fulfillment/`. Its generated schema,
resource and form are separate files; no custom fetching or save controller is
needed.

## Continue reading

- [Validation rules](validation.md) for shared record and asynchronous checks.
- [Forms](../forms/form-screens.md) for declarative layouts and custom control choices.

### Date display and date entry

`BeakFormatting` (and portable `BeakFormatPolicy`) accepts `dateInputPattern`
separately from `datePattern`. It defaults to `datePattern` for existing panels.
For example, `datePattern: 'EEE d MMM', dateInputPattern: 'd MMM yyyy'` displays
compact dates in tables and summaries while calendar editors and filter endpoints
include the year. Calendar controls, including the date part of timestamp inputs,
use the same locale and input pattern. Selection retains typed `BeakDate` values
or timezone-aware timestamp conversion; it does not parse the displayed label or
change canonical API values. The portable policy preserves both patterns in JSON.
