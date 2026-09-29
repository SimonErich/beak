---
title: Typography and icons
description: Use the theme type scale and typed navigation icons.
type: guide
audience: [expert]
status: draft
---

# Typography and icons

Use `OiLabel` variants for headings, body text and captions in custom widgets. Blocks expose the same intent through their presentation options. Resource and screen icons use `BeakIconToken`, with Obers UI icon constants available through the UI barrel.

Use a short descriptive navigation title, readable section headings and captions for supporting information. Custom widgets should honor text scaling and available width. The shop receivables widget provides a compiling example.

```dart title="examples/clean_beak_config/lib/widgets/receivables_card.dart"
--8<-- "examples/clean_beak_config/lib/widgets/receivables_card.dart"
```

## Continue reading

- [Theming basics](theming-basics.md)
- [Custom widgets](../extending/custom-blocks-and-widgets.md)
