---
title: Hide a resource from the sidebar
description: Keep a model, its API and its relationships while dropping it from the navigation.
---

# Hide a resource from the sidebar

A join table or a child model usually has no business in the navigation, but it
still needs its model, its API and its relationships. Set `hidden: true` on it
in `beak.yaml`; that is the only change:

```yaml title="examples/store/beak.yaml"
resources:
  products:
    icon: package
    section: Catalog
  # ...categories, tags, roast_profiles, orders, users...
  order_items:
    hidden: true
```

The showcase app leans on this hard: 49 models, 17 of them navigable.

## Continue reading

- [beak.yaml](../reference/beak-yaml.md)
