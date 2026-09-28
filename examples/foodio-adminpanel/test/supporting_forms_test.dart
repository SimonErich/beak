import 'package:beak/migrations.dart';
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodio_adminpanel/beak/registry.g.dart';
import 'package:foodio_adminpanel/models/models.dart';
import 'package:foodio_adminpanel/resources/finance/finance_resources.dart';
import 'package:foodio_adminpanel/resources/operations/operations_resources.dart';
import 'package:foodio_adminpanel/resources/people/people_resources.dart';

void main() {
  final registry = buildBeakRegistry();
  BeakFormLayout layout(BeakResource resource) =>
      (resource.screenFor(BeakScreenRole.create)! as BeakFormScreen).layout!;

  test(
    'customer form derives identity and enrollment without duplicate fields',
    () async {
      final resource = peopleResources().firstWhere(
        (resource) => resource.model.table == 'customers',
      );
      final session = BeakFormSession(
        model: resource.model,
        dataSource: WormDataSource(registry, adapter: InMemoryAdapter()),
        registry: registry,
        layout: layout(resource),
      );
      addTearDown(session.dispose);
      session.root.set(CustomerModel.firstName, 'Sofia');
      session.root.set(CustomerModel.lastName, 'Huber');
      session.root.set(CustomerModel.email, 'sofia@example.test');
      expect(session.root.read(CustomerModel.name), 'Sofia Huber');
      expect(
        session.root.read(CustomerModel.joinedAt),
        DateTime.utc(2026, 9, 28, 7, 42),
      );
      expect(
        await session.validate(),
        isTrue,
        reason: '${session.root.errors}',
      );
      expect(session.root.buildRecord().values, isNot(contains('name')));
    },
  );

  for (final resource in [
    ...peopleResources(),
    ...financeResources(),
    ...operationsResources(),
  ]) {
    testWidgets('${resource.model.table} has a usable configured form', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakConfiguredForm(
            model: resource.model,
            registry: registry,
            dataSource: WormDataSource(registry, adapter: InMemoryAdapter()),
            layout: layout(resource),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (resource.model.table == 'notifications') {
        expect(find.text('Read'), findsWidgets);
      } else {
        expect(find.byType(EditableText), findsWidgets);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
