import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:reference_admin/main.dart';
import 'package:reference_admin_models/reference_admin_models.dart';

void main() {
  group('panel configuration', () {
    test('exposes every shared model as a resource', () {
      final config = buildReferencePanelConfig();

      expect(config.resources.map((resource) => resource.model.table), [
        'products',
        'categories',
        'tags',
        'users',
        'orders',
        'order_items',
      ]);
      expect(config.dashboardStats, hasLength(3));
      expect(config.dashboardCharts, hasLength(1));
      expect(config.buildRegistry().all, hasLength(6));
    });

    test('the chart mapper turns product records into typed points', () {
      final points = stockPerProduct([
        BeakRecord.fromRow(const {'name': 'Beans', 'stock': 42}),
        BeakRecord.fromRow(const {'name': 'Grinder'}),
      ]);

      expect(points.first.label, 'Beans');
      expect(points.first.value, 42.0);
      expect(points.last.value, 0.0);
    });
  });

  group('boot', () {
    testWidgets('renders the shell with one nav item per resource', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ReferenceAdminApp(dataSource: _EmptyDataSource()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OiAppShell), findsOneWidget);
      expect(find.text('Products'), findsWidgets);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Beak Admin'), findsWidgets);
    });

    testWidgets('renders no Material or Cupertino widgets', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ReferenceAdminApp(dataSource: _EmptyDataSource()),
      );
      await tester.pumpAndSettle();

      const banned = {
        'Material',
        'Scaffold',
        'AppBar',
        'ElevatedButton',
        'TextField',
        'CupertinoApp',
        'CupertinoPageScaffold',
        'MaterialApp',
      };
      final offenders = tester.allWidgets
          .where((widget) => banned.contains(widget.runtimeType.toString()))
          .toList();
      expect(offenders, isEmpty, reason: 'obers_ui only — no Material');
    });

    testWidgets('the duplicate escape hatch copies through the source', (
      tester,
    ) async {
      final source = _EmptyDataSource();
      final record = BeakRecord.fromRow(const {
        'id': 'p1',
        'name': 'Beans',
        'price': 12.5,
        'status': 'published',
      });

      await tester.pumpWidget(ReferenceAdminApp(dataSource: source));
      await tester.pumpAndSettle();
      final BuildContext context = tester.element(find.byType(OiAppShell));
      await duplicateProduct(
        record,
        BeakActionContext(
          buildContext: context,
          model: const ProductModel(),
          dataSource: source,
          router: GoRouter.of(context),
        ),
      );

      expect(source.created, hasLength(1));
      final (String table, BeakRecord copy) = source.created.single;
      expect(table, 'products');
      expect(copy['name'], const BeakStringValue('Beans (copy)'));
      expect(copy['price'], const BeakDoubleValue(12.5));
    });
  });
}

/// An empty in-memory data source so widget tests never touch a network.
final class _EmptyDataSource implements BeakDataSource {
  final List<(String, BeakRecord)> created = [];

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
  Future<BeakRecord> create(String table, BeakRecord data) async {
    created.add((table, data));
    return data;
  }

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
