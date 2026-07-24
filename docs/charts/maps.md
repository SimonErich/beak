---
title: Maps
description: The two Beak map blocks, a vector choropleth that shades world regions by a value and a raster tile map that pins latitude/longitude rows on OpenStreetMap.
---

# Maps

After this page you can shade a world map by a per-country value with
`BeakMapBlock` and pin coordinate rows on a scrollable OpenStreetMap with
`BeakTileMapBlock`. Both are data-bound blocks that follow the same
query-plus-fields shape as the [charts](chart-basics.md); the difference is they
key on your column constants directly instead of a mapper function.

Both examples come from the showcase's maps screen (`apps/beak_superdashboard`,
port 8180), which seeds a `country_stats` table and an `office_locations` table.

## Two kinds of map

| Block | Geometry | Keys on | Renders onto | Use it for |
| --- | --- | --- | --- | --- |
| `BeakMapBlock` | vector world regions | `regionCodeField`, `valueField` | `OiVectorMap` | a value that varies by country |
| `BeakTileMapBlock` | raster OSM tiles | `latitudeField`, `longitudeField` | `OiTileMap` | points with real coordinates |

Pick the vector map when your data is one row per region and you want the whole
country shaded. Pick the tile map when your data is points on the globe, offices,
stores, sensors, and you want them pinned on a pannable, zoomable map.

## Vector choropleth: `BeakMapBlock`

A choropleth shades each region by a value. `BeakMapBlock` renders onto
`OiVectorMap` with its bundled world geometry: your query returns one row per
region, `regionCodeField` names the column holding the ISO 3166-1 alpha-2 code
that keys the map, and `valueField` names the column that drives the shade.

```dart title="packages/beak_frontend/lib/src/blocks/beak_map_block.dart"
final class BeakMapBlock extends BeakBlock {
  /// Creates a map block.
  const BeakMapBlock({
    required this.title,
    required this.query,
    required this.regionCodeField,
    required this.valueField,
    this.valueLabel = 'Value',
    this.heightInPixels = 320,
    super.span,
  });
```

The two `*Field` parameters take `BeakColumn` constants, not strings, so a
renamed column is a compile error rather than a blank map. The showcase keys on
`CountryStatColumns`:

```dart title="apps/beak_superdashboard/lib/screens/maps_screen.dart"
BeakCardBlock(
  title: 'Vector map - live users by country',
  child: BeakMapBlock(
    title: 'Active users',
    query: BeakQuerySpec(
      table: 'country_stats',
      pagination: analyticsPage,
    ),
    regionCodeField: CountryStatColumns.countryCode,
    valueField: CountryStatColumns.activeUsers,
    valueLabel: 'Active users',
  ),
),
```

Those columns are ordinary typed columns on the `country_stats` model. The
region code is a two-character string; note the `BeakMaxLength(2)` rule matching
the ISO alpha-2 format the map expects:

```dart title="apps/beak_superdashboard/lib/models/analytics/country_stat.dart"
/// ISO 3166-1 alpha-2 code, keying the map region.
static const countryCode = BeakStringColumn(
  key: 'country_code',
  label: 'Code',
  rules: [BeakRequired(), BeakMaxLength(2)],
);

/// Active users in this country.
static const activeUsers = BeakIntColumn(
  key: 'active_users',
  label: 'Active users',
  min: 0,
  sortable: true,
);
```

!!! tip "The region code must match the map's keys"
    `OiVectorMap` keys its regions by ISO 3166-1 alpha-2 (`US`, `DE`, `FR`). A row
    whose `regionCodeField` value is not a valid alpha-2 code has no region to
    shade and is skipped. Store the code, not the country name, in that column.

`valueLabel` is the caption shown in the tooltip and legend for the shaded value;
it defaults to `'Value'`.

## Raster tile map: `BeakTileMapBlock`

A tile map is the pannable, zoomable map you know from every "find us" page. Each
record with a latitude and longitude becomes a pin on a slippy `OiTileMap`, drawn
from OpenStreetMap tiles by default.

```dart title="packages/beak_frontend/lib/src/blocks/beak_tile_map_block.dart"
final class BeakTileMapBlock extends BeakBlock {
  /// Creates a tile map titled [title], pinning the rows of [query].
  const BeakTileMapBlock({
    required this.title,
    required this.query,
    required this.latitudeField,
    required this.longitudeField,
    this.labelField,
    this.centerLatitude,
    this.centerLongitude,
    this.zoom = 3,
    this.tileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.heightInPixels = 360,
    super.span,
  });
```

The showcase pins the office locations, labelling each pin by name and framing
the map on the world with `centerLatitude`, `centerLongitude`, and `zoom`:

```dart title="apps/beak_superdashboard/lib/screens/maps_screen.dart"
BeakCardBlock(
  title: 'Tile map - offices',
  child: BeakTileMapBlock(
    title: 'Offices',
    query: BeakQuerySpec(
      table: 'office_locations',
      pagination: analyticsPage,
    ),
    latitudeField: OfficeLocationColumns.latitude,
    longitudeField: OfficeLocationColumns.longitude,
    labelField: OfficeLocationColumns.name,
    centerLatitude: 30,
    centerLongitude: 0,
    zoom: 2,
  ),
),
```

The coordinate columns are `BeakDecimalColumn`s with enough precision to place a
pin accurately:

```dart title="apps/beak_superdashboard/lib/models/analytics/office_location.dart"
/// The office latitude.
static const latitude = BeakDecimalColumn(
  key: 'latitude',
  label: 'Latitude',
  precision: 5,
);

/// The office longitude.
static const longitude = BeakDecimalColumn(
  key: 'longitude',
  label: 'Longitude',
  precision: 5,
);
```

### Framing and tiles

A few parameters shape the view:

| Parameter | Default | What it does |
| --- | --- | --- |
| `labelField` | `null` | Column labelling each pin; omit for unlabelled markers. |
| `centerLatitude` / `centerLongitude` | first marker | Where the map opens. |
| `zoom` | `3` | Starting zoom level (higher is closer). |
| `tileUrlTemplate` | OpenStreetMap | The `{z}/{x}/{y}` tile source. |

Leave `centerLatitude` and `centerLongitude` unset and the map centers on the
first marker. Swap `tileUrlTemplate` to point at any `{z}/{x}/{y}` tile server if
you host your own tiles or use a different provider.

!!! warning "OpenStreetMap tiles have a usage policy"
    The default template hits OpenStreetMap's public tile servers, which are fine
    for development and light demo use but expect attribution and rate limits in
    production. Point `tileUrlTemplate` at your own or a commercial tile source
    before you ship a busy panel.

## The whole maps screen

Both blocks are just blocks, so the screen is a `BeakColumnBlock` of two cards.
Nothing here is map-specific plumbing; it reads like every other custom screen.

```dart title="apps/beak_superdashboard/lib/screens/maps_screen.dart"
BeakScreen buildMapsScreen() => const BeakScreen(
  path: '/maps',
  title: 'Maps',
  icon: BeakIconToken(OiIcons.map),
  section: 'Showcase',
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [
      // the two BeakCardBlocks above
    ],
  ),
);
```

## Continue reading

- [Chart basics](chart-basics.md) the query-plus-mapper shape maps share.
- [Advanced charts](advanced-charts.md) bubble, candlestick, and heatmap blocks.
- [Column types](../models/column-types.md) the `BeakStringColumn`, `BeakIntColumn`, and `BeakDecimalColumn` the map fields point at.
- [Dashboards](../panel/dashboards.md) where a map block sits beside stats and charts.
