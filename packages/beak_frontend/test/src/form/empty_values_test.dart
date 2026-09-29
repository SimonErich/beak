import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

const _title = BeakScalarField<String>(
  model: ArticleModel(),
  column: ArticleColumns.title,
);
const _categoryName = BeakScalarField<String>(
  model: ArticleModel(),
  column: BeakStringColumn(key: 'name', label: 'Category name'),
  path: [ArticleRelations.category],
);
const _category = BeakToOneField(
  model: ArticleModel(),
  relation: ArticleRelations.category,
  target: _CategoryModel(),
);

/// The empty-value text the tests ask for, so a stray hard-coded dash shows.
const _empty = BeakFormatting(emptyValue: 'n/a');

Future<void> _pumpRead(WidgetTester tester, BeakFormLayout layout) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    OiApp(
      theme: OiThemeData.light(),
      home: BeakFormattingScope(
        formatting: _empty,
        child: BeakConfiguredForm(
          model: const ArticleModel(),
          dataSource: FakeDataSource(
            models: const [ArticleModel(), _CategoryModel()],
            records: {
              'articles': {
                'a1': BeakRecord.fromRow({'id': 'a1', 'title': 'Lonely'}),
              },
            },
          ),
          recordId: 'a1',
          mode: BeakFormMode.read,
          canEdit: false,
          layout: layout,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty to-one relation reads like an empty scalar', (
    tester,
  ) async {
    await _pumpRead(
      tester,
      BeakFormLayout(
        children: [
          _title.input(),
          const BeakRelationInput(field: _category),
          const BeakInput<Object>(field: ArticleColumnsRefs.summary),
        ],
      ),
    );

    expect(find.text('Lonely'), findsOneWidget);
    expect(find.text('Category: n/a'), findsOneWidget);
    expect(find.text('n/a'), findsOneWidget);
  });

  testWidgets('a related field of a missing record shows the empty value', (
    tester,
  ) async {
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakFormattingScope(
          formatting: _empty,
          child: Builder(
            builder: (context) => renderBeakField(
              context,
              field: _categoryName,
              record: BeakRecord.fromRow({'id': 'a1'}),
            ),
          ),
        ),
      ),
    );

    expect(find.text('n/a'), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });
}

/// Typed references for the fixture columns the tests place.
abstract final class ArticleColumnsRefs {
  static const summary = BeakScalarField<Object>(
    model: ArticleModel(),
    column: ArticleColumns.summary,
  );
}

final class _CategoryModel extends BeakModel {
  const _CategoryModel();

  @override
  String get table => 'categories';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];
}
