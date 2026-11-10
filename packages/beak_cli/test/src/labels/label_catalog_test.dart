import 'dart:io';

import 'package:beak_cli/src/labels/label_catalog.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('beak-labels-'));
  tearDown(() => root.deleteSync(recursive: true));

  void arb(String name, String json) =>
      File('${root.path}/$name').writeAsStringSync(json);

  test('reads every locale, skipping metadata, template first', () {
    arb('models_en.arb', '''
{
  "@@locale": "en",
  "placedOrder.email": "Email",
  "@placedOrder.email": {"description": "Where the confirmation went"}
}''');
    arb('models_de.arb', '''
{"@@locale": "de", "placedOrder.email": "E-Mail"}''');

    final catalog = BeakLabelCatalog.read(root, template: 'en');

    expect(catalog.locales, ['en', 'de']);
    expect(catalog.template, 'en');
    expect(catalog.keys, {'placedOrder.email'});
    expect(catalog.text('de', 'placedOrder.email'), 'E-Mail');
    expect(catalog.text('en', 'placedOrder.missing'), isNull);
  });

  test('without a template the first locale by name leads', () {
    arb('models_en.arb', '{"@@locale": "en"}');
    arb('models_de.arb', '{"@@locale": "de"}');

    expect(BeakLabelCatalog.read(root).template, 'de');
  });

  test('an ICU plural gives one and other; a plain text serves both', () {
    arb('models_de.arb', '''
{
  "@@locale": "de",
  "placedOrder": "{count, plural, one{Bestellung} other{Bestellungen}}",
  "tag": "Tag",
  "box": "{n, plural, =1{Kiste} other{Kisten}}"
}''');

    final catalog = BeakLabelCatalog.read(root);

    expect(catalog.names('de', 'placedOrder'), (
      one: 'Bestellung',
      other: 'Bestellungen',
    ));
    expect(catalog.names('de', 'tag'), (one: 'Tag', other: 'Tag'));
    expect(catalog.names('de', 'box'), (one: 'Kiste', other: 'Kisten'));
  });

  test('refuses a file without @@locale, a duplicate locale and non-text', () {
    arb('a.arb', '{"x": "y"}');
    arb('b_de.arb', '{"@@locale": "de", "n": 3}');
    arb('c_de.arb', '{"@@locale": "de"}');

    expect(
      () => BeakLabelCatalog.read(root),
      throwsA(
        isA<BeakLabelCatalogException>().having(
          (error) => error.issues.map((issue) => issue.message).join('\n'),
          'messages',
          allOf(
            contains('no "@@locale"'),
            contains('"n" is not a text'),
            contains('a second file for "de"'),
          ),
        ),
      ),
    );
  });

  test('refuses a plural without other and an unknown template', () {
    arb('models_de.arb', '''
{"@@locale": "de", "order": "{count, plural, one{Bestellung}}"}''');

    expect(
      () => BeakLabelCatalog.read(root),
      throwsA(isA<BeakLabelCatalogException>()),
    );
    File('${root.path}/models_de.arb').writeAsStringSync('{"@@locale": "de"}');
    expect(
      () => BeakLabelCatalog.read(root, template: 'fr'),
      throwsA(isA<BeakLabelCatalogException>()),
    );
  });
}
