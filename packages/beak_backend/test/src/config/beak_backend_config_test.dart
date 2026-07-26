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
