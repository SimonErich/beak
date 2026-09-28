import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

/// A tiny model whose rows carry the fields the gallery and timeline read.
final class _MediaModel extends BeakModel {
  const _MediaModel();

  @override
  String get table => 'media';

  @override
  String get displayColumnKey => 'caption';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'url', label: 'Url'),
    BeakStringColumn(key: 'caption', label: 'Caption'),
    BeakDateTimeColumn(key: 'at', label: 'At'),
  ];
}

void main() {
  const url = BeakStringColumn(key: 'url', label: 'Url');
  const caption = BeakStringColumn(key: 'caption', label: 'Caption');
  const at = BeakDateTimeColumn(key: 'at', label: 'At');

  setUp(() {
    final dataSource = FakeDataSource(
      records: {
        'media': {
          'm1': BeakRecord.fromRow(const {
            'id': 'm1',
            'url': 'https://example.com/a.png',
            'caption': 'Alpha',
            'at': '2026-01-01T00:00:00.000Z',
          }),
          'm2': BeakRecord.fromRow(const {
            'id': 'm2',
            'url': 'https://example.com/b.png',
            'caption': 'Beta',
            'at': '2026-02-01T00:00:00.000Z',
          }),
        },
      },
    );
    registerBeakDependencies(
      config: const BeakPanelConfig(
        title: 'Demo',
        apiBaseUrl: 'http://localhost',
        resources: [
          BeakResource(
            model: _MediaModel(),
            icon: BeakIconToken(OiIcons.image),
          ),
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

  group('static leaves', () {
    testWidgets('alert maps its level onto OiBanner', (tester) async {
      await pump(
        tester,
        const BeakAlertBlock('Saved', level: BeakAlertLevel.success),
      );

      final banner = tester.widget<OiBanner>(find.byType(OiBanner));
      expect(banner.level, OiBannerLevel.success);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('badge maps its color onto OiBadge', (tester) async {
      await pump(
        tester,
        const BeakBadgeBlock('Active', color: BeakColor.success),
      );

      final badge = tester.widget<OiBadge>(find.byType(OiBadge));
      expect(badge.color, OiBadgeColor.success);
      expect(badge.label, 'Active');
    });

    testWidgets('every alert level has a banner level of its own', (
      tester,
    ) async {
      const expected = {
        BeakAlertLevel.info: OiBannerLevel.info,
        BeakAlertLevel.success: OiBannerLevel.success,
        BeakAlertLevel.warning: OiBannerLevel.warning,
        BeakAlertLevel.error: OiBannerLevel.error,
      };
      expect(expected.keys.toSet(), BeakAlertLevel.values.toSet());

      for (final MapEntry(key: level, value: banner) in expected.entries) {
        await pump(tester, BeakAlertBlock('Heads up', level: level));

        expect(tester.widget<OiBanner>(find.byType(OiBanner)).level, banner);
      }
    });

    testWidgets('every badge color maps onto an obers badge color', (
      tester,
    ) async {
      const expected = {
        BeakColor.primary: OiBadgeColor.primary,
        BeakColor.secondary: OiBadgeColor.accent,
        BeakColor.success: OiBadgeColor.success,
        BeakColor.warning: OiBadgeColor.warning,
        BeakColor.error: OiBadgeColor.error,
        BeakColor.info: OiBadgeColor.info,
        BeakColor.muted: OiBadgeColor.neutral,
      };
      expect(expected.keys.toSet(), BeakColor.values.toSet());

      for (final MapEntry(key: color, value: badge) in expected.entries) {
        await pump(tester, BeakBadgeBlock('State', color: color));

        expect(tester.widget<OiBadge>(find.byType(OiBadge)).color, badge);
      }
    });

    testWidgets('progress renders a linear bar at its value', (tester) async {
      await pump(tester, const BeakProgressBlock(value: 0.6, label: 'Storage'));

      final progress = tester.widget<OiProgress>(find.byType(OiProgress));
      expect(progress.value, 0.6);
      expect(progress.label, 'Storage');
    });

    testWidgets('rating renders read-only stars', (tester) async {
      await pump(tester, const BeakRatingBlock(value: 3.5));

      final rating = tester.widget<OiStarRating>(find.byType(OiStarRating));
      expect(rating.value, 3.5);
      expect(rating.readOnly, isTrue);
      expect(rating.allowHalf, isTrue);
    });
  });

  group('data-bound leaves', () {
    testWidgets('gallery turns rows into thumbnails on OiGallery', (
      tester,
    ) async {
      await pump(
        tester,
        const BeakGalleryBlock(
          query: BeakQuerySpec(table: 'media'),
          imageUrlField: url,
          captionField: caption,
          columns: 3,
        ),
      );

      final gallery = tester.widget<OiGallery>(find.byType(OiGallery));
      expect(gallery.items, hasLength(2));
      expect(gallery.columns, 3);
      expect(gallery.items.first.src, 'https://example.com/a.png');
      tester.takeException();
    });

    testWidgets('timeline orders rows newest-first on OiTimeline', (
      tester,
    ) async {
      await pump(
        tester,
        const BeakTimelineBlock(
          query: BeakQuerySpec(table: 'media'),
          titleField: caption,
          timeField: at,
        ),
      );

      final timeline = tester.widget<OiTimeline>(find.byType(OiTimeline));
      expect(timeline.events, hasLength(2));
      expect(timeline.events.first.title, 'Beta');
      tester.takeException();
    });
  });

  group('icon gallery', () {
    testWidgets('renders one OiIcon per entry with its label', (tester) async {
      await pump(
        tester,
        const BeakIconGalleryBlock(
          columns: 3,
          items: [
            BeakIconGalleryItem(
              icon: BeakIconToken(OiIcons.home),
              label: 'Home',
            ),
            BeakIconGalleryItem(
              icon: BeakIconToken(OiIcons.user),
              label: 'User',
            ),
          ],
        ),
      );

      expect(find.byType(OiIcon), findsNWidgets(2));
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('User'), findsOneWidget);
    });
  });
}
