import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';

const _owner = BeakStringColumn(key: 'tagId', label: 'Tag');
const _locale = BeakStringColumn(key: 'locale', label: 'Locale');
const _name = BeakStringColumn(key: 'name', label: 'Name');

final class _TranslationModel extends BeakModel {
  const _TranslationModel();

  @override
  String get table => 'tag_translations';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    _owner,
    _locale,
    _name,
  ];

  @override
  BeakAdmission get admission => const BeakAdmission(
    translation: BeakTranslationSpec(owner: _owner, locale: _locale),
  );
}

final class _TagModel extends BeakModel {
  const _TagModel();

  @override
  String get table => 'tags';

  @override
  String get displayColumnKey => 'id';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
  ];
}

const _translations = BeakToManyField(
  model: _TagModel(),
  relation: BeakHasMany(
    key: 'translations',
    label: 'Translations',
    relatedTable: 'tag_translations',
    displayColumnKey: 'name',
    foreignKey: 'tagId',
    owned: true,
  ),
  target: _TranslationModel(),
);

String _keyOf(BeakFormNode node) => switch (node) {
  BeakInput(:final field) => field.key,
  _ => '',
};

void main() {
  test('cards put the language and every text in one card', () {
    final table = _translations.translationsForm();

    expect(table.presentation, BeakRelationTablePresentation.cards);
    expect(table.children.map(_keyOf), ['locale', 'name']);
  });

  test('rows lead with the language and delete a removed row', () {
    final table = _translations.translationsForm(
      presentation: BeakRelationTablePresentation.rows,
    );

    expect(table.presentation, BeakRelationTablePresentation.rows);
    expect(table.identityChildren.map(_keyOf), ['locale']);
    expect(table.children.map(_keyOf), ['name']);
    expect(table.removeBehavior, BeakRemoveBehavior.deleteOwned);
  });
}
