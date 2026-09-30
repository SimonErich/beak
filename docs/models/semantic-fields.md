---
title: Semantic fields
description: Give a field a meaning beyond its column, such as email, exact money, percentages, dates, lists or an embedded object, and see what each stores and shows.
type: guide
audience: [expert]
status: stable
---

# Semantic fields

A Dart type picks the physical column. A semantic says what the value means, and with it how to type it, check it, store it and show it. After this page you can choose the right meaning for email, money, percentages, calendar values, lists and embedded objects, and you know what each one puts in the database.

You write the meaning once, on the schema field. The generated reference keeps the domain type (`BeakDecimal`, `BeakDate`, `List<String>`), a codec translates it to a portable database and wire value, and `.input()` picks the control. Changing a label or moving an input into a tab never changes how the value is stored.

## At a glance

The shop's `FulfillmentPolicy` uses most of them. This is its money and number fields:

```dart
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart:FulfillmentMoney"
```

```dart
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart:FulfillmentNumbers"
```

And this is all its form says about them. There is no per-type input, because `.input()` reads the column:

```dart
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/screens/fulfillment_policy_form.dart:fulfillmentPricingColumns"
```

The meanings, what they store and what the reader sees:

| Definition | Dart type | Stored as | Shown as |
| --- | --- | --- | --- |
| `BeakSemantic.email()` | `String` | Text | As typed. Checked as an email address |
| `BeakSemantic.url()` | `String` | Text | As typed. Must be an absolute HTTP or HTTPS URL |
| `BeakSemantic.phone()` | `String` | Text | As typed. Conservative syntax check |
| `BeakSemantic.slug()` | `String` | Text | Lowercase letters, numbers and single hyphens |
| `BeakSemantic.uuid()` | `String` | Text | Canonical hyphenated form |
| `BeakSemantic.password()` | `String` | Text | Obscured input, form-only by default. Never returned by the server |
| `BeakDate` | `BeakDate` | `YYYY-MM-DD` text | Date pattern, no timezone shift |
| `BeakTime` | `BeakTime` | `HH:mm:ss` text | Time pattern, no date, no timezone |
| `Duration` | `Duration` | Integer microseconds | `hh:mm:ss`, may pass 24 hours |
| `BeakDecimal` | `BeakDecimal` | Integer units at the scale | Localized number at its own scale |
| `BeakSemantic.exactDecimal(scale: n)` | `BeakDecimal` | Integer units | Same, with the scale you choose |
| `BeakSemantic.money(...)` | `BeakDecimal` | Integer units | Amount with its currency |
| `BeakSemantic.percentage(scale: n)` | `double` | As the column | Percent, `n` being the stored value for 100% |
| `BeakSemantic.quantity(unit: 'kg')` | `int` or `double` | As the column | Number plus the unit |
| `BeakSemantic.fileSize()` | `int` | Integer bytes | Binary units (KiB, MiB) |
| `List<String>`, `List<int>`, `List<double>`, `List<bool>` | Typed list | JSON text | Items joined with commas |
| `BeakSemantic.object(schema)` on `BeakJsonObject` | `BeakJsonObject` | JSON text | Recursive child editors |

`BeakDate`, `BeakTime`, `Duration`, `BeakDecimal`, lists and `BeakJsonObject` carry their semantic without an annotation: the type implies it. The rest go into `@Column(semantic: ...)`, and `beak prepare` rejects a semantic on a Dart type it does not accept, naming the field.

## Text with a meaning

Email, URL, phone, slug and UUID are strings that get a syntax check on the client and on the server, and a text keyboard or preset in the input. These are the server messages, from one request that got each of them wrong:

```json
{"code":"validation","message":"Validation failed for \"fulfillment_policies\".","fieldErrors":{"code":["Use lowercase letters, numbers and single hyphens."],"support_email":["Must be a valid email address."],"support_phone":["Must be a valid phone number."],"tracking_url":["Must be a valid URL."], ...}}
```

`password()` obscures the input and is visible on the form only unless you say otherwise. It cannot be `@Display` or `searchable`.

The stored value never leaves the server. Single reads, queries, batch reads, relations included in a response and the response to a create or an update all omit the field, whatever the policy says. A filter, sort or aggregate over it is a `422` (a search over it is refused too), because a `startsWith` filter would reveal a hash one character at a time. The CSV export writes `••••••••` where a value exists and never the value. Capabilities still list the field as readable and writable, so a form keeps the input.

It does not hash anything: Beak stores the text as sent. Hash it before it is stored, in a save-plan preparer (`preparePlan`) or in an action, or let your authentication code write the column. A password field keeps a secret off the screen and out of the API, not safe at rest.

## Exact amounts and percentages

`BeakDecimal(12345, scale: 2)` means 123.45. The value is an integer count of units, and every operation works on integers: `+` and `-` keep the greater scale, `*` takes an `int` quantity, and comparison ignores scale, so 1.5 equals 1.50. The coefficient is limited to 9007199254740991, the largest integer JavaScript, JSON and SQL all hold exactly. A value beyond that, or one with more decimals than its scale, is a `FormatException` and a validation error.

That leaves out multiplying two decimals, and that is deliberate: it forces you to decide how to round. The shop decides half-up, to a whole cent, with integer arithmetic:

```dart title="examples/clean_beak_config/lib/domain/shop_totals.dart"
/// [percent] of [amount], rounded half-up to a whole cent.
static BeakDecimal percentOf(BeakDecimal amount, BeakDecimal percent) =>
    BeakDecimal(
      roundRatio(
        _atScale(amount).units,
        _atScale(percent).units,
        _hundred.units,
      ),
    );
```

Money adds a currency. `money(currency: 'EUR')` fixes it for the whole column, which is what the invoice does. `money(scale: 2)` together with `currencyFrom: #currency` reads it from a `String` field of the same record, so a euro policy and a dollar policy live in one table. `currencyFrom` is a `Symbol` that `beak prepare` resolves to the typed column, and a misspelled name is an error instead of a currency that never resolves.

Display and storage scale are independent. An exact amount is shown at its own scale, so changing the panel locale changes the separators and the symbol, and never a stored unit.

Percentages come in three shapes, and the field says which:

| You store | Declare | 2.5% is stored as |
| --- | --- | --- |
| A ratio | `double` with `percentage(scale: 1)` | `0.025` |
| Percentage points | `double` with `percentage(scale: 100)` | `2.5` |
| An exact rate | `BeakDecimal` with `exactDecimal(scale: 2)` and `suffix: '%'` | `250` at scale 2 |

The scale is the stored value that means 100%. The editor always shows percent, so an administrator types `2.5` in all three, and the codec converts. For the ratio shape, `beak prepare` adds `precision: 4` so the column keeps `0.025`, unless you pass a precision yourself. The shop's tax rate uses the third shape, which is the one to pick when the rate goes into a calculation (the shop's `ratePercent` feeds `percentOf` above).

## Dates, times and durations

Three types and an instant, each with one job:

| Type | Means | Never does |
| --- | --- | --- |
| `DateTime` | An instant | Ignore the timezone: it is shown in the panel's display timezone |
| `BeakDate` | A calendar day (a birthday, a due date) | Convert through a timezone |
| `BeakTime` | A time of day (a cutoff) | Carry a date or a zone |
| `Duration` | Elapsed time | Wrap at 24 hours |

```dart
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart:FulfillmentTimes"
```

A `BeakTime` does not know where it is 14:30. The warehouse cutoff above needs a location that the application defines, and Beak does not guess one. A `DateTime` is shown according to the panel's formatting policy (device time by default, or a fixed offset), see [Formatting and localization](../theming/formatting-and-localization.md). The policy keeps `datePattern` (display) and `dateInputPattern` (calendar controls and range endpoints) apart, so a table can show `Tue 29 Sep` while the calendar input asks for the year. The input pattern defaults to the display one, and the values stay typed dates either way.

The editors parse strictly. `2026-02-30` is not a date, `25:00` is not a time, and a duration is written `hours:minutes:seconds`, for example `2:30:00`. Text that does not parse stays an error on the field and blocks the save. It is never replaced by a guess.

A range is two fields and one rule. The fulfillment policy declares `BeakAfterField(promotionEndsAt, promotionStartsAt, inclusive: true)`, and `inputRange` and `inputDateRange` place both editors side by side, see [Validation](validation.md).

## Choices, lists and objects

Enums supply their own choices. `inputSelect()` and `inputRadio()` change the control, and `options:` can read the live draft (`(state) => ...`) when the choices depend on other fields. Primitive lists support `inputTags()`, `inputMultiSelect()` and `inputCheckboxGroup()`:

```dart
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/screens/fulfillment_policy_form.dart:fulfillmentCoverageCard"
```

A list is stored as JSON text and read back as an immutable typed list. Its bounds live in the semantic: `BeakSemantic.list(BeakPrimitiveType.string, minItems: 1, maxItems: 5, distinctItems: true, itemRules: [...])`. A `bool?` is a three-state field (true, false, unset), which the form draws as such; `signatureRequired` above uses it to mean "ask the carrier".

An embedded object declares its properties with ordinary columns and reuses the schema:

```dart
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart:DispatchAddress"
```

```dart
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart:FulfillmentStructures"
```

The editor renders the child fields recursively, and the child rules run in the form and in the API. Unknown properties are rejected unless the schema says `allowUnknown: true`, which is also what a bare `BeakJsonObject` field with no schema gets. Free-form data that no schema describes is a `BeakJson` field (`providerOptions` above): the editor takes JSON text and reports `Must be valid JSON.` when it does not parse.

## Rules and limits

- The semantic must fit the type. `email()` on an `int`, or `money()` on a `double`, is an error from `beak prepare` naming the field.
- Money is never a `double`. A `double` with a `€` prefix is still a floating-point number. Use `BeakDecimal` with `money` for anything that has to add up.
- The wire carries the stored form. Over the REST route a money amount is integer units (`490`, not `"4.90"`), a duration is microseconds, and a list or an object is JSON text. The panel does the conversion for you, a script has to do it itself.
- Defaults apply to omissions. A default fills a value that is left out of a create, and the form starts on it. An explicit `null` stays `null`, and a required field then fails.
- Display never converts storage. Formatting changes what is shown and typed. It does not touch the stored value, the query value or the export of raw units.
- Scale is 0 to 12. `BeakSemantic` asserts it.
- `placement validate:` is not a server rule. A `validate:` or `validators:` callback on a screen runs in the form only. Put constraints that every caller must obey on the field or in `validationRules`.
- `percentage` and `quantity` do not change the column. They are labels on a number, so `BeakMin` and `BeakMax` still do the bounding.

## Verify it

Send a record with a wrong value in each field and read the messages back. This is real output from the shop's server for a create with a bad email, phone, URL, calendar date, time, duration and list:

```json
{"code":"validation","message":"Validation failed for \"fulfillment_policies\".","fieldErrors":{"code":["Use lowercase letters, numbers and single hyphens."],"support_email":["Must be a valid email address."],"support_phone":["Must be a valid phone number."],"tracking_url":["Must be a valid URL."],"currency":["Must be one of: EUR, USD, GBP."],"delivery_fee":["Invalid money value."],"insurance_rate":["Must be at most 1."],"attachment_limit":["Must be at least 0.","Must be a nonnegative number of bytes."],"effective_date":["Expected a valid calendar date (YYYY-MM-DD)."],"dispatch_cutoff":["Expected a valid time (HH:mm[:ss[.ffffff]])."],"handling_time":["Invalid duration value."],"tags":["Invalid primitiveList value."]}}
```

And a valid one, to see what is stored. The response keeps the stored form: money in units, the date and time as text, the duration in microseconds, the list and the object as JSON text:

```json
{"values":{"id":"683fb11f-3e09-41e2-be58-63f9571bea05","name":"Standard Europe","code":"standard-europe","support_email":"help@example.com","currency":"EUR","delivery_fee":490,"insurance_rate":0.025,"maximum_weight":12.5,"attachment_limit":10485760,"effective_date":"2026-10-01","dispatch_cutoff":"14:30:00","handling_time":86400000000,"tags":"[\"fragile\",\"eu\"]","regions":"[\"AT\",\"DE\"]","signature_required":null,"speed":"standard","origin":"{\"street\":\"Hauptstr. 1\",\"postal_code\":\"1010\",\"city\":\"Wien\",\"email\":\"dock@example.com\"}","provider_options":null},"relations":{}}
```

The record rules, shared by the form and this request:

```dart
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart:FulfillmentRules"
```

## Reference

| Symbol | Where | Purpose |
| --- | --- | --- |
| `BeakSemantic`, `BeakSemanticKind` | `beak_core` | The meaning and its codec |
| `BeakDecimal`, `BeakDate`, `BeakTime` | `beak_core` | Exact and calendar values |
| `BeakObjectSchema` | `beak_core` | The declared shape of an embedded object |
| `BeakPrimitiveType` | `beak_core` | The item type of a list |
| `BeakFormatPolicy` | `beak_core` | How each meaning is displayed |
| `inputCurrency`, `inputDate`, `inputTime`, `inputDuration`, `inputTags`, `inputJson` | `beak_frontend` | Placements for a specific control |

Every constructor, the parsing rules of `BeakDecimal` and the storage of each kind are in [Field types](../reference/field-types.md#semantic-kinds).

## Continue reading

- [Validation](validation.md) the rules a field or a record adds on top of its meaning.
- [Inputs](../forms/inputs.md) every input placement and its options.
- [Formatting and localization](../theming/formatting-and-localization.md) locale, currency and date patterns.
