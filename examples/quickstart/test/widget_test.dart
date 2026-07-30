import 'package:beak/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quickstart/beak/app.g.dart';
import 'package:quickstart/beak/registry.g.dart';

void main() {
  testWidgets('the panel boots with every declared model registered', (
    tester,
  ) async {
    // An empty in-memory source: the panel renders its empty states, and
    // seeding one is `source.seed(const NoteModel(), [record])`.
    final source = InMemoryBeakDataSource(registry: buildBeakRegistry());
    await tester.pumpWidget(BeakApp(dataSource: source));
    await tester.pumpAndSettle();

    expect(beakModels, isNotEmpty, reason: 'no model was discovered');
    for (final model in beakModels) {
      expect(
        buildBeakRegistry().byTable(model.table),
        isNotNull,
        reason: '${model.table} is not registered',
      );
    }
  });
}
