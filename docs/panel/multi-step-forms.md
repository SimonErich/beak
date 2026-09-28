---
title: Multi-step forms
description: Present one managed draft in validated steps.
---

# Multi-step forms

A `BeakWizardScreen` supplies steps to the same form session used by ordinary screens. Moving between steps retains values and related edits. Going forward validates the current step; finishing validates the submitted graph.

```dart title="examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart"
--8<-- "examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart"
```

For rail navigation, `BeakWizardStep.heading` and `introduction` declare the main step header separately from the short navigation `title` and `description`. The header stays above the scrolling inputs, alongside the pinned actions and independent summary. Both values fall back to the navigation text when omitted; no wrapper section or custom widget is needed.

Keep steps aligned with user decisions: choose the customer, arrange delivery, edit items, review the result. Use cards and columns inside a step for grouping. A selected customer can constrain a later relationship through a shared eligibility rule.

Use `BeakFormSections` when the same sections should become an edit screen with tabs. Presentation does not define an alternative save path: both screens execute the same model constraints and actions.

All relationship changes remain local until submission. Cancelling an inner editor restores that editor's checkpoint; abandoning a wizard follows the form's draft policy.

## Continue reading

- [Forms](forms.md)
- [Declarative resources](../concepts/declarative-resources.md)

## Dynamic guidance

Use `navigationDescription` for a short explanation beneath the rail. Step
`introductionBuilder` and `footerHintBuilder` can name a selected customer,
delivery date, or approval recipient from the same draft. List related fields
in the step's `dependencies`; simple scalar values already belong to the form.
The callbacks receive the global formatting policy, so contextual dates and
amounts follow the panel's configured locale and time zone.

See [Workflow presentations](workflow-presentations.md) for compact date
presets, record templates, scoped catalog tabs, populated previews, and rich
relationship choices. These are presentation declarations over the same final
validation and save operation.
