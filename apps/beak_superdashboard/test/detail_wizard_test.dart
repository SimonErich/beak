import 'package:beak_core/beak_core.dart';
import 'package:beak_superdashboard/models/models.dart';
import 'package:beak_test/beak_test.dart';
import 'package:beak_superdashboard/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

/// The product the show and edit pages render, seeded into a real in-memory
/// source so the pages' relation-loaded query answers the same way the API
/// would.
BeakDataSource productSource() {
  final BeakModelRegistry registry = app
      .buildSuperdashboardConfig()
      .buildRegistry();
  return InMemoryBeakDataSource(registry: registry)
    ..seed(const ProductModel(), [
      BeakRecord.fromRow(const {
        'id': 'p1',
        'name': 'Wireless mouse',
        'sku': 'WM-001',
        'status': 'active',
        'price': 29.9,
        'cost': 12.0,
        'stock': 42,
      }),
    ]);
}

void main() {
  Future<GoRouter> boot(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app.SuperdashboardApp(dataSource: productSource()));
    await tester.pumpAndSettle();
    return GoRouter.of(tester.element(find.byType(OiAppShell)));
  }

  testWidgets('a product show page renders its structured detail layout', (
    tester,
  ) async {
    final router = await boot(tester);
    router.go('/products/p1');
    await tester.pumpAndSettle();

    // The headline card, grouped field labels/values, and the tabbed
    // relations section from the shared product layout.
    expect(find.text('Product'), findsWidgets);
    expect(find.text('Name'), findsWidgets);
    expect(find.text('Wireless mouse'), findsWidgets);
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Variants'), findsWidgets);
    tester.takeException();
  });

  testWidgets('a product edit page renders the same layout as a form', (
    tester,
  ) async {
    final router = await boot(tester);
    router.go('/products/p1/edit');
    await tester.pumpAndSettle();

    // The shared layout's cards structure the form (Overview card present),
    // and the form chrome — a Save button — renders below it.
    expect(find.byType(OiCard), findsWidgets);
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Save'), findsWidgets);
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
