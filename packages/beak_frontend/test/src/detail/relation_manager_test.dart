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

    testWidgets('deleting a child asks first, then reloads the list', (
      tester,
    ) async {
      await pumpManager(tester, ArticleRelations.comments);

      _tapTrash(tester);
      await tester.pumpAndSettle();
      expect(find.text('Delete this record?'), findsOneWidget);
      expect(dataSource.deleteCalls, isEmpty, reason: 'nothing before the yes');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(dataSource.deleteCalls, isEmpty, reason: 'cancel keeps the row');
      expect(find.text('First!'), findsOneWidget);

      _tapTrash(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(dataSource.deleteCalls, [('comments', 'k1', false)]);
      expect(find.text('First!'), findsNothing);
      expect(find.text('No comments yet.'), findsOneWidget);
    });

    testWidgets('a refused delete says why and keeps the row', (tester) async {
      dataSource = _Refusing(
        records: {
          'comments': {
            'k1': BeakRecord.fromRow(const {
              'id': 'k1',
              'text': 'First!',
              'article_id': 'a1',
            }),
          },
        },
      )..refuseWrites = const BeakAuthorizationException('Not your comment.');
      await pumpManager(tester, ArticleRelations.comments);

      _tapTrash(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Not your comment.'), findsOneWidget);
      expect(find.text('First!'), findsOneWidget);
      await _drainToasts(tester);
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

  group('a failure is never shown as an empty list', () {
    testWidgets('a failed read says so and retries', (tester) async {
      final source = _Refusing(
        records: {
          'comments': {
            'k1': BeakRecord.fromRow(const {
              'id': 'k1',
              'text': 'First!',
              'article_id': 'a1',
            }),
          },
        },
      )..refuseReads = const BeakStorageException('disk detail');
      dataSource = source;
      await pumpManager(tester, ArticleRelations.comments);

      expect(
        find.text('The operation could not be completed.'),
        findsOneWidget,
      );
      expect(find.textContaining('disk detail'), findsNothing);
      expect(find.text('No comments yet.'), findsNothing);

      source.refuseReads = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('First!'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a refused detach says why', (tester) async {
      dataSource = _Refusing(
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
      )..refuseWrites = const BeakAuthorizationException('Tags are locked.');
      await pumpManager(tester, ArticleRelations.tags);

      final OiButton detach = tester.widget(
        find.byWidgetPredicate(
          (widget) => widget is OiButton && widget.semanticLabel == 'Detach',
        ),
      );
      detach.onTap!();
      await tester.pumpAndSettle();

      expect(find.text('Tags are locked.'), findsOneWidget);
      await _drainToasts(tester);
    });
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

/// Lets the toast queue empty, so no toast leaks into the next test (the
/// queue is process-wide).
Future<void> _drainToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void _tapTrash(WidgetTester tester) {
  final OiButton trash = tester.widget(
    find.byWidgetPredicate(
      (widget) => widget is OiButton && widget.semanticLabel == 'Delete',
    ),
  );
  trash.onTap!();
}

/// A source that can be told to refuse its reads or its relationship writes.
final class _Refusing extends FakeDataSource {
  _Refusing({required super.records});

  BeakException? refuseReads;
  BeakException? refuseWrites;

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    if (refuseReads case final BeakException failure) throw failure;
    return super.query(spec);
  }

  @override
  Future<void> delete(String table, Object id, {bool force = false}) async {
    if (refuseWrites case final BeakException failure) throw failure;
    return super.delete(table, id, force: force);
  }

  @override
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async {
    if (refuseWrites case final BeakException failure) throw failure;
    return super.detach(table, id, relationKey, relatedIds);
  }
}
