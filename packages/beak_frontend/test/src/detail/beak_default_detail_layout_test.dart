import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart';

import '../../support/panel_fixtures.dart';

/// The articles fixture with the columns and relationships one case needs.
///
/// The derived layout is a function of the model, so the cases that differ
/// only in what the model declares vary this instead of adding a fixture per
/// shape.
final class _ArticleVariant extends BeakModel {
  const _ArticleVariant({
    this.columns = ArticleColumns.values,
    this.relationships = const [],
  });

  @override
  final List<BeakColumn> columns;

  @override
  final List<BeakRelationship> relationships;

  @override
  String get table => 'articles';

  @override
  String get displayColumnKey => 'title';
}

void main() {
  const internalNote = BeakStringColumn(
    key: 'internal_note',
    label: 'Internal note',
    visibleOn: {BeakContext.table, BeakContext.form},
  );

  BeakColumnBlock stackOf(BeakBlock block) => switch (block) {
    final BeakColumnBlock stack => stack,
    final BeakBlock other => fail('Expected a column stack, got $other.'),
  };

  BeakColumnBlock stackFor(BeakModel model) =>
      stackOf(beakDefaultDetailLayout(model));

  BeakCardBlock cardOf(BeakBlock block) => switch (block) {
    final BeakCardBlock card => card,
    final BeakBlock other => fail('Expected a card, got $other.'),
  };

  BeakGridBlock gridOf(BeakBlock block) => switch (block) {
    final BeakGridBlock grid => grid,
    final BeakBlock other => fail('Expected a grid, got $other.'),
  };

  BeakTabsBlock tabsOf(BeakBlock block) => switch (block) {
    final BeakTabsBlock tabs => tabs,
    final BeakBlock other => fail('Expected tabs, got $other.'),
  };

  BeakFieldGroupBlock fieldsOf(BeakBlock block) => switch (block) {
    final BeakFieldGroupBlock fields => fields,
    final BeakBlock other => fail('Expected a field group, got $other.'),
  };

  BeakRelationBlock relationOf(BeakBlock block) => switch (block) {
    final BeakRelationBlock relation => relation,
    final BeakBlock other => fail('Expected a relation block, got $other.'),
  };

  List<String> keysOf(BeakBlock block) => [
    for (final column in fieldsOf(block).columns) column.key,
  ];

  test('a model without relationships is a headline card over a grid', () {
    final BeakColumnBlock stack = stackFor(const _ArticleVariant());

    expect(stack.gapInPixels, 20);
    expect(stack.children, hasLength(2));

    final BeakCardBlock headline = cardOf(stack.children.first);
    expect(headline.title, isNull);
    expect(keysOf(headline.child), ['title', 'summary', 'price', 'stock']);
    expect(fieldsOf(headline.child).columnCount, 4);

    final BeakGridBlock grid = gridOf(stack.children[1]);
    expect(grid.columns, 12);
    expect(grid.children, hasLength(2));

    final BeakCardBlock details = cardOf(grid.children.first);
    expect(details.title, 'Details');
    expect(details.span?.columns, 8);
    expect(fieldsOf(details.child).columnCount, 2);
    expect(keysOf(details.child), [
      'active',
      'status',
      'published_at',
      'brand_color',
      'body',
      'meta',
      'avatar',
      'attachment',
    ]);

    final BeakCardBlock more = cardOf(grid.children[1]);
    expect(more.title, 'More');
    expect(more.span?.columns, 4);
    // No relationship claims `category_id` here, so it is just another field.
    expect(keysOf(more.child), ['badge', 'category_id']);
  });

  test('four detail columns or fewer stay in the headline, alone', () {
    final BeakColumnBlock stack = stackFor(const LabelModel());

    expect(stack.children, hasLength(1));
    final BeakCardBlock headline = cardOf(stack.children.single);
    expect(keysOf(headline.child), ['name']);
    expect(fieldsOf(headline.child).columnCount, 1);
  });

  test('the grid stays one wide card until the rest outgrow eight', () {
    const model = _ArticleVariant(
      columns: [
        ArticleColumns.id,
        ArticleColumns.title,
        ArticleColumns.summary,
        ArticleColumns.price,
        ArticleColumns.stock,
        ArticleColumns.active,
      ],
    );

    final BeakGridBlock grid = gridOf(stackFor(model).children[1]);

    expect(grid.children, hasLength(1));
    expect(cardOf(grid.children.single).title, 'Details');
    expect(keysOf(cardOf(grid.children.single).child), ['active']);
  });

  test('a column hidden from the detail context is left out', () {
    const model = _ArticleVariant(
      columns: [
        ArticleColumns.id,
        ArticleColumns.title,
        internalNote,
        ArticleColumns.summary,
      ],
    );

    final BeakColumnBlock stack = stackFor(model);

    expect(stack.children, hasLength(1));
    expect(keysOf(cardOf(stack.children.single).child), ['title', 'summary']);
  });

  test('the primary key and the key a belongs-to owns never show', () {
    final BeakColumnBlock stack = stackFor(const ArticleModel());
    final BeakGridBlock grid = gridOf(stack.children[1]);
    final List<String> shown = [
      ...keysOf(cardOf(stack.children.first).child),
      for (final child in grid.children) ...keysOf(cardOf(child).child),
    ];

    expect(shown, isNot(contains('id')));
    expect(shown, isNot(contains('category_id')));
    expect(shown.first, 'title');
    expect(shown.last, 'badge');
  });

  test('a to-one relationship adds no tab, only hides its key', () {
    const model = _ArticleVariant(relationships: [ArticleRelations.category]);

    final BeakColumnBlock stack = stackFor(model);

    expect(stack.children, hasLength(2));
    expect(stack.children.last, isA<BeakGridBlock>());
    final BeakGridBlock grid = gridOf(stack.children[1]);
    expect(keysOf(cardOf(grid.children[1]).child), ['badge']);
  });

  test('one tab per to-many relationship, in declaration order', () {
    final BeakColumnBlock stack = stackFor(const ArticleModel());

    expect(stack.children, hasLength(3));
    final BeakCardBlock related = cardOf(stack.children.last);
    expect(related.title, 'Related');

    final BeakTabsBlock tabs = tabsOf(related.child);
    expect(tabs.initialIndex, 0);
    expect([for (final tab in tabs.tabs) tab.label], ['Tags', 'Comments']);
    expect(
      [for (final tab in tabs.tabs) relationOf(tab.content).relationship.key],
      ['tags', 'comments'],
    );
  });

  test('a many-to-many gets a tab even when the grid is empty', () {
    final BeakColumnBlock stack = stackFor(const NoteModel());

    expect(stack.children, hasLength(2));
    expect(keysOf(cardOf(stack.children.first).child), ['title']);
    final BeakTabsBlock tabs = tabsOf(cardOf(stack.children.last).child);
    expect(tabs.tabs.single.label, 'Labels');
    expect(relationOf(tabs.tabs.single.content).relationship.key, 'labels');
  });

  group('BeakResource.effectiveDetail', () {
    test('derives the layout when the resource declares no detail', () {
      const resource = BeakResource(
        model: ArticleModel(),
        icon: BeakIconToken(OiIcons.file),
      );

      final BeakColumnBlock stack = stackOf(resource.effectiveDetail);

      expect(stack.children, hasLength(3));
      expect(keysOf(cardOf(stack.children.first).child), [
        'title',
        'summary',
        'price',
        'stock',
      ]);
      expect(
        [
          for (final tab in tabsOf(cardOf(stack.children.last).child).tabs)
            tab.label,
        ],
        ['Tags', 'Comments'],
      );
    });

    test('returns the declared layout when the resource has one', () {
      const detail = BeakCardBlock(child: BeakTextBlock('Hand written'));
      const resource = BeakResource(
        model: ArticleModel(),
        icon: BeakIconToken(OiIcons.file),
        detail: detail,
      );

      expect(resource.effectiveDetail, same(detail));
    });
  });
}
