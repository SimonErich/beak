# Cheatsheet

> Find the configuration entrypoint for each common task.

| Task | Configuration |
| --- | --- |
| Register navigation | `BeakPanel.resources` and `BeakResource` |
| Arrange a form | `BeakFormScreen` with `BeakFormLayout` |
| Add a wizard | `BeakWizardScreen` and `BeakWizardStep` |
| Reuse sections | `BeakFormSections` projections |
| Show a related picker | Generated relationship `.inputCombobox()` |
| Edit owned children | Generated relationship `.tableForm()` |
| Add a gallery | Generated relationship `.galleryForm()` |
| Define eligibility | `BeakExists` with `BeakFieldMatch` |
| Compute shared values | `BeakModelBehavior.values` |
| Define a transition | `BeakModelBehavior.actions` |
| Resume drafts | Screen `drafts` configuration |
| Review changes | `reviewBeforeSave` |
| Diagnose resolved state | `showInspector` or `session.explain()` |
| Duplicate a graph | Resource `duplication` with `BeakDuplicationSpec` |
| Import CSV | `BeakImportView` and `BeakImportDefinition` |
| Bulk edit | `BeakBulkAction.edit` with typed field changes |
| Add a custom page | `BeakScreen` and blocks |
| Add a custom input | `BeakFormWidget` and `BeakDraftScope` |
| Enforce field access | Server `BeakFieldPolicy` |

Generated fields are shared across these declarations. See each guide for the storage, permission and transaction contracts.

## Continue reading

- [Forms](../forms/form-screens.md)
- [Model behavior](../models/behavior.md)
