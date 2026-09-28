---
title: Your first resource
description: Define a shared schema and register its presentation in a panel.
---

# Your first resource

A schema describes stored facts. A resource describes navigation and screens. The panel discovers the related models and supplies loading, validation and persistence.

## Read a schema

This category owns reusable attribute definitions. Products refer to the category through their own belongs-to relationship. The annotations describe relationships and their deletion behavior; the generated part supplies typed fields and record readers.

```dart title="examples/clean_beak_config/lib/resources/categories/models/category.dart"
--8<-- "examples/clean_beak_config/lib/resources/categories/models/category.dart"
```

Run `beak prepare` after changing a schema. Commit the generated `.beak.dart` files and review new migrations before applying them. You never edit a generated model to add application behavior: declare it on the schema.

## Register presentation

```dart title="examples/clean_beak_config/lib/resources/categories/category_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/categories/category_resource.dart"
```

The resource inherits standard routes from its model. Configured screens replace only their declared route roles. Referenced models are registered even when they have no sidebar entry.

`lib/main.dart` supplies resources to `BeakPanel`. A generated project can retain its generated default panel until it needs an authored layout; `beak prepare` preserves an authored entrypoint.

## Continue reading

- [Fields and validation](02-columns-and-validation.md)
- [Generated code](../models/generated-code.md)
