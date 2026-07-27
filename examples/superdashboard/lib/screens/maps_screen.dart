import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';
import 'package:superdashboard/services/dashboard_charts.dart';
import 'package:beak/ui.dart';

/// The maps showcase — the two kinds of map Beak can drive from seeded data:
/// a vector choropleth (active users shaded by country) and a raster slippy
/// tile map (office locations pinned by latitude/longitude).
BeakScreen buildMapsScreen() => const BeakScreen(
  path: '/maps',
  title: 'Maps',
  icon: BeakIconToken(OiIcons.map),
  section: 'Showcase',
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [
      BeakCardBlock(
        title: 'Vector map — live users by country',
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
      BeakCardBlock(
        title: 'Tile map — offices',
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
    ],
  ),
);
