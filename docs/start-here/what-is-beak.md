---
title: What is Beak?
description: Build Dart and Flutter admin interfaces from shared model and screen configuration.
type: concept
audience: [beginner]
status: draft
---

# What is Beak?

Beak is a Dart and Flutter framework for model-driven admin panels. Schemas define types, relationships, validation and behavior. Resources define navigation, search and screens. Layouts arrange fields while the framework handles drafts, queries, persistence and refresh.

The default backend uses Shelf and Worm; data-source interfaces support other integrations. The frontend uses Obers UI. Custom screens and widgets remain available when a task needs more than generated CRUD.

```dart title="examples/clean_beak_config/lib/resources/categories/models/category.dart"
--8<-- "examples/clean_beak_config/lib/resources/categories/models/category.dart"
```

## Continue reading

- [Quickstart](quickstart.md)
- [Declarative resources](../concepts/declarative-resources.md)
