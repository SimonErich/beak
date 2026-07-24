---
title: Validation rules reference
description: Every BeakRule subclass, its constructor arguments, exactly what it validates, and the message it emits.
---

# Validation rules reference

This page lists every validation rule Beak ships: its constructor, what it
checks, which values pass untouched, and the exact message it returns on
failure. Attach rules to a column's `rules` list; the same list drives both the
form field in `beak_frontend` and the request validator in `beak_backend`, so
client and server never disagree.

## How a rule works

`BeakRule` is `sealed`. Every rule exposes a stable `id` (for serialization
across the wire) and a single `validate` method that returns `null` when the
value is valid, or a human-readable message when it is not.

```dart title="packages/beak_core/lib/src/rules/beak_rule.dart"
@immutable
sealed class BeakRule {
  const BeakRule();

  /// Stable machine-readable identity for serialization to either side of
  /// the wire.
  String get id;

  /// Returns `null` when [value] is valid, else a human-readable message.
  String? validate(Object? value);
}
```

### Non-applicable types pass

Each rule pattern-matches the *runtime type* of the value it receives. A rule
that does not apply to the value's type reports it as valid. This is what lets
rules compose freely: presence stays `BeakRequired`'s job alone, and a length
rule on a numeric field never bites.

```dart title="packages/beak_core/lib/src/rules/beak_rule.dart"
const rule = BeakMaxLength(3);
rule.validate('abcd'); // 'Must be at most 3 characters.'
rule.validate(42);     // null (not a string)
```

Rules run in the order you list them, and the first non-null message wins:

```dart title="packages/beak_core/lib/src/rules/beak_rule.dart"
static const email = BeakStringColumn(
  key: 'email',
  label: 'Email',
  rules: [BeakRequired(), BeakEmail(), BeakMaxLength(255)],
);
```

## Overview

| Rule | Constructor | `id` | Validates | Message on failure |
|---|---|---|---|---|
| [`BeakRequired`](#beakrequired) | `BeakRequired()` | `required` | Value is present (non-null; non-empty for strings and collections). | `This field is required.` |
| [`BeakMin`](#beakmin) | `BeakMin(num min)` | `min` | Number is at least `min`. | `Must be at least $min.` |
| [`BeakMax`](#beakmax) | `BeakMax(num max)` | `max` | Number is at most `max`. | `Must be at most $max.` |
| [`BeakMinLength`](#beakminlength) | `BeakMinLength(int minLength)` | `min_length` | String has at least `minLength` characters. | `Must be at least $minLength characters.` |
| [`BeakMaxLength`](#beakmaxlength) | `BeakMaxLength(int maxLength)` | `max_length` | String has at most `maxLength` characters. | `Must be at most $maxLength characters.` |
| [`BeakPattern`](#beakpattern) | `BeakPattern(String regex, {String? message})` | `pattern` | String matches `regex`. | `message` or `Must match the expected format.` |
| [`BeakEmail`](#beakemail) | `BeakEmail()` | `email` | String looks like an email address. | `Must be a valid email address.` |
| [`BeakUrl`](#beakurl) | `BeakUrl()` | `url` | String is an absolute `http`/`https` URL with a host. | `Must be a valid URL.` |
| [`BeakInList<T>`](#beakinlistt) | `BeakInList<T>(List<T> allowed)` | `in_list` | Value is one of `allowed` (`null` passes). | `Must be one of: ...` |
| [`BeakAllowedFileTypes`](#beakallowedfiletypes) | `BeakAllowedFileTypes(List<BeakFileType> allowedTypes)` | `allowed_file_types` | Upload is one of `allowedTypes`. | `File type must be one of: ...` |
| [`BeakMaxFileSize`](#beakmaxfilesize) | `BeakMaxFileSize(int maxSizeInBytes)` | `max_file_size` | Upload size (bytes) is at most `maxSizeInBytes`. | `File must be at most $maxSizeInBytes bytes.` |

## Presence

### `BeakRequired`

Requires a value to be present: non-null and, for strings and collections,
non-empty. Whitespace-only strings count as empty. `false` and `0` are present
values and pass.

```dart title="packages/beak_core/lib/src/rules/beak_required.dart"
const BeakRequired();
```

`id`: `required`. Message: `This field is required.`

| Value | Result |
|---|---|
| `null` | fails |
| `''`, `'   '` (whitespace only) | fails |
| an empty `Iterable` | fails |
| `false`, `0`, `'a'`, a non-empty list | passes |

## Numeric bounds

### `BeakMin`

Requires a number to be at least `min` (inclusive). Non-numeric values pass.

```dart title="packages/beak_core/lib/src/rules/beak_min.dart"
const BeakMin(this.min);
```

| Argument | Type | Meaning |
|---|---|---|
| `min` | `num` | Lowest accepted value (inclusive). |

`id`: `min`. Message when a number is below the bound: `Must be at least $min.`
Pair it with a column's `min` (on `BeakIntColumn`/`BeakDecimalColumn`) so the
form stepper and the submit-time check agree.

### `BeakMax`

Requires a number to be at most `max` (inclusive). Non-numeric values pass.

```dart title="packages/beak_core/lib/src/rules/beak_max.dart"
const BeakMax(this.max);
```

| Argument | Type | Meaning |
|---|---|---|
| `max` | `num` | Highest accepted value (inclusive). |

`id`: `max`. Message when a number exceeds the bound: `Must be at most $max.`

## String length

### `BeakMinLength`

Requires a string to be at least `minLength` characters long. The empty string
fails like any other short string; add `BeakRequired` when presence should be
enforced too. Non-string values pass.

```dart title="packages/beak_core/lib/src/rules/beak_min_length.dart"
const BeakMinLength(this.minLength);
```

| Argument | Type | Meaning |
|---|---|---|
| `minLength` | `int` | Lowest accepted number of characters. |

`id`: `min_length`. Message: `Must be at least $minLength characters.`

### `BeakMaxLength`

Caps a string's length at `maxLength` characters. Non-string values pass.

```dart title="packages/beak_core/lib/src/rules/beak_max_length.dart"
const BeakMaxLength(this.maxLength);
```

| Argument | Type | Meaning |
|---|---|---|
| `maxLength` | `int` | Highest accepted number of characters. |

`id`: `max_length`. Message: `Must be at most $maxLength characters.`

## String format

### `BeakPattern`

Requires a string to match `regex`. The pattern is the source only and is
unanchored: add `^`/`$` yourself to match the whole value. Supply `message` for a
domain-specific error instead of the generic default. Non-string values pass.

```dart title="packages/beak_core/lib/src/rules/beak_pattern.dart"
const BeakPattern(this.regex, {this.message});
```

| Argument | Type | Default | Meaning |
|---|---|---|---|
| `regex` | `String` | required | Regular-expression source the value must match. |
| `message` | `String?` | `null` | Custom error message, if any. |

`id`: `pattern`. Message when the string does not match:
`message` when set, otherwise `Must match the expected format.`

```dart title="packages/beak_core/lib/src/rules/beak_pattern.dart"
static const slug = BeakStringColumn(
  key: 'slug',
  label: 'Slug',
  rules: [
    BeakPattern(
      r'^[a-z0-9-]+$',
      message: 'Use lowercase letters, digits and hyphens only.',
    ),
  ],
);
```

### `BeakEmail`

Requires a string to look like an email address (`local@domain.tld`, no
whitespace). Non-string values pass.

```dart title="packages/beak_core/lib/src/rules/beak_email.dart"
const BeakEmail();
```

`id`: `email`. Message: `Must be a valid email address.` The check is
`^[^@\s]+@[^@\s]+\.[^@\s]+$`.

### `BeakUrl`

Requires a string to be an absolute `http`/`https` URL with a host. Non-string
values pass.

```dart title="packages/beak_core/lib/src/rules/beak_url.dart"
const BeakUrl();
```

`id`: `url`. Message: `Must be a valid URL.` A value fails unless
`Uri.tryParse` yields a URI whose scheme is `http` or `https` and whose host is
non-empty.

## Membership

### `BeakInList<T>`

Requires a value to be one of `allowed`. `null` passes (leave presence to
`BeakRequired`); any non-null value outside `allowed` fails. The type parameter
`T` keeps the accepted set type-safe.

```dart title="packages/beak_core/lib/src/rules/beak_in_list.dart"
const BeakInList(this.allowed);
```

| Argument | Type | Meaning |
|---|---|---|
| `allowed` | `List<T>` | The accepted values. |

`id`: `in_list`. Message: `Must be one of: ` followed by the allowed values
joined with `, ` and a trailing `.`.

```dart title="packages/beak_core/lib/src/rules/beak_in_list.dart"
static const size = BeakStringColumn(
  key: 'size',
  label: 'Size',
  rules: [BeakInList<String>(['S', 'M', 'L'])],
);
```

!!! tip "For enums, reach for BeakEnumColumn"
    A `BeakEnumColumn<T>` already constrains a field to its `values` type-safely.
    Use `BeakInList` for a closed set of plain strings or numbers that is not
    modelled as a Dart enum.

## Upload rules

These two rules validate uploads. They apply to the `BeakFileType`, filename, or
byte-size a `BeakImageColumn`/`BeakFileColumn` produces.

### `BeakAllowedFileTypes`

Restricts an upload to `allowedTypes`. It validates `BeakFileType` values
directly, and strings either as file names (matched by extension,
case-insensitively) or as exact MIME types. An empty `allowedTypes` list allows
everything.

```dart title="packages/beak_core/lib/src/rules/beak_allowed_file_types.dart"
const BeakAllowedFileTypes(this.allowedTypes);
```

| Argument | Type | Meaning |
|---|---|---|
| `allowedTypes` | `List<BeakFileType>` | The accepted file types; empty means unrestricted. |

`id`: `allowed_file_types`. Message: `File type must be one of: ` followed by the
first extension of each allowed type, joined with `, `.

```dart title="packages/beak_core/lib/src/rules/beak_allowed_file_types.dart"
const rule = BeakAllowedFileTypes([BeakFileType.jpeg, BeakFileType.png]);
rule.validate('photo.PNG');       // null (extension matches)
rule.validate('image/jpeg');      // null (MIME matches)
rule.validate('notes.pdf');       // 'File type must be one of: jpg, png.'
```

### `BeakMaxFileSize`

Caps an upload's size at `maxSizeInBytes`. It validates against the size in bytes
as an `int`; other value types pass.

```dart title="packages/beak_core/lib/src/rules/beak_max_file_size.dart"
const BeakMaxFileSize(this.maxSizeInBytes);
```

| Argument | Type | Meaning |
|---|---|---|
| `maxSizeInBytes` | `int` | Highest accepted upload size in bytes. |

`id`: `max_file_size`. Message when an `int` byte count exceeds the cap:
`File must be at most $maxSizeInBytes bytes.`

!!! note "Column-level upload bounds vs. rules"
    Upload columns also take `maxSizeInBytes` and `allowedTypes` directly on the
    constructor. Those configure the column's own upload validator; the two rules
    above let you express the same limits inside a `rules` list when you want them
    alongside your other validations. See [Files and storage
    columns](../models/files-and-storage-columns.md).

## Continue reading

- [Column types reference](column-types.md) every column you attach these rules to.
- [Validation rules](../models/validation-rules.md) the guided tour, with worked form examples.
- [The type-safety promise](../concepts/the-type-safety-promise.md) why one rule list drives both client and server.
- [Security](../guides/security.md) how server-side validation backs up the client.
