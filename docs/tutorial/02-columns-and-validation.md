---
title: Columns and validation
description: Use typed fields, semantic metadata and shared model constraints.
---

# Columns and validation

Declare each field's type and shared constraints on the schema. Beak uses that information for controls, formatting, filters and authoritative validation.

```dart title="examples/clean_beak_config/lib/resources/products/models/product_variant.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/models/product_variant.dart"
```

Non-nullable fields become required. `rules` adds reusable scalar constraints. `unique` is enforced by the database as well as preflight validation. Relationship identity types follow the related model's primary key.

## Rich values

The fulfillment policy demonstrates exact money, per-record currency, percentages, units, dates, durations, lists and structured objects. These use semantic metadata on existing storage columns. Their generated field references preserve the public Dart value type.

Read [Semantic fields](../models/semantic-fields.md) for the complete storage and formatting contract. Configure the panel's formatting policy once to control date patterns, locale, currency and empty values.

## Cross-field constraints

A schema's static `validationRules` getter declares conditional requirements, field comparisons, distinct collection values and relationship eligibility. These rules run through the common validation engine. A rule that must hold for all callers belongs here or in shared model behavior.

Placement validators can add screen-specific feedback. They do not replace the server's invariants. Missing, pending and invalid values remain visible in the draft until corrected.

## Continue reading

- [Relationships](03-relationships.md)
- [Validation rules](../models/validation-rules.md)
