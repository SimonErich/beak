---
title: Validation
description: Share scalar, record and relationship constraints between client and server.
type: guide
audience: [beginner, expert]
status: draft
---

# Validation

Column rules validate individual values. Static schema `validationRules` describe cross-field and relationship constraints. The shared engine handles required values, bounds, patterns, collections, comparisons, conditional requirements and eligible references.

Use `BeakExists` for references and `BeakFieldMatch` for scoped relationships. `BeakCount` constrains collection size and `BeakDistinct` prevents repeated child values. Database uniqueness remains authoritative when two requests race. A frontend check provides feedback but cannot replace that boundary.

Screen placement validators can refine the current workflow. Wizard steps validate before advancing; the final save validates the complete graph. Server errors retain field and relation paths so the form can reveal the relevant group. Async checks must complete before submission.

```dart title="examples/clean_beak_config/lib/resources/invoices/models/invoice.dart"
--8<-- "examples/clean_beak_config/lib/resources/invoices/models/invoice.dart"
```

## Continue reading

- [Validation reference](../reference/validation-rules.md)
- [Model behavior](behavior.md)
