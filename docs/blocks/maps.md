---
title: Maps
description: Configure data maps and tile maps inside custom screens.
type: guide
audience: [expert]
status: draft
---

# Maps

`BeakMapBlock` presents geographic data; `BeakTileMapBlock` provides a tile-based map surface. Configure their typed data, labels and callbacks in a screen definition. Data loading and provider credentials belong in the application service boundary.

Location data should have explicit coordinate conventions and meaningful empty states. The block API below describes the tile-map configuration.

```dart title="packages/beak_frontend/lib/src/blocks/beak_tile_map_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_tile_map_block.dart"
```

## Continue reading

- [Custom screens](../panel/custom-screens.md)
- [Block reference](../reference/blocks.md)
