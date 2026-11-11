import 'package:beak_cli/src/project/beak_project_config.dart';
import 'package:test/test.dart';

BeakProjectConfig parse(String generate) => BeakProjectConfig.parse('''
serverpod: {server: ../server}
generate:
$generate
''', packageName: 'shop_admin');

void main() {
  test('reads the definitions package and the handler folder', () {
    final settings = parse('''
  definitions: admin_definitions
  handlers: ../server/lib/src/admin
  prefix: Shop
''').generate!;

    expect(settings.definitions, 'admin_definitions');
    expect(settings.handlers, '../server/lib/src/admin');
    expect(settings.prefix, 'Shop');
  });

  test('defaults to definitions/ and no handlers', () {
    final settings = parse('  prefix: Shop').generate!;

    expect(settings.definitions, 'definitions');
    expect(settings.handlers, isNull);
  });

  for (final removed in ['output', 'inventory', 'writes']) {
    test('the removed generate.$removed points at the definition classes', () {
      expect(
        () => parse('  $removed: x'),
        throwsA(
          isA<BeakProjectConfigException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('generate.$removed is gone'),
              contains('definition classes'),
            ),
          ),
        ),
      );
    });
  }
}
