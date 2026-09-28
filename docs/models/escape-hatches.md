---
title: Model escape hatches
description: Customize presentation and persistence while retaining typed model metadata.
---

# Model escape hatches

Use normal schemas and generated fields for standard data. A model can provide a custom transport while keeping its query and presentation metadata. A custom column renderer handles a specialized value; a custom form node handles a specialized interaction.

`BeakFormWidget` receives the current draft scope. Read and stage values through typed fields so validation, dirty tracking, review and saving remain consistent. `BeakWidgetBlock` hosts independent custom widgets on pages and dashboards. Keep widget state local only when it does not represent persisted form values.

For cross-record business calculations, use shared model behavior or a transactional graph preparer. For an existing external backend, implement the data-source capabilities it actually supports; unsupported graph operations must fail explicitly.

## Continue reading

- [Custom columns](../extending/custom-columns.md)
- [Custom data sources](../extending/custom-data-sources.md)
