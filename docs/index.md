---
title: Beak
description: Declarative admin panels with shared model behavior and customizable screens.
---

# Beak

Build an admin panel from shared schemas, resource definitions and structured layouts. Beak handles loading, typed inputs, validation, relationship drafts, saving and refresh.

```dart title="examples/clean_beak_config/lib/main.dart"
--8<-- "examples/clean_beak_config/lib/main.dart"
```

The maintained shop includes products and variants, category-defined attributes, orders, invoices with taxes and vouchers, draft recovery, imports and custom operational widgets. The minimal quickstart uses the same contracts.

- [Start a project](start-here/quickstart.md).
- [Learn the declarative model](concepts/declarative-resources.md).
- [Follow the shop tutorial](tutorial/index.md).
- [Customize a screen](extending/custom-screens-and-pages.md).

Models own shared constraints and lifecycle rules. Screens own layout. Typed extension points remain available for domain calculations, custom controls and alternative data sources.

## Continue reading

- [Models](models/index.md)
- [The panel](panel/index.md)
