---
title: Charts and maps
description: The Beak chart families and map blocks, all data-bound to a query through one typed record-to-point mapping.
---

# Charts and maps

Beak draws charts and maps the same way it draws everything else: you hand it a
query and a small typed function that turns records into points, and Beak runs
the query, maps the rows, and renders with `obers_ui_charts`. No chart library
plumbing, no `dynamic`, no string field references in your data path.

This section covers three surfaces:

- **[Chart basics](chart-basics.md)** the seven single-series chart families
  (line, bar, pie, donut, area, radar, funnel), the `BeakChartPoint` shape, the
  `BeakChartMapper` that produces it, and where charts live: on the flat
  dashboard (`BeakChart`) and inside any block tree (`BeakChartBlock`).
- **[Advanced charts](advanced-charts.md)** the three richer families that need
  more than a label and a value: bubble (x, y, size), candlestick (OHLC), and
  heatmap (row, column, value), each with its own typed point and mapper.
- **[Maps](maps.md)** the two map blocks: a vector choropleth
  (`BeakMapBlock`) that shades world regions by a value, and a raster slippy map
  (`BeakTileMapBlock`) that pins latitude/longitude rows on OpenStreetMap tiles.

## The shared shape

Every chart and map block carries the same four ideas. Learn them once and the
whole section reads the same.

| Idea | What it is | Example |
| --- | --- | --- |
| `title` | The card heading. | `'Revenue (area)'` |
| `query` | A `BeakQuerySpec` naming the table (and any sort, filter, pagination). | `BeakQuerySpec(table: 'time_series_points')` |
| `map` | A typed function from `List<BeakRecord>` to the chart's point type. | `seriesPoints('sales_revenue')` |
| `type` / fields | Which family to draw, or the field columns a map keys on. | `BeakChartType.area` |

Beak runs the query through the data source, applies `map` to the returned
records, and renders. A query that fails leaves the card empty rather than
throwing into your dashboard.

!!! tip "Charts want every row, not a page"
    `BeakQuerySpec` defaults to 25 rows per page. A chart over a 60-point series
    would silently truncate. The showcase raises the page size with a shared
    `BeakPagination(perPage: 500)`; do the same for any table a chart reads whole.

## Where the code lives

All the chart and map types are exported from `beak_frontend`. The single-series
types (`BeakChartType`, `BeakChartPoint`, `BeakChart`) live in
`packages/beak_frontend/lib/src/dashboard/beak_chart.dart`; the composable blocks
live under `packages/beak_frontend/lib/src/blocks/`. The showcase app
(`apps/superdashboard`, port 8180) wires all of them against seeded
analytics tables, which is where the worked examples on the next three pages come
from.

## Continue reading

- [Chart basics](chart-basics.md) the seven families, points, mappers, and the dashboard-vs-block split.
- [Advanced charts](advanced-charts.md) bubble, candlestick, and heatmap with their typed points.
- [Maps](maps.md) the vector choropleth and the raster tile map.
- [Data blocks](../blocks/data-blocks.md) the wider family of data-bound blocks charts belong to.
- [Dashboards](../panel/dashboards.md) how `BeakChart` and stats compose the flat dashboard.
