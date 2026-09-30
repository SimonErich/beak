import 'package:beak/migrations.dart';
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodio_adminpanel/beak/registry.g.dart';
import 'package:foodio_adminpanel/beak/server.g.dart';
import 'package:foodio_adminpanel/main.dart';
import 'package:go_router/go_router.dart';

import 'support/gabel_fonts.dart';

/// A verified viewport and the height its delivery slot rows are given.
typedef _Viewport = ({Size size, double slotRowsHeightInPixels});

/// The viewports the example is verified at: desktop, phone, phone rotated.
///
/// Only the phone stacks the overview cards narrowly enough for every time
/// range to wrap, so only there do the slot rows get their taller box.
const _viewports = <String, _Viewport>{
  'desktop': (size: Size(1440, 900), slotRowsHeightInPixels: 216),
  'tablet': (size: Size(768, 1024), slotRowsHeightInPixels: 216),
  'phone': (size: Size(375, 812), slotRowsHeightInPixels: 306),
  'rotated phone': (size: Size(812, 375), slotRowsHeightInPixels: 216),
};

void main() {
  late DatabaseAdapter adapter;
  late WormDataSource source;
  setUpAll(() async {
    await loadGabelFonts();
    final host = beakHost(
      environment: {
        'DATABASE_URL': 'sqlite::memory:',
        'BEAK_STORAGE_DRIVER': 'none',
      },
    );
    adapter = adapterFromUrl(host.config.databaseUrl);
    await adapter.connect();
    await MigrationRunner(
      adapter: adapter,
      migrations: host.migrations,
      seeders: host.seeders,
    ).fresh(seed: true);
    source = WormDataSource(buildBeakRegistry(), adapter: adapter);
  });
  tearDownAll(() async {
    await adapter.disconnect();
    await Worm.reset();
  });

  for (final MapEntry(key: name, value: viewport) in _viewports.entries) {
    testWidgets('the home overview and the orders list fit a $name screen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(viewport.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        BeakPanel(config: foodioPanel(), dataSource: source),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
      expect(
        router.routeInformationProvider.value.uri.path,
        '/overview',
        reason: 'The panel lands on its first navigation item.',
      );
      expect(find.text('Good morning, Marie'), findsWidgets);
      expect(tester.takeException(), isNull, reason: 'Overview at $name');
      final rows = find
          .ancestor(
            of: find.byType(OiCapacityIndicator).first,
            matching: find.byWidgetPredicate(
              (widget) => widget is SizedBox && widget.height != null,
            ),
          )
          .first;
      expect(
        tester.widget<SizedBox>(rows).height,
        viewport.slotRowsHeightInPixels,
        reason: 'Delivery slot rows at $name',
      );
      router.go('/orders');
      await tester.pumpAndSettle();
      for (
        var attempt = 0;
        attempt < 100 && find.text('Loading…').evaluate().isNotEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('Loading…'), findsNothing);
      expect(tester.takeException(), isNull, reason: 'Orders list at $name');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
