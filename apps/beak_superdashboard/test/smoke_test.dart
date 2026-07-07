import 'package:beak_core/beak_core.dart';
import 'package:beak_superdashboard/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  group('superdashboard panel', () {
    test('registers every resource and the custom dashboard page', () {
      final config = app.buildSuperdashboardConfig();

      expect(config.title, 'Beak Superdashboard');
      expect(config.apiBaseUrl, 'http://localhost:8080');
      expect(config.resources, hasLength(17));
      expect(config.buildRegistry().all, hasLength(17));
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

      await tester.pumpWidget(
        app.SuperdashboardApp(dataSource: _EmptyDataSource()),
      );
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

      await tester.pumpWidget(
        app.SuperdashboardApp(dataSource: _EmptyDataSource()),
      );
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
