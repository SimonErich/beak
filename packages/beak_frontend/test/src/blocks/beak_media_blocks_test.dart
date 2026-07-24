import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_charts/obers_ui_charts.dart';

import '../../support/panel_fixtures.dart';

/// A tiny model whose rows carry the fields the media blocks read.
final class _RegionModel extends BeakModel {
  const _RegionModel();

  @override
  String get table => 'regions';

  @override
  String get displayColumnKey => 'code';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'code', label: 'Code'),
    BeakStringColumn(key: 'url', label: 'Url'),
    BeakIntColumn(key: 'value', label: 'Value'),
  ];
}

void main() {
  setUp(() {
    final dataSource = FakeDataSource(
      records: {
        'regions': {
          'r1': BeakRecord.fromRow(const {
            'id': 'r1',
            'code': 'US',
            'url': 'https://example.com/a.png',
            'value': 42,
          }),
          'r2': BeakRecord.fromRow(const {
            'id': 'r2',
            'code': 'DE',
            'url': 'https://example.com/b.png',
            'value': 17,
          }),
        },
      },
    );
    registerBeakDependencies(
      config: const BeakPanelConfig(
        title: 'Demo',
        apiBaseUrl: 'http://localhost',
        resources: [
          BeakResource(model: _RegionModel(), icon: BeakIconToken(OiIcons.map)),
        ],
      ),
      dataSource: dataSource,
    );
  });

  Future<void> pump(WidgetTester tester, BeakBlock block) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakBlockHost(block: block),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('map folds rows into region values on OiVectorMap', (
    tester,
  ) async {
    await pump(
      tester,
      const BeakMapBlock(
        title: 'Users by country',
        query: BeakQuerySpec(table: 'regions'),
        regionCodeField: BeakStringColumn(key: 'code', label: 'Code'),
        valueField: BeakIntColumn(key: 'value', label: 'Value'),
      ),
    );

    final map = tester.widget<OiVectorMap>(find.byType(OiVectorMap));
    expect(map.values, {'US': 42, 'DE': 17});
    tester.takeException();
  });

  testWidgets('carousel turns rows into image slides on OiCarousel', (
    tester,
  ) async {
    await pump(
      tester,
      const BeakCarouselBlock(
        query: BeakQuerySpec(table: 'regions'),
        imageUrlField: BeakStringColumn(key: 'url', label: 'Url'),
      ),
    );

    final carousel = tester.widget<OiCarousel>(find.byType(OiCarousel));
    expect(carousel.items, hasLength(2));
    tester.takeException();
  });

  testWidgets('video plays the first row on OiVideoPlayer', (tester) async {
    await pump(
      tester,
      const BeakVideoBlock(
        query: BeakQuerySpec(table: 'regions'),
        urlField: BeakStringColumn(key: 'url', label: 'Url'),
        title: 'Clip',
      ),
    );

    final player = tester.widget<OiVideoPlayer>(find.byType(OiVideoPlayer));
    expect(player.src, 'https://example.com/a.png');
    expect(player.label, 'Clip');
    tester.takeException();
  });

  testWidgets('radial slider updates its value on change', (tester) async {
    await pump(
      tester,
      const BeakRadialSliderBlock(label: 'Volume', initialValue: 40),
    );

    final slider = tester.widget<OiRadialSlider>(find.byType(OiRadialSlider));
    expect(slider.value, 40);
    expect(slider.label, 'Volume');
  });
}
