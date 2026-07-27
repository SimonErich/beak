import 'package:beak/beak.dart';
import 'package:superdashboard/beak/app.g.dart';
import 'package:superdashboard/beak/panel.g.dart';
import 'package:superdashboard/beak/registry.g.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:beak/ui.dart';

void main() {
  group('superdashboard panel', () {
    test('registers every resource and the custom dashboard page', () {
      final config = buildBeakPanel();

      expect(config.title, 'Beak Superdashboard');
      expect(config.apiBaseUrl, 'http://localhost:8180');
      // 17 of the 49 models earn a sidebar entry; the rest are reached
      // through the resource or screen that owns them, and keep their API.
      expect(config.resources, hasLength(17));
      expect(config.buildRegistry().all, hasLength(17));
      expect(beakModels, hasLength(49));
      expect(buildBeakRegistry().all, hasLength(49));
      expect(
        config.pages.map((page) => page.path),
        containsAll(<String>[
          '/',
          '/email',
          '/chat',
          '/files',
          '/invoice',
          '/profile',
          '/pricing',
          '/faq',
          '/charts',
          '/gallery',
          '/ui-kit',
          '/typography',
          '/icons',
          '/maps',
          '/starter',
        ]),
      );
      expect(config.auth, isNotNull);
      expect(config.maintenance, isNotNull);
    });

    testWidgets('boots the shell and renders the dashboard at /', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1600, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(BeakApp(dataSource: _EmptyDataSource()));
      await tester.pumpAndSettle();

      expect(find.byType(OiAppShell), findsOneWidget);
      expect(find.text('Total earnings'), findsWidgets);
      tester.takeException();
    });

    testWidgets('navigates to every custom app page without crashing', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1600, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(BeakApp(dataSource: _EmptyDataSource()));
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(OiAppShell)));

      for (final path in const [
        '/email',
        '/chat',
        '/files',
        '/invoice',
        '/profile',
        '/pricing',
        '/faq',
        '/charts',
        '/gallery',
        '/ui-kit',
        '/typography',
        '/icons',
        '/maps',
        '/starter',
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(find.byType(OiAppShell), findsOneWidget, reason: 'at $path');
        tester.takeException();
      }
    });
  });
}

/// An empty in-memory data source so widget tests never touch a network.
final class _EmptyDataSource implements BeakDataSource {
  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async => BeakPage(
    items: const [],
    total: 0,
    page: spec.pagination.page,
    perPage: spec.pagination.perPage,
  );

  @override
  Future<BeakRecord?> getOne(String table, Object id) async => null;

  @override
  Future<BeakRecord> create(String table, BeakRecord data) async => data;

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) async =>
      data;

  @override
  Future<void> delete(String table, Object id, {bool force = false}) async {}

  @override
  Future<BeakRecord> restore(String table, Object id) async =>
      const BeakRecord(values: {});

  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) async =>
      const [];

  @override
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async {}

  @override
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async {}

  @override
  Future<num> aggregate(BeakAggregateSpec spec) async => 0;
}
