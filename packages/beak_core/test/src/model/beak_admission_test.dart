import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

enum _Write { menu }

const _name = BeakStringColumn(key: 'name', label: 'Name');
const _secret = BeakStringColumn(key: 'token', label: 'Token');
const _owner = BeakStringColumn(key: 'menu_id', label: 'Menu');
const _locale = BeakStringColumn(key: 'locale', label: 'Locale');

/// The admission is a constant of a generated model, so it must be reachable
/// from a `const` context.
const _admission = BeakAdmission(
  writable: [_name],
  hidden: [_secret],
  restoreKey: [_owner, _locale],
  translation: BeakTranslationSpec(owner: _owner, locale: _locale),
  write: _Write.menu,
  reason: 'Rows are written by the importer.',
);

final class _Menu extends BeakModel {
  const _Menu();

  @override
  String get table => 'menus';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [_name, _secret];

  @override
  BeakAdmission get admission => _admission;
}

final class _Plain extends BeakModel {
  const _Plain();

  @override
  String get table => 'plain';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [_name];
}

void main() {
  test('an empty admission closes everything', () {
    const admission = BeakAdmission();
    expect(admission.writable, isEmpty);
    expect(admission.hidden, isEmpty);
    expect(admission.restoreKey, isEmpty);
    expect(admission.translation, isNull);
    expect(admission.write, isNull);
    expect(admission.reason, isNull);
  });

  test('a full admission is const-constructible and keeps every fact', () {
    expect(_admission.writable, [_name]);
    expect(_admission.hidden, [_secret]);
    expect(_admission.restoreKey, [_owner, _locale]);
    expect(_admission.translation?.owner, same(_owner));
    expect(_admission.translation?.locale, same(_locale));
    expect(_admission.write, _Write.menu);
    expect(_admission.reason, contains('importer'));
  });

  test('equal constants are canonicalised', () {
    const first = BeakAdmission(writable: [_name]);
    const second = BeakAdmission(writable: [_name]);
    expect(identical(first, second), isTrue);
  });

  test('a model has no admission unless it declares one', () {
    expect(const _Plain().admission, isNull);
    expect(const _Menu().admission, same(_admission));
  });
}
