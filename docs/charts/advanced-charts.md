---
title: Advanced charts
description: Use typed heatmap, bubble and candlestick configurations.
---

# Advanced charts

Specialized chart blocks retain the same page composition contract. Heatmaps map values to cells, bubble charts add a size dimension, and candlestick charts represent open, high, low and close values. Choose the block whose data type matches the meaning of the data; transform domain records in a typed loader.

The heatmap contract is shown below. `BeakBubbleChartBlock` and `BeakCandlestickChartBlock` are exported beside it.

```dart title="packages/beak_frontend/lib/src/blocks/beak_heatmap_chart_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_heatmap_chart_block.dart"
```

## Continue reading

- [Chart basics](chart-basics.md)
- [Block reference](../reference/blocks-index.md)
