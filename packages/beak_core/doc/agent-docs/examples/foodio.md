# Foodio admin

> Tour the Foodio food-ordering admin: composed lists, a wizard, templates, effects and a theme.

The [Foodio admin example](https://github.com/SimonErich/beak/tree/v0.9.0/examples/foodio-adminpanel) demonstrates a custom visual design through reusable Beak configuration. Its application code supplies models, domain calculations, presentation definitions and a theme. Beak owns fetching, filters, record state, validation, commits and command recovery.

## One population for the orders page

`BeakListDefinition` declares the order presets, typed composite columns, quick filters, summary region, saved-view provider and export projection. `BeakQueryController` resolves the permanent resource scope, selected preset, interactive filters and search once. The table uses its paginated query; summaries and export use the same population without pagination.

Preset counts have their own documented scope: they describe each preset before the currently selected list's interactive filters. Foodio's page subtitle formats those same counts. It does not make a second application request.

A saved view stores versioned query choices in a normal resource. Resource authorization controls who can read or change it. Navigation retains the originating list state through a local return URI; the primary rail and contextual sidebar are panel configuration.

## One draft for the complete workflow

The create wizard and record views compose `BeakFormNode` regions: customer choices, dependent profile and delivery inputs, catalog relationship rows, summaries, capacity indicators and actions. Generated typed readers bind these regions to one `BeakFormSession`. The catalog creates staged child rows; it does not write a separate order while the user is still choosing items.

The summary footer pins totals independently of the summary's scroll position.
`BeakReviewSection` displays the shared values and supplies an Edit link to its
owning step. `BeakFormReader.stepIndex` controls the review-only aside without
application navigation state. Forward navigation validates prerequisites; review
links preserve staged edits. Collapsible cards retain their fields and reopen
when validation identifies an error.

Dependency declarations let Beak eagerly load relationships used by templates and calculations. Inline choices and dependent eligibility reuse the model's validation rules. Custom calculation functions remain ordinary typed Dart functions so client previews and trusted server calculations can share them.

A named model action runs through the existing graph commit path. Backend guards and the transactional domain preparer determine whether a transition is allowed and compute authoritative totals. Timeline and document records come from those domain operations. An action's menu position does not grant authorization.

## Presentation and effects stay separate

Obers owns responsive page, rail, wizard, sheet, table and input presentation. Beak connects those components to typed queries and drafts. Foodio's theme supplies semantic colors, typography, icons and component styling. Schema `EnumLabels` and badge colors provide consistent labels across inputs, filters, tables and formatted export without changing wire values.

Effects that can outlive a request use the [durable effects workflow](../backend/durable-effects.md). Optional shared foreground refresh invalidates active readers when remote work finishes. Unsaved form drafts are preserved; they are not replaced by polling responses.

## Continue reading

- [Composed lists and query state](../panel/composed-lists.md)
- [Workflow presentations](../forms/workflow-presentations.md)
- [Model behavior](../models/behavior.md)
- [Population summaries](../blocks/summaries.md)
