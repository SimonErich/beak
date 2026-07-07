import 'package:beak_core/beak_core.dart';
import 'package:beak_superdashboard/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

/// A data source that returns one canned product record, so the show page can
/// render its custom detail layout.
final class _ProductDataSource implements BeakDataSource {
  static final _product = BeakRecord.fromRow(const {
    'id': 'p1',
    'name': 'Wireless mouse',
    'sku': 'WM-001',
    'status': 'active',
    'price': 29.9,
    'cost': 12.0,
    'stock': 42,
  });

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async => BeakPage(
    items: const [],
    total: 0,
    page: 1,
    perPage: spec.pagination.perPage,
  );

  @override
  Future<BeakRecord?> getOne(String table, Object id) async =>
      table == 'products' ? _product : null;

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

void main() {
  Future<GoRouter> boot(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app.SuperdashboardApp(dataSource: _ProductDataSource()),
    );
    await tester.pumpAndSettle();
    return GoRouter.of(tester.element(find.byType(OiAppShell)));
  }

  testWidgets('a product show page renders its structured detail layout', (
    tester,
  ) async {
    final router = await boot(tester);
    router.go('/products/p1');
    await tester.pumpAndSettle();

    // The headline card and grouped field labels/values from productDetail.
    expect(find.text('Product'), findsWidgets);
    expect(find.text('Name'), findsWidgets);
    expect(find.text('Wireless mouse'), findsWidgets);
    expect(find.text('Details'), findsWidgets);
    tester.takeException();
  });

  testWidgets('the calendar-event create page renders as a wizard', (
    tester,
  ) async {
    final router = await boot(tester);
    router.go('/calendar_events/create');
    await tester.pumpAndSettle();

    expect(find.byType(OiWizard), findsOneWidget);
    tester.takeException();
  });
}
