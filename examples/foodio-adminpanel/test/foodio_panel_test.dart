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

import 'support/gabel_fonts.dart';

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

  const themePreview = BeakScreen(
    path: '/theme-preview',
    title: 'Theme preview',
    icon: BeakIconToken(OiIcons.sun),
    body: BeakTextBlock('Theme preview'),
    showInNav: false,
  );
  const nextPreview = BeakScreen(
    path: '/next-preview',
    title: 'Next preview',
    icon: BeakIconToken(OiIcons.sun),
    body: BeakTextBlock('Next preview'),
    showInNav: false,
  );

  for (final (layout, sizeInPixels) in const [
    ('desktop', Size(1440, 900)),
    ('phone', Size(390, 844)),
    ('landscape', Size(844, 390)),
  ]) {
    testWidgets('theme menu works beside help on $layout', (tester) async {
      await tester.binding.setSurfaceSize(sizeInPixels);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final baseConfig = foodioPanel();
      final config = baseConfig.copyWith(
        initialThemeMode: OiThemeMode.light,
        home: themePreview,
        pages: [...baseConfig.pages, themePreview, nextPreview],
      );
      await tester.pumpWidget(BeakPanel(config: config, dataSource: source));
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(OiAppShell)));
      // A short landscape body stays minimal so table sizing cannot mask
      // whether the shared top bar and its theme menu work.
      final initialPath = layout == 'landscape'
          ? themePreview.path
          : BeakRoutes.list(const AppSettingModel().table);
      final nextPath = layout == 'landscape'
          ? nextPreview.path
          : BeakRoutes.list(const CustomerModel().table);
      router.go(initialPath);
      await tester.pumpAndSettle();

      final themeButton = find.descendant(
        of: find.byType(OiThemeToggle),
        matching: find.byType(OiIconButton),
      );
      final helpButton = find.byWidgetPredicate(
        (widget) =>
            widget is OiButton &&
            widget.semanticLabel == 'Order workspace help',
      );
      expect(themeButton, findsOneWidget);
      final helpRect = tester.getRect(helpButton);
      final themeRect = tester.getRect(themeButton);
      expect(themeRect.center.dy, closeTo(helpRect.center.dy, 1));
      expect(themeRect.left, greaterThanOrEqualTo(helpRect.right));
      expect(themeRect.left - helpRect.right, lessThan(themeRect.width));
      expect(themeRect.right, lessThanOrEqualTo(sizeInPixels.width));

      for (final (mode, label) in const [
        (OiThemeMode.dark, 'Dark mode'),
        (OiThemeMode.light, 'Light mode'),
        (OiThemeMode.system, 'System mode'),
      ]) {
        final pathBefore = router.routeInformationProvider.value.uri.path;
        await tester.tap(themeButton);
        await tester.pumpAndSettle();
        expect(find.text('Light mode'), findsOneWidget);
        expect(find.text('Dark mode'), findsOneWidget);
        expect(find.text('System mode'), findsOneWidget);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(tester.widget<OiApp>(find.byType(OiApp)).themeMode, mode);
        expect(
          OiTheme.of(tester.element(find.byType(OiAppShell))).brightness,
          mode == OiThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        expect(router.routeInformationProvider.value.uri.path, pathBefore);
        expect(find.text('Light mode'), findsNothing);
        expect(find.text('Dark mode'), findsNothing);
        expect(find.text('System mode'), findsNothing);
        expect(tester.takeException(), isNull);

        final destination = pathBefore == initialPath ? nextPath : initialPath;
        router.go(destination);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, destination);
        expect(tester.widget<OiApp>(find.byType(OiApp)).themeMode, mode);
        expect(find.byType(OiThemeToggle), findsOneWidget);
      }
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(
        tester.widget<OiApp>(find.byType(OiApp)).themeMode,
        OiThemeMode.system,
      );
      expect(
        OiTheme.of(tester.element(find.byType(OiAppShell))).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('the complete panel boots and all configured routes render', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final config = foodioPanel();
    await tester.pumpWidget(BeakPanel(config: config, dataSource: source));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Full panel bootstrap');
    expect(find.byType(OiThemeToggle), findsOneWidget);
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
  }, timeout: const Timeout(Duration(minutes: 3)));
}
