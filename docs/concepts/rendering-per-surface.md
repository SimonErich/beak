---
title: Rendering per surface
description: Apply the same field metadata to inputs, tables and read views.
---

# Rendering per surface

A field's column type and semantic metadata determine its default renderer. Forms use inputs; tables and read layouts use formatted values. A projection can override its label or format without changing storage or validation.

Set `BeakFormatting` on the panel for locale, date patterns, currency and empty-value presentation. Exact decimal values retain their scale, and per-record currency fields select the correct currency. Custom renderers remain available for specialized columns. Field visibility controls presentation, while field policies control access.

## Continue reading

- [Semantic fields](../models/semantic-fields.md)
- [Custom columns](../extending/custom-columns.md)
