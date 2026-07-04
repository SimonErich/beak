import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;
  late BeakFormController controller;

  setUp(() {
    dataSource = FakeDataSource(
      records: {
        'categories': {
          'c1': BeakRecord.fromRow(const {'id': 'c1', 'name': 'News'}),
          'c2': BeakRecord.fromRow(const {'id': 'c2', 'name': 'Sports'}),
        },
        'tags': {
          't1': BeakRecord.fromRow(const {'id': 't1', 'name': 'hot'}),
          't2': BeakRecord.fromRow(const {'id': 't2', 'name': 'new'}),
        },
        'articles': {
          'a1': const BeakRecord(
            values: {'id': BeakStringValue('a1')},
            relations: {
              'tags': [
                BeakRecord(
                  values: {
                    'id': BeakStringValue('t1'),
                    'name': BeakStringValue('hot'),
                  },
                ),
              ],
            },
          ),
        },
      },
    );
    controller = BeakFormController(model: const ArticleModel());
    addTearDown(controller.dispose);
  });

  group('BeakBelongsToField', () {
    Future<OiComboBox<BeakRecord>> pumpPicker(WidgetTester tester) async {
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakBelongsToField(
            controller: controller,
            relation: ArticleRelations.category,
            dataSource: dataSource,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.widget(find.byType(OiComboBox<BeakRecord>));
    }

    testWidgets('searches the related table by the search columns', (
      tester,
    ) async {
      final picker = await pumpPicker(tester);

      final List<BeakRecord> options = await picker.search!('New');

      expect(options, hasLength(2));
      expect(dataSource.queryCalls, hasLength(1));
      final BeakQuerySpec spec = dataSource.queryCalls.single;
      expect(spec.table, 'categories');
      expect(spec.search?.term, 'New');
      expect(spec.search?.columnKeys, ['name']);
    });

    testWidgets('an empty query lists without a search directive', (
      tester,
    ) async {
      final picker = await pumpPicker(tester);

      await picker.search!('  ');

      expect(dataSource.queryCalls.single.search, isNull);
    });

    testWidgets('selecting stores the foreign key; clearing removes it', (
      tester,
    ) async {
      final picker = await pumpPicker(tester);

      picker.onSelect!(
        BeakRecord.fromRow(const {'id': 'c2', 'name': 'Sports'}),
      );
      expect(controller.valueOf<Object>(ArticleColumns.categoryId), 'c2');

      picker.onSelect!(null);
      expect(controller.valueOf<Object>(ArticleColumns.categoryId), isNull);
    });

    testWidgets('resolves a prefilled foreign key into its record label', (
      tester,
    ) async {
      controller.setValue(ArticleColumns.categoryId, 'c1');

      await pumpPicker(tester);

      expect(find.text('News'), findsWidgets);
    });
  });

  group('BeakBelongsToManyField', () {
    Future<OiComboBox<BeakRecord>> pumpPicker(WidgetTester tester) async {
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakBelongsToManyField(
            model: const ArticleModel(),
            parentId: 'a1',
            relation: ArticleRelations.tags,
            dataSource: dataSource,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.widget(find.byType(OiComboBox<BeakRecord>));
    }

    testWidgets('seeds the selection with the attached records', (
      tester,
    ) async {
      final picker = await pumpPicker(tester);

      expect(picker.multiSelect, isTrue);
      expect(picker.selectedValues, hasLength(1));
      expect(
        picker.selectedValues.single['name'],
        const BeakStringValue('hot'),
      );
      final BeakQuerySpec loadSpec = dataSource.queryCalls.single;
      expect(loadSpec.table, 'articles');
      expect(loadSpec.relationLoads.single.relationKey, 'tags');
    });

    testWidgets('growing the selection attaches the new ids', (tester) async {
      final picker = await pumpPicker(tester);

      picker.onMultiSelect!([
        BeakRecord.fromRow(const {'id': 't1', 'name': 'hot'}),
        BeakRecord.fromRow(const {'id': 't2', 'name': 'new'}),
      ]);
      await tester.pumpAndSettle();

      expect(dataSource.attachCalls, hasLength(1));
      final (String table, Object id, String relationKey, List<Object> ids) =
          dataSource.attachCalls.single;
      expect(table, 'articles');
      expect(id, 'a1');
      expect(relationKey, 'tags');
      expect(ids, ['t2']);
      expect(dataSource.detachCalls, isEmpty);
    });

    testWidgets('shrinking the selection detaches the removed ids', (
      tester,
    ) async {
      final picker = await pumpPicker(tester);

      picker.onMultiSelect!(const []);
      await tester.pumpAndSettle();

      expect(dataSource.detachCalls, hasLength(1));
      final (String table, Object id, String relationKey, List<Object> ids) =
          dataSource.detachCalls.single;
      expect(table, 'articles');
      expect(id, 'a1');
      expect(relationKey, 'tags');
      expect(ids, ['t1']);
      expect(dataSource.attachCalls, isEmpty);
    });

    testWidgets('a rejected detach reverts the optimistic selection', (
      tester,
    ) async {
      final failing = _DetachFailsSource(
        records: {
          'tags': {
            't1': BeakRecord.fromRow(const {'id': 't1', 'name': 'hot'}),
          },
          'articles': {
            'a1': const BeakRecord(
              values: {'id': BeakStringValue('a1')},
              relations: {
                'tags': [
                  BeakRecord(
                    values: {
                      'id': BeakStringValue('t1'),
                      'name': BeakStringValue('hot'),
                    },
                  ),
                ],
              },
            ),
          },
        },
      );
      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakBelongsToManyField(
            model: const ArticleModel(),
            parentId: 'a1',
            relation: ArticleRelations.tags,
            dataSource: failing,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final picker = tester.widget<OiComboBox<BeakRecord>>(
        find.byType(OiComboBox<BeakRecord>),
      );
      picker.onMultiSelect!(const []);
      await tester.pumpAndSettle();

      final reverted = tester.widget<OiComboBox<BeakRecord>>(
        find.byType(OiComboBox<BeakRecord>),
      );
      expect(failing.detachCalls, hasLength(1));
      expect(
        reverted.selectedValues,
        hasLength(1),
        reason: 'a rejected detach must not leave the row visually detached',
      );
      expect(
        reverted.selectedValues.single['name'],
        const BeakStringValue('hot'),
      );
    });
  });
}

/// A fake whose detach always fails, to pin optimistic-revert behavior.
final class _DetachFailsSource extends FakeDataSource {
  _DetachFailsSource({super.records});

  @override
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async {
    detachCalls.add((table, id, relationKey, relatedIds));
    throw const BeakStorageException('detach rejected');
  }
}
