import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import '../resources/habitats/models/habitat.dart';
import 'chart_data.dart';

/// The two kinds of map: a vector choropleth and a raster tile map.
BeakScreen mapBlocksPage() => BeakScreen(
  path: '/maps',
  title: 'Maps',
  icon: const BeakIconToken(OiIcons.map),
  navigationGroup: 'Blocks',
  body: BeakColumnBlock(gapInPixels: 24, children: [_choropleth(), _tileMap()]),
);

/// Countries shaded by the capacity of the habitat that comes from them.
// --8<-- [start:choropleth]
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
// --8<-- [end:choropleth]

/// Habitats pinned by latitude and longitude.
// --8<-- [start:tileMap]
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
// --8<-- [end:tileMap]
