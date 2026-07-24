part of '../beak_block_host.dart';

/// Fetches a [BeakTileMapBlock]'s rows, turns those with coordinates into
/// pins, and renders them on `OiTileMap`.
class _BeakTileMapBlockView extends HookWidget {
  const _BeakTileMapBlockView({required this.block});

  final BeakTileMapBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakLocator<BeakDataSource>();
    final records = useState(const <BeakRecord>[]);

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final result = await BeakResourceRepository(
          dataSource,
        ).query(block.query);
        if (cancelled) {
          return;
        }
        if (result case BeakOk(:final value)) {
          records.value = value.items;
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource, block]);

    final markers = <OiMapMarker>[
      for (final record in records.value)
        if (_coordOf(record, block.latitudeField) case final double lat)
          if (_coordOf(record, block.longitudeField) case final double lng)
            OiMapMarker(
              latitude: lat,
              longitude: lng,
              label: block.labelField == null
                  ? ''
                  : record[block.labelField!.key]?.raw?.toString() ?? '',
              value: 1,
            ),
    ];

    final center = OiLatLng(
      block.centerLatitude ?? (markers.isEmpty ? 20 : markers.first.latitude),
      block.centerLongitude ?? (markers.isEmpty ? 0 : markers.first.longitude),
    );

    return OiCard(
      title: OiLabel.smallStrong(block.title),
      child: OiTileMap(
        label: block.title,
        center: center,
        zoom: block.zoom,
        markers: markers,
        tileUrlTemplate: block.tileUrlTemplate,
        heightInPixels: block.heightInPixels,
      ),
    );
  }

  double? _coordOf(BeakRecord record, BeakColumn column) =>
      switch (record[column.key]?.raw) {
        final num value => value.toDouble(),
        final String value => double.tryParse(value),
        _ => null,
      };
}
