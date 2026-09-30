# Maps

> Shade countries by a value with the vector map block, or pin rows by latitude and longitude on an OpenStreetMap tile map.

Two blocks put rows on a map, and they are different kinds of map. `BeakMapBlock` is a world choropleth: it shades countries by a value, from geometry bundled with obers_ui, and needs no network. `BeakTileMapBlock` is a slippy tile map: it pins rows at coordinates on tiles fetched from a tile server. After this page you can pick the right one, feed it the right columns, and you know what the default tile server expects from you.

## At a glance

| Block | Draws | Needs from each row | Network |
| --- | --- | --- | --- |
| `BeakMapBlock` | a world map, countries shaded by a value, with a legend | an ISO 3166-1 alpha-2 country code and a number | none |
| `BeakTileMapBlock` | a pannable, zoomable map with a pin per row | a latitude and a longitude, optionally a label | tile requests |

Both take a `BeakQuerySpec`, so you scope, sort and page them like a chart. The default page of 25 rows applies here too, which is why the Aviary's queries ask for the largest page (200).

## The choropleth

```dart title="examples/showcase/lib/pages/map_blocks.dart"
BeakBlock _choropleth() => BeakCardBlock(
  title: 'Where the birds come from',
  child: BeakMapBlock(
    title: 'Capacity by country',
    query: const HabitatModel().query(pagination: chartPage),
    regionCodeField: HabitatModel.countryCode.column,
    valueField: HabitatModel.capacity.column,
    valueLabel: 'Capacity',
  ),
);
```

`regionCodeField` names the column that holds the country code and `valueField` the number that drives the shade. `valueLabel` is the caption in the tooltip and legend.

Three details decide whether a country lights up:

- **The code is uppercase alpha-2.** `BR` matches, `br` does not, and `BRA` does not. The bundled outlines are keyed by the uppercase two-letter code, and the block does not normalize what your column holds. Validate the column instead: the Aviary's habitat carries `BeakMinLength(2)` and `BeakMaxLength(2)` on `countryCode`.
- **One row per country.** The block builds a map from code to value, so when several rows share a code, the last one wins. It does not add them up. To shade a country by a total, query grouped data, for example a [summary](summaries.md) result mapped to rows, or a table that holds one row per country.
- **A country needs an outline.** The world geometry is low-resolution and covers countries, not subdivisions. A code without a bundled outline draws nothing, and a country without a row keeps the neutral fill.

The value is read as a number whether the wire carries a number or a numeric string (a Postgres decimal does), and a value that cannot be read counts as 0.

## The tile map

```dart title="examples/showcase/lib/pages/map_blocks.dart"
BeakBlock _tileMap() => BeakCardBlock(
  title: 'Where the habitats sit in the wild',
  child: BeakTileMapBlock(
    title: 'Habitats',
    query: const HabitatModel().query(pagination: chartPage),
    latitudeField: HabitatModel.latitude.column,
    longitudeField: HabitatModel.longitude.column,
    labelField: HabitatModel.name.column,
    centerLatitude: 10,
    centerLongitude: 20,
    zoom: 1,
  ),
);
```

A row becomes a pin when both coordinate columns hold a number, or a numeric string. Rows missing either are skipped. `labelField` names the pin; without it the pin has an empty label. Coordinates are decimal degrees, latitude first, and the block does not check the ranges. The projection is Web Mercator, which stops at about 85 degrees of latitude.

The view starts at `centerLatitude` and `centerLongitude` and at `zoom` (an integer, default 3). Without a center it opens on the first pin, or on latitude 20 and longitude 0 when there are no pins. The reader can drag the map and zoom it, from level 1 to 18.

### Tiles, attribution and the default server

`tileUrlTemplate` defaults to `https://tile.openstreetmap.org/{z}/{x}/{y}.png`, the public OpenStreetMap server, and the map shows the OpenStreetMap credit. That server has a usage policy that rules out heavy use, so a production panel that many people open should point `tileUrlTemplate` at a provider you have an account with, or at your own tile server. The block accepts any `{z}/{x}/{y}` template.

The credit text is not a parameter of the block. It stays "© OpenStreetMap contributors" whatever template you set, so if your provider requires its own attribution, add it beside the map as a text block. Browsers also need to be allowed to load the tile host: a panel behind a strict content security policy has to permit it.

## Rules and limits

- Same states as charts. Neither block has a loading state. A failed request keeps the last map on screen and shows an error line above it with a Retry button (the server's message for a domain failure, the panel's generic sentence for an infrastructure one). Both refetch after a write.
- The query decides the rows. 25 by default, and there is no server-side aggregation. For a country total, aggregate first.
- The tile map needs the network to get its tiles. The choropleth draws from bundled geometry and works offline.
- One value per pin. Every pin has the same weight; the block does not size pins by a column. If you need bubbles, use a [bubble chart](charts.md) or a summary.
- Heights are fixed. `heightInPixels` is 320 for the choropleth and 360 for the tile map, and both sit inside a card that carries `title`.
- Not a geocoder. Rows need coordinates or a country code. Nothing converts addresses.

## Verify it

The Aviary builds both maps on its Maps page, with fixture rows:

```console
$ cd examples/showcase
$ flutter test --no-pub test/aviary_pages_test.dart
...
Maps renders
...
All tests passed!
```

The habitats it maps have six different countries, so each shades once:

```console
$ curl -s -X POST localhost:8082/api/habitats/query -H 'content-type: application/json' \
    -d '{"table":"habitats"}' | jq -c '[.items[].values | {country_code, capacity}]'
[{"country_code":"BR","capacity":40},{"country_code":"AU","capacity":30},{"country_code":"ZA","capacity":25},{"country_code":"NZ","capacity":15},{"country_code":"PE","capacity":20},{"country_code":"IN","capacity":35}]
```

## Reference

Required parameters are marked with a star. Every block also takes `span`.

| Block | Parameters (default) |
| --- | --- |
| `BeakMapBlock` | `title`*, `query`*, `regionCodeField`*, `valueField`*, `valueLabel` (`'Value'`), `heightInPixels` (320) |
| `BeakTileMapBlock` | `title`*, `query`*, `latitudeField`*, `longitudeField`*, `labelField`, `centerLatitude`, `centerLongitude`, `zoom` (3), `tileUrlTemplate` (OpenStreetMap), `heightInPixels` (360) |

All the field parameters are `BeakColumn`s (`HabitatModel.countryCode.column`). Every block class with its constructor is on [Blocks](../reference/blocks.md).

## Continue reading

- [Charts](charts.md) the same query-and-mapper pattern for lines, bars and heat maps.
- [Module blocks](module-blocks.md) media, documents and conversations bound to your models.
- [Custom screens](../panel/custom-screens.md) where a map page is routed.
- [Blocks](../reference/blocks.md) every block class and its parameters.
