import 'dart:io';

import '../../support/beak_cli_internals.dart';
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

  group('panel', () {
    test('has no entrypoint of its own by default', () {
      expect(parse('').panel.entrypoint, isNull);
      expect(parse('name: Acme\n').panel.entrypoint, isNull);
      expect(parse('panel: {}\n').panel.entrypoint, isNull);
      expect(
        BeakProjectConfig.defaults(packageName: 'acme_admin').panel.entrypoint,
        isNull,
      );
    });

    test('reads the entrypoint of an app that embeds the panel', () {
      final config = parse('panel:\n  entrypoint: lib/admin_main.dart\n');

      expect(config.panel.entrypoint, 'lib/admin_main.dart');
      expect(config.panel.entrypointPath, 'lib/admin_main.dart');
    });

    test('boots from lib/main.dart when it names none', () {
      expect(parse('').panel.entrypointPath, 'lib/main.dart');
    });

    test('an unknown panel key is an error naming it', () {
      expect(
        () => parse('panel:\n  title: Admin\n'),
        throwsA(
          isA<BeakProjectConfigException>()
              .having((e) => e.message, 'message', contains('panel.title'))
              .having((e) => e.message, 'message', contains('entrypoint')),
        ),
      );
    });

    test('the entrypoint must be a string', () {
      expect(
        () => parse('panel:\n  entrypoint: 3\n'),
        throwsA(
          isA<BeakProjectConfigException>().having(
            (e) => e.message,
            'message',
            contains('panel.entrypoint must be a string'),
          ),
        ),
      );
    });

    for (final bad in const [
      '/home/me/lib/main.dart',
      'lib/main',
      '../other/lib/main.dart',
      r'lib\\main.dart',
      "''",
    ]) {
      test('rejects the entrypoint $bad', () {
        expect(
          () => parse('panel:\n  entrypoint: $bad\n'),
          throwsA(
            isA<BeakProjectConfigException>().having(
              (e) => e.message,
              'message',
              contains('panel.entrypoint'),
            ),
          ),
        );
      });
    }

    test('a panel that is not a mapping is an error', () {
      expect(
        () => parse('panel: lib/main.dart\n'),
        throwsA(
          isA<BeakProjectConfigException>().having(
            (e) => e.message,
            'message',
            contains('panel must be a mapping'),
          ),
        ),
      );
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

  group('a YAML syntax error', () {
    // The scanner's own exception used to escape `parse` untouched, so
    // `prepare`, `eject` and `doctor` crashed with a stack trace that never
    // said which file was wrong.
    test('is a config exception naming the file, line and column', () {
      expect(
        () => parse('name: Shop\nresources: [unclosed\n'),
        throwsA(
          isA<BeakProjectConfigException>().having(
            (error) => error.toString(),
            'toString',
            allOf(
              startsWith('beak.yaml: '),
              contains('line 3'),
              contains('column 1'),
              contains("expected ',' or ']'"),
            ),
          ),
        ),
      );
    });

    test('counts lines and columns from one, as an editor does', () {
      expect(
        () => parse('name: a: b\n'),
        throwsA(
          isA<BeakProjectConfigException>().having(
            (error) => error.message,
            'message',
            allOf(contains('line 1'), contains('column 8')),
          ),
        ),
      );
    });

    test('is reported by load too, from the file on disk', () {
      final Directory root = Directory.systemTemp.createTempSync('beak_yaml_');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/beak.yaml').writeAsStringSync('a:\n\t- b\n');

      expect(
        () => BeakProjectConfig.load(root, packageName: 'acme_admin'),
        throwsA(
          isA<BeakProjectConfigException>().having(
            (error) => error.message,
            'message',
            allOf(contains('line 2'), contains('Tab characters')),
          ),
        ),
      );
    });
  });
}
