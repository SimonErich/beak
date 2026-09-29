---
title: Generated code
description: Understand generated fields, record readers and preserved authored files.
type: guide
audience: [beginner, expert, agent]
status: draft
---

# Generated code

Run `beak prepare` after editing a schema. It discovers resource schemas under `lib/`, emits adjacent `.beak.dart` parts and updates the registry, panel defaults and server wiring. Generated files are committed; edit their schemas instead of their output.

Generated models expose typed scalar and relationship fields, query helpers and record readers. The `fields` namespace always contains every field. Direct shortcuts are omitted for names that collide with model members. Static schema `validationRules` and `behavior` getters are forwarded to the model.

The generator also proposes missing migrations. Existing migrations are preserved as upgrade history, and authored entrypoints and overrides remain application code. Review and apply database migrations explicitly. `beak doctor` detects stale generation and inconsistent wiring.

```dart title="examples/clean_beak_config/lib/resources/categories/models/category.dart"
--8<-- "examples/clean_beak_config/lib/resources/categories/models/category.dart"
```

## Continue reading

- [Defining models](defining-models.md)
- [CLI commands](../reference/cli-commands.md)
