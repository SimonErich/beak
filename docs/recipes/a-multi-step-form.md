---
title: A multi-step form
description: Project reusable sections into a validated wizard.
---

# A multi-step form

Configure a `BeakWizardScreen` from `BeakWizardStep` nodes, or project shared `BeakFormSections` into steps. Beak validates each step, retains values while navigating and saves the complete draft graph on Finish.

```dart title="examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart"
--8<-- "examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart"
```

## Continue reading

- [Related guide](../panel/multi-step-forms.md)
- [All recipes](index.md)
