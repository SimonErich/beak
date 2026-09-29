import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_frontend/src/pages/beak_default_show_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/panel_fixtures.dart';

void main() {
  BeakModelRegistry registryOf(List<BeakModel> models) {
    final registry = BeakModelRegistry();
    models.forEach(registry.register);
    return registry;
  }

  List<BeakTab> tabsOf(BeakFormLayout layout) => [
    for (final child in layout.children)
      if (child is BeakCard)
        for (final inner in child.children)
          if (inner is BeakTabs) ...inner.tabs,
  ];

  test('a model without to-many relationships is one card of inputs', () {
    final layout = beakDefaultShowLayout(const LabelModel());

    expect(layout.children, [
      isA<BeakCard>().having((card) => card.children, 'children', isNotEmpty),
    ]);
    expect(tabsOf(layout), isEmpty);
  });

  test('each to-many relationship with a known target gets a tab', () {
    final layout = beakDefaultShowLayout(
      const ArticleModel(),
      registry: registryOf(const [
        ArticleModel(),
        _TagModel(),
        _CommentModel(),
      ]),
    );

    expect(tabsOf(layout).map((tab) => tab.title), ['Tags', 'Comments']);
  });

  test('a relationship whose target is not registered is left out', () {
    final layout = beakDefaultShowLayout(
      const ArticleModel(),
      registry: registryOf(const [ArticleModel(), _TagModel()]),
    );

    expect(tabsOf(layout).map((tab) => tab.title), ['Tags']);
  });

  test('related rows list the first useful columns only', () {
    final layout = beakDefaultShowLayout(
      const ArticleModel(),
      registry: registryOf(const [ArticleModel(), _CommentModel()]),
    );

    final table = tabsOf(
      layout,
    ).single.children.whereType<BeakRelationTable>().single;
    final listed = [
      for (final node in table.children)
        if (node is BeakInput<Object>) node.field.key,
    ];
    // The identity (the display column), the key and the pointer back at the
    // article are not repeated as cells.
    expect(listed, ['author', 'body']);
    expect(table.readOnly, isTrue);
    expect(table.allowAdding, isFalse);
    expect(table.allowEdit, isFalse);
    expect(table.allowRemove, isFalse);
  });
}

/// A tag, the target of the article fixture's many-to-many relationship.
final class _TagModel extends BeakModel {
  const _TagModel();

  @override
  String get table => 'tags';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];
}

/// A comment, the target of the article fixture's has-many relationship.
final class _CommentModel extends BeakModel {
  const _CommentModel();

  @override
  String get table => 'comments';

  @override
  String get displayColumnKey => 'text';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'text', label: 'Text'),
    BeakStringColumn(key: 'author', label: 'Author'),
    BeakStringColumn(key: 'body', label: 'Body'),
    BeakStringColumn(key: 'article_id', label: 'Article'),
  ];
}
