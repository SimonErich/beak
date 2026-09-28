---
title: A row action
description: Declare a server-owned transition once for forms and tables.
---

# A row action

Add a `BeakModelAction` to the schema behavior for a business transition. Resource tables discover it, load the current record and collect optional arguments. Use `BeakRecordAction` only for an application-specific presentation callback.

```dart title="examples/clean_beak_config/lib/resources/invoices/models/invoice.dart"
--8<-- "examples/clean_beak_config/lib/resources/invoices/models/invoice.dart"
```

## Continue reading

- [Related guide](../panel/actions.md)
- [All recipes](index.md)
