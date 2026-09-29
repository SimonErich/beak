---
title: Defining models
description: Describe data once and generate typed model, field and record APIs.
type: guide
audience: [beginner]
status: draft
---

# Defining models

Declare an annotated `BeakSchema` anywhere under `lib/`. Import the generated part and run `beak prepare`. The generator discovers schemas, resolves relationships and emits typed helpers.

```dart title="examples/clean_beak_config/lib/resources/products/models/product_variant.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/models/product_variant.dart"
```

A schema contains stored fields, their validation and relationship ownership. Static `validationRules` and `behavior` getters hold shared constraints and lifecycle configuration; generated model getters forward them without copying their logic.

Generated `Model.fields` always exposes field references. Convenient direct shortcuts are also emitted when their names do not collide with model members. Required fields come from nullability. Defaults and semantic metadata are checked against the declared field type.

Keep presentation in resource and screen files. Keep application-specific pure calculations in a domain module and reference them from shared behavior. Custom model classes remain available for integration with an existing data source.

## Continue reading

- [Generated code](generated-code.md)
- [Shared model behavior](behavior.md)
