---
title: Custom screens
description: Compose dashboards and complete custom application screens from Beak blocks and widgets.
type: guide
audience: [beginner, expert]
status: draft
---

# Custom screens

Register custom pages with `BeakPanel.pages`. Each `BeakScreen` provides a route,
optional navigation entry and `BeakBlock` body. The panel supplies its normal theme,
dependencies, formatting and resource navigation.

The shop dashboard mixes live metrics and filtered tables with a reusable custom
receivables widget. The same widget appears on the Operations page; both observe
confirmed writes through Beak's mutation source.

```dart title="examples/clean_beak_config/lib/overview.dart"
--8<-- "examples/clean_beak_config/lib/overview.dart:shopOverview"
```

Use `BeakWidgetBlock` to embed custom UI and `BeakCustomResourceScreen` to replace a
specific resource route. A custom widget inside an otherwise ordinary form uses
`BeakFormWidget` and the existing draft session, so custom interactions still take
part in save, cancel and validation.

See [custom screens and pages](custom-screens.md) for route
options, [custom blocks and widgets](../extending/custom-blocks-and-widgets.md) for
the embedded-widget example, and [dynamic attributes and variants](../models/dynamic-attributes-and-variants.md)
for a custom editor that stages owned relationships.

## Continue reading

- [Custom pages](custom-screens.md).
- [Custom widgets](../extending/custom-blocks-and-widgets.md).
