---
title: Column types
description: Choose storage kinds and semantic values for generated controls.
---

# Column types

The generator selects a storage column from the schema field type. Semantic metadata then selects richer inputs, formatting and validation.

| Schema value | Storage column or behavior |
| --- | --- |
| `String`, `BeakText` | Single-line or multiline text |
| `int`, `double` | Integer or decimal number |
| `bool` | Boolean toggle |
| `DateTime` | Timestamp with configured display |
| Enum | Typed choices and optional badges |
| `BeakJson`, `BeakJsonObject` | Structured JSON value |
| `BeakRichText` | Rich text |
| `BeakHexColor` | Color |
| `BeakImageRef`, `BeakFileRef` | Managed upload references |
| `BeakDate`, `BeakTime`, `Duration` | Date-only, time-only and duration semantics |
| `BeakDecimal` | Exact scaled value, including money |
| Typed scalar lists | List input and validation |
| A custom renderer declaration | Application-specific presentation |

Semantic fields include email, URL, phone, password, slug, choices, ratings, percentages, money and measured units. Use exact decimals for financial values and declare whether a percentage is stored as a ratio or display value. A currency field can depend on another field in the same record.

The fulfillment policy is the maintained rich-field example. Read [Semantic fields](semantic-fields.md) for parsing, storage and rounding rules, and [Column reference](../reference/column-types.md) for constructor parameters.

```dart title="examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart"
--8<-- "examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart"
```

## Continue reading

- [Declarative resources](../concepts/declarative-resources.md)
- [Custom screens](../extending/custom-screens-and-pages.md)
