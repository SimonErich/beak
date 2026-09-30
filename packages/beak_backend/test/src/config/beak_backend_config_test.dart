import 'dart:io';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const databaseUrl = 'postgres://beak:secret@localhost:25432/beak';

  group('fromEnv', () {
    test('parses a fully specified environment', () {
      final config = BeakBackendConfig.fromEnv(
        environment: {
          'DATABASE_URL': databaseUrl,
          'PORT': '9090',
          'HOST': '127.0.0.1',
        },
      );
      expect(config.databaseUrl, Uri.parse(databaseUrl));
      expect(config.port, 9090);
      expect(config.host, '127.0.0.1');
    });

    test('applies defaults for everything but DATABASE_URL', () {
      final config = BeakBackendConfig.fromEnv(
        environment: {'DATABASE_URL': databaseUrl},
      );
      expect(config.port, 8080);
      expect(config.host, '0.0.0.0');
    });

    test('falls back to a SQLite file when DATABASE_URL is absent', () {
      // The first `beak dev` must need no Docker, no credentials and no .env:
      // requiring a database to see anything at all loses more first-time
      // users than any other step.
      final config = BeakBackendConfig.fromEnv(
        environment: const <String, String>{},
      );

      expect(config.databaseUrl.toString(), 'sqlite:beak.db');
      expect(isSqliteUrl(config.databaseUrl), isTrue);
      expect(sqliteFilePathOf(config.databaseUrl), 'beak.db');
    });

    test('reads the sqlite path, and :memory: as no path at all', () {
      String? pathOf(String url) => sqliteFilePathOf(
        BeakBackendConfig.fromEnv(
          environment: {'DATABASE_URL': url},
        ).databaseUrl,
      );

      expect(pathOf('sqlite:beak.db'), 'beak.db');
      expect(pathOf('sqlite:///tmp/beak.db'), '/tmp/beak.db');
      expect(pathOf('sqlite::memory:'), isNull);
    });

    group('the file a sqlite URL names', () {
      String? fileOf(String url) => sqliteFilePathOf(
        BeakBackendConfig.fromEnv(
          environment: {'DATABASE_URL': url},
        ).databaseUrl,
      );
      final String here = Directory.current.absolute.path;
      final String parent = Directory.current.parent.absolute.path;

      test('keeps a relative path as written', () {
        expect(fileOf('sqlite:beak.db'), 'beak.db');
        expect(fileOf('sqlite:./beak.db'), 'beak.db');
        expect(fileOf('sqlite:data/beak.db'), 'data/beak.db');
        expect(fileOf('file:data/beak.db'), 'data/beak.db');
      });

      test('reaches a file above the working directory', () {
        // Uri.parse would drop the `..` and open a new, empty file here.
        expect(fileOf('sqlite:../legacy.db'), '$parent/legacy.db');
        expect(
          fileOf('sqlite:../../legacy.db'),
          '${Directory.current.parent.parent.absolute.path}/legacy.db',
        );
        expect(fileOf('file:../legacy.db'), '$parent/legacy.db');
      });

      test('resolves a dot segment against the working directory', () {
        // Uri.parse would turn this into the absolute path `/x.db`.
        expect(fileOf('sqlite:./data/../x.db'), '$here/x.db');
        expect(fileOf('sqlite:a/b/../../c.db'), '$here/c.db');
      });

      test('cannot climb above the root', () {
        expect(fileOf('sqlite:${'../' * 64}x.db'), '/x.db');
      });

      test('reads an absolute path, dots resolved', () {
        expect(fileOf('sqlite:///tmp/beak.db'), '/tmp/beak.db');
        expect(fileOf('sqlite:///tmp/a/../b.db'), '/tmp/b.db');
      });

      test('decodes what a path may hold', () {
        expect(fileOf('sqlite:my data/beak.db'), 'my data/beak.db');
        expect(fileOf('sqlite:my%20data/beak.db'), 'my data/beak.db');
        expect(fileOf('sqlite:../my data/x.db'), '$parent/my data/x.db');
        expect(fileOf('sqlite:../100%25/x.db'), '$parent/100%/x.db');
      });

      test('names no file for an in-memory database', () {
        expect(fileOf('sqlite::memory:'), isNull);
      });
    });

    test('a sqlite URL needs no host, a postgres URL still does', () {
      expect(
        () => BeakBackendConfig.fromEnv(
          environment: {'DATABASE_URL': 'sqlite:beak.db'},
        ),
        returnsNormally,
      );
      expect(
        () => BeakBackendConfig.fromEnv(
          environment: {'DATABASE_URL': 'postgres:///beak'},
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects a DATABASE_URL without a scheme', () {
      expect(
        () => BeakBackendConfig.fromEnv(
          environment: {'DATABASE_URL': 'localhost:5432/beak'},
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('a rejected DATABASE_URL never repeats its password', () {
      // The message is printed by the generated bin/serve.dart.
      for (final url in [
        'postgres://beak:hunter2@db:notaport/beak',
        'postgres://beak:hunter2@/beak',
        'postgres://beak:hun@ter2@db:notaport/beak',
      ]) {
        expect(
          () => BeakBackendConfig.fromEnv(environment: {'DATABASE_URL': url}),
          throwsA(
            isA<BeakConfigurationException>().having(
              (error) => error.message,
              'message',
              allOf(
                isNot(contains('hunter2')),
                isNot(contains('hun@')),
                contains('postgres://'),
              ),
            ),
          ),
          reason: url,
        );
      }
    });

    test('rejects a non-numeric PORT', () {
      expect(
        () => BeakBackendConfig.fromEnv(
          environment: {'DATABASE_URL': databaseUrl, 'PORT': 'eighty'},
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects an out-of-range PORT', () {
      for (final port in ['0', '65536']) {
        expect(
          () => BeakBackendConfig.fromEnv(
            environment: {'DATABASE_URL': databaseUrl, 'PORT': port},
          ),
          throwsA(isA<BeakConfigurationException>()),
          reason: port,
        );
      }
    });

    test('rejects an empty HOST', () {
      expect(
        () => BeakBackendConfig.fromEnv(
          environment: {'DATABASE_URL': databaseUrl, 'HOST': ''},
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('reads the real process environment when none is injected', () {
      // The test process has no DATABASE_URL, so this lands on the default —
      // proving fromEnv falls back to Platform.environment rather than to an
      // empty map.
      expect(
        BeakBackendConfig.fromEnv().databaseUrl.toString(),
        BeakBackendConfig.defaultDatabaseUrl,
      );
    });
  });

  test('toString redacts database credentials', () {
    final config = BeakBackendConfig.fromEnv(
      environment: {'DATABASE_URL': databaseUrl},
    );
    final rendered = config.toString();
    expect(rendered, isNot(contains('secret')));
    expect(rendered, contains('localhost'));
    expect(rendered, contains('8080'));
  });
}
