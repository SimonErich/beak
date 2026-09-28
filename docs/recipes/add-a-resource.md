---
title: Add a resource
description: Declare a schema and register its screen configuration.
---

# Add a resource

Add a schema below `lib/`, run `beak prepare`, review its migration and register a `BeakResource` in the panel. Place screen definitions beside the resource. The category resource shows a complete configuration.

```dart title="examples/clean_beak_config/lib/resources/categories/category_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/categories/category_resource.dart"
```

## Continue reading

- [Related guide](../panel/resources.md)
- [All recipes](index.md)
