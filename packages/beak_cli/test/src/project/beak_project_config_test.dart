import 'package:beak_cli/beak_cli.dart';
import 'package:test/test.dart';

BeakProjectConfig parse(String yaml) =>
    BeakProjectConfig.parse(yaml, packageName: 'acme_admin');

void main() {
  group('defaults', () {
    test('title the panel after the package', () {
      final config = BeakProjectConfig.defaults(packageName: 'acme_admin');
      expect(config.name, 'Acme Admin');
      expect(config.api.baseUrl, 'http://localhost:8080');
      expect(config.sidebarCollapsible, isTrue);
      expect(config.sidebarStartCollapsed, isFalse);
      expect(config.resources, isEmpty);
    });

    test('apply to an empty document — deleting beak.yaml is supported', () {
      expect(parse('').name, 'Acme Admin');
      expect(parse('# just a comment\n').name, 'Acme Admin');
    });
  });

  group('parsing', () {
    test('reads every supported key', () {
      final config = parse('''
name: Acme
api:
  baseUrl: https://api.example.com
theme:
  sidebar:
    collapsible: false
    startCollapsed: true
resources:
  products:
    icon: package
    label: Catalog
    section: Store
''');

      expect(config.name, 'Acme');
      expect(config.api.baseUrl, 'https://api.example.com');
      expect(config.sidebarCollapsible, isFalse);
      expect(config.sidebarStartCollapsed, isTrue);
      expect(config.resources['products']?.icon, 'package');
      expect(config.resources['products']?.label, 'Catalog');
      expect(config.resources['products']?.section, 'Store');
    });

    test('a partially specified resource keeps the rest null', () {
      final config = parse('''
resources:
  products:
    icon: package
''');
      expect(config.resources['products']?.icon, 'package');
      expect(config.resources['products']?.label, isNull);
    });
  });

  group('api base url', () {
    test('compiles a fixed origin in, overridable at build time', () {
      expect(
        parse('api:\n  baseUrl: https://api.example.com\n').api.expression,
        contains("String.fromEnvironment('BEAK_API_BASE_URL'"),
      );
    });

    test('`auto` resolves the serving origin on web', () {
      final api = parse('api:\n  baseUrl: auto\n').api;
      expect(api.isAuto, isTrue);
      expect(api.expression, contains('Uri.base.origin'));
    });
  });

  group('errors name the offending key', () {
    test('an unknown top-level key', () {
      expect(
        () => parse('colour: blue\n'),
        throwsA(
          isA<BeakProjectConfigException>()
              .having((e) => e.message, 'message', contains('colour'))
              .having((e) => e.message, 'message', contains('Expected one of')),
        ),
      );
    });

    test('an unknown nested key', () {
      expect(
        () => parse('api:\n  url: x\n'),
        throwsA(
          isA<BeakProjectConfigException>().having(
            (e) => e.message,
            'message',
            contains('api.url'),
          ),
        ),
      );
    });

    test('an unknown resource key', () {
      expect(
        () => parse('resources:\n  products:\n    colour: blue\n'),
        throwsA(
          isA<BeakProjectConfigException>().having(
            (e) => e.message,
            'message',
            contains('resources.products.colour'),
          ),
        ),
      );
    });

    test('a value of the wrong type', () {
      expect(
        () => parse('name: 42\n'),
        throwsA(
          isA<BeakProjectConfigException>().having(
            (e) => e.message,
            'message',
            contains('must be a string'),
          ),
        ),
      );
      expect(
        () => parse('theme:\n  sidebar:\n    collapsible: yes please\n'),
        throwsA(
          isA<BeakProjectConfigException>().having(
            (e) => e.message,
            'message',
            contains('must be true or false'),
          ),
        ),
      );
    });

    test('a scalar where a mapping belongs', () {
      expect(
        () => parse('api: https://example.com\n'),
        throwsA(
          isA<BeakProjectConfigException>().having(
            (e) => e.message,
            'message',
            contains('must be a mapping'),
          ),
        ),
      );
    });

    test('toString prefixes the file so the message stands alone', () {
      expect(
        const BeakProjectConfigException('unknown key "x".').toString(),
        'beak.yaml: unknown key "x".',
      );
    });
  });
}
