import 'package:beak_core/beak_core.dart';
import 'package:beak_superdashboard/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  group('superdashboard scaffold', () {
    test('builds a panel config with the demo title', () {
      final config = app.buildSuperdashboardConfig();

      expect(config.title, 'Beak Superdashboard');
      expect(config.apiBaseUrl, 'http://localhost:8080');
      expect(config.buildRegistry().all, isEmpty);
    });

    testWidgets('boots the obers_ui shell', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        app.SuperdashboardApp(dataSource: _EmptyDataSource()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OiAppShell), findsOneWidget);
      expect(find.text('Beak Superdashboard'), findsWidgets);
    });

    testWidgets('the entry point boots the real app', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // The panel has no resources yet, so the default (dashboard) route
      // issues no queries — booting the real HTTP-backed app touches no
      // network and settles immediately.
      app.main();
      await tester.pumpAndSettle();

      expect(find.byType(OiAppShell), findsOneWidget);
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
