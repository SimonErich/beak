import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcase/main.dart';
import 'package:showcase/resources/keepers/models/keeper.dart';
import 'package:showcase/resources/specimens/models/specimen.dart';
import 'package:showcase/seeders/aviary_ids.dart';
import 'package:showcase/widgets/band_code_cell.dart';

import 'support/aviary_pump.dart';

void main() {
  setUp(registerAviaryRenderers);
  tearDown(BeakCustomRenderers.reset);

  final BeakPanel panel = buildPanel();
  for (final resource in panel.resources) {
    testWidgets('${resource.title} lists its records', (tester) async {
      await pumpAviaryAt(tester, BeakRoutes.list(resource.model.table));

      expect(tester.takeException(), isNull);
      expect(find.byType(OiTable<BeakRecord>), findsOneWidget);
    });
  }

  testWidgets('the keeper read screen composes record blocks', (tester) async {
    await pumpAviaryAt(
      tester,
      BeakRoutes.show(const KeeperModel().table, AviaryIds.ada),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Ada Wing'), findsOneWidget);
    expect(find.text('ada@aviary.example'), findsOneWidget);
    expect(find.text('Looks after the Canopy.'), findsOneWidget);
    expect(find.text('Habitats'), findsWidgets);
  });

  const specimen = SpecimenModel();
  // Identity, the foreign key the relation picker stands for, and the
  // timestamps: the framework maintains them, so no page labels them.
  const bookkeeping = [
    SpecimenColumns.id,
    SpecimenColumns.habitatId,
    SpecimenColumns.createdAt,
    SpecimenColumns.updatedAt,
    SpecimenColumns.deletedAt,
  ];
  for (final (name, location, context) in [
    ('create form', BeakRoutes.create('specimens'), BeakContext.form),
    ('edit form', BeakRoutes.edit('specimens', 'specimen-0'), BeakContext.form),
    (
      'detail page',
      BeakRoutes.show('specimens', 'specimen-0'),
      BeakContext.detail,
    ),
  ]) {
    testWidgets('the specimen $name labels every column it shows', (
      tester,
    ) async {
      await pumpAviaryAt(tester, location);

      expect(tester.takeException(), isNull);
      final labelled = [
        for (final column in specimen.columns)
          if (column.visibleOn.contains(context) &&
              !bookkeeping.contains(column) &&
              column is! BeakCustomColumn)
            column.label,
      ];
      expect(labelled, hasLength(greaterThan(15)));
      for (final label in labelled) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    });
  }

  testWidgets('a custom column draws with the renderer the app registered', (
    tester,
  ) async {
    await pumpAviaryAt(tester, BeakRoutes.list('specimens'));

    expect(find.text('AV-1000'), findsOneWidget);
  });
}
