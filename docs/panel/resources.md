---
title: Resources
description: Configure navigation, search and conventional screens around a shared model.
type: guide
audience: [beginner]
status: draft
---

# Resources

A `BeakResource` connects one model to navigation and screens. Register resource instances in `BeakPanel.resources`; omitted screens use model-derived defaults.

```dart title="examples/clean_beak_config/lib/resources/orders/order_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/orders/order_resource.dart"
```

Titles, navigation grouping and rank belong here. `globalSearchSources` describes searchable fields, including typed related paths. Filters and table fields control presentation without changing the model's storage contract.

Each screen declares the route roles it serves. A form can handle create, edit and read with the same structure. Duplicate role declarations are configuration errors. Custom resource screens can replace a selected route while retaining the resource's surrounding navigation.

Model-owned transports and an injected panel source use the same resource definitions. Related models are registered recursively; a child model does not need a sidebar resource merely to participate in a relationship editor.

## Continue reading

- [Forms](../forms/form-screens.md)
- [Tables and filters](tables-and-filters.md)
