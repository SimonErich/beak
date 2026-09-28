import 'package:beak/migrations.dart';
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:foodio_adminpanel/beak/registry.g.dart';
import 'package:foodio_adminpanel/beak/server.g.dart';
import 'package:foodio_adminpanel/main.dart';
import 'package:foodio_adminpanel/models/models.dart';
import 'package:foodio_adminpanel/seeders/foodio_seeder.dart';

void main() {
  late DatabaseAdapter adapter;
  late WormDataSource source;
  setUpAll(() async {
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

  testWidgets(
    'the complete panel boots and all configured routes render',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final config = foodioPanel();
      await tester.pumpWidget(BeakPanel(config: config, dataSource: source));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Full panel bootstrap');
      final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
      Future<void> route(String path) async {
        router.go(path);
        await tester.pumpAndSettle();
        if (find.text('Discard changes').evaluate().isNotEmpty) {
          await tester.tap(find.text('Discard changes').last);
          await tester.pumpAndSettle();
        } else if (find.text('Leave this form?').evaluate().isNotEmpty) {
          await tester.tap(find.text('Leave').last);
          await tester.pumpAndSettle();
        }
        // SQLite reads can finish between frames without scheduling another
        // frame while the reduced-motion loading placeholder is visible.
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
        expect(find.text('Loading…'), findsNothing, reason: path);
        expect(router.routeInformationProvider.value.uri.path, path);
        expect(tester.takeException(), isNull, reason: path);
        expect(
          find.textContaining('Invalid default'),
          findsNothing,
          reason: path,
        );
      }

      await route('/orders/create');
      expect(find.text('Customer & profile'), findsWidgets);
      await route('/orders/${FoodioIds.order(24817)}');
      expect(find.text('Back'), findsNothing);
      expect(find.text('Edit order'), findsOneWidget);
      expect(
        tester
            .widget<OiButton>(
              find.byWidgetPredicate(
                (widget) => widget is OiButton && widget.label == 'Edit order',
              ),
            )
            .variant,
        OiButtonVariant.primary,
      );
      expect(find.text('Add note'), findsWidgets);
      expect(find.text('New internal note'), findsWidgets);
      final addNote = find.text('Add note').last;
      await tester.ensureVisible(addNote);
      await tester.tap(addNote);
      await tester.pumpAndSettle();
      expect(find.byType(OiDialog), findsNothing);
      expect(tester.takeException(), isNull, reason: 'Inline note validation');
      await route('/orders/${FoodioIds.order(24802)}');
      await tester.tap(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is OiButton && widget.semanticLabel == 'More actions',
            )
            .last,
      );
      await tester.pumpAndSettle();
      final redelivery = find.text('Schedule redelivery').first;
      await tester.ensureVisible(redelivery);
      await tester.tap(redelivery);
      await tester.pumpAndSettle();
      expect(find.text('New delivery date'), findsWidgets);
      expect(find.text(OrderRelations.slot.label), findsWidgets);
      expect(tester.takeException(), isNull, reason: 'Redelivery arguments');
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      for (final resource in config.resources.where(
        (resource) => resource.model.table != 'orders',
      )) {
        if (resource.canCreate) await route('/${resource.model.table}/create');
        final records = await source.query(
          resource.model.query(pagination: const BeakPagination(perPage: 1)),
        );
        if (records.items.isNotEmpty) {
          await route(
            '/${resource.model.table}/${resource.model.primaryKeyOf(records.items.first)}',
          );
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
