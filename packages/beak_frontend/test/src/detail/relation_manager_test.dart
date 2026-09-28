import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

void main() {
  late FakeDataSource dataSource;

  setUp(() {
    dataSource = FakeDataSource(
      records: {
        'comments': {
          'k1': BeakRecord.fromRow(const {
            'id': 'k1',
            'text': 'First!',
            'article_id': 'a1',
          }),
        },
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
  });

  Future<void> pumpManager(
    WidgetTester tester,
    BeakRelationship relationship, {
    VoidCallback? onCreateRequested,
  }) async {
    await tester.pumpWidget(
      OiApp(
        theme: OiThemeData.light(),
        home: BeakRelationManager(
          parentModel: const ArticleModel(),
          parentId: 'a1',
          relationship: relationship,
          dataSource: dataSource,
          onCreateRequested: onCreateRequested,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('has-many', () {
    testWidgets('lists the children filtered by the foreign key', (
      tester,
    ) async {
      await pumpManager(tester, ArticleRelations.comments);

      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('First!'), findsOneWidget);
      final BeakQuerySpec spec = dataSource.queryCalls.single;
      expect(spec.table, 'comments');
      final BeakFieldFilter filter = switch (spec.filter) {
        final BeakFieldFilter field => field,
        final Object? other => fail('Expected a field filter, got $other.'),
      };
      expect(filter.columnKey, 'article_id');
      expect(filter.value, const BeakStringValue('a1'));
    });

    testWidgets('deleting a child reloads the list', (tester) async {
      await pumpManager(tester, ArticleRelations.comments);

      final OiButton deleteButton = tester.widget(
        find.byWidgetPredicate(
          (widget) => widget is OiButton && widget.semanticLabel == 'Delete',
        ),
      );
      deleteButton.onTap!();
      await tester.pumpAndSettle();

      expect(dataSource.deleteCalls, [('comments', 'k1', false)]);
      expect(find.text('First!'), findsNothing);
      expect(find.text('No comments yet.'), findsOneWidget);
    });

    testWidgets('surfaces the create hook', (tester) async {
      var createRequested = false;
      await pumpManager(
        tester,
        ArticleRelations.comments,
        onCreateRequested: () => createRequested = true,
      );

      await tester.tap(find.text('Create'));
      expect(createRequested, isTrue);
    });
  });

  group('belongs-to-many', () {
    testWidgets('lists the attached records and detaches on demand', (
      tester,
    ) async {
      await pumpManager(tester, ArticleRelations.tags);

      expect(find.text('hot'), findsOneWidget);

      final OiButton detachButton = tester.widget(
        find.byWidgetPredicate(
          (widget) => widget is OiButton && widget.semanticLabel == 'Detach',
        ),
      );
      detachButton.onTap!();
      await tester.pumpAndSettle();

      expect(dataSource.detachCalls, hasLength(1));
      final (String table, Object id, String relationKey, List<Object> ids) =
          dataSource.detachCalls.single;
      expect((table, id, relationKey), ('articles', 'a1', 'tags'));
      expect(ids, ['t1']);
    });

    testWidgets('attaching through the picker links the selection', (
      tester,
    ) async {
      await pumpManager(tester, ArticleRelations.tags);

      final OiComboBox<BeakRecord> picker = tester.widget(
        find.byType(OiComboBox<BeakRecord>),
      );
      picker.onSelect!(BeakRecord.fromRow(const {'id': 't9', 'name': 'cold'}));
      await tester.pumpAndSettle();

      expect(dataSource.attachCalls, hasLength(1));
      final (String table, Object id, String relationKey, List<Object> ids) =
          dataSource.attachCalls.single;
      expect((table, id, relationKey), ('articles', 'a1', 'tags'));
      expect(ids, ['t9']);
    });
  });

  testWidgets('a to-one relationship renders a configuration notice', (
    tester,
  ) async {
    await pumpManager(tester, ArticleRelations.category);

    expect(find.text('Unavailable'), findsOneWidget);
  });

  group('paging', () {
    testWidgets('the badge counts what exists, and more can be loaded', (
      tester,
    ) async {
      final source = FakeDataSource(
        records: {
          'comments': {
            for (var index = 1; index <= 5; index += 1)
              'c$index': BeakRecord.fromRow({
                'id': 'c$index',
                'text': 'Comment $index',
                'article_id': 'a1',
              }),
          },
          'articles': {
            'a1': BeakRecord.fromRow(const {'id': 'a1'}),
          },
        },
      );

      await tester.pumpWidget(
        OiApp(
          theme: OiThemeData.light(),
          home: BeakRelationManager(
            parentModel: const ArticleModel(),
            parentId: 'a1',
            relationship: ArticleRelations.comments,
            dataSource: source,
            pageSize: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Two rows of five, and the badge says five — not two.
      expect(find.text('Comment 1'), findsOneWidget);
      expect(find.text('Comment 3'), findsNothing);
      expect(find.text('5'), findsOneWidget);

      await tester.tap(find.text('Load more (3)'));
      await tester.pumpAndSettle();

      expect(find.text('Comment 3'), findsOneWidget);
      expect(find.text('Comment 5'), findsNothing);
    });
  });
}
