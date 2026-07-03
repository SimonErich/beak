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

    test('rejects a missing DATABASE_URL', () {
      expect(
        () => BeakBackendConfig.fromEnv(environment: const <String, String>{}),
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
      // The test process has no DATABASE_URL, so the validated read throws —
      // proving fromEnv falls back to Platform.environment.
      expect(
        BeakBackendConfig.fromEnv,
        throwsA(isA<BeakConfigurationException>()),
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
