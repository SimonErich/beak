import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  group('BeakStorageSettings.fromEnv', () {
    test('builds an s3 config from the BEAK_S3_* block', () {
      final config = BeakStorageSettings.fromEnv(const {
        'BEAK_STORAGE_DRIVER': 's3',
        'BEAK_S3_ENDPOINT': 'http://localhost:29000',
        'BEAK_S3_BUCKET': 'beak-uploads',
        'BEAK_S3_ACCESS_KEY': 'beak',
        'BEAK_S3_SECRET_KEY': 'beaksecret',
        'BEAK_S3_REGION': 'us-east-1',
        'BEAK_S3_USE_PATH_STYLE': 'true',
      });

      expect(config, isA<BeakS3Config>());
      if (config case final BeakS3Config s3) {
        expect(s3.bucket, 'beak-uploads');
        expect(s3.region, 'us-east-1');
        expect(s3.usePathStyle, isTrue);
        expect(s3.endpoint, Uri.parse('http://localhost:29000'));
      }
    });

    test('treats a non-"true" path-style value as false', () {
      final config = BeakStorageSettings.fromEnv(const {
        'BEAK_STORAGE_DRIVER': 's3',
        'BEAK_S3_ENDPOINT': 'https://s3.example.com',
        'BEAK_S3_BUCKET': 'b',
        'BEAK_S3_ACCESS_KEY': 'k',
        'BEAK_S3_SECRET_KEY': 's',
        'BEAK_S3_REGION': 'eu-central-1',
      });
      expect((config! as BeakS3Config).usePathStyle, isFalse);
    });

    test('builds an ftp config, defaulting the port to 21', () {
      final config = BeakStorageSettings.fromEnv(const {
        'BEAK_STORAGE_DRIVER': 'ftp',
        'BEAK_FTP_HOST': 'ftp.example.com',
        'BEAK_FTP_USER': 'beak',
        'BEAK_FTP_PASSWORD': 'secret',
        'BEAK_FTP_BASE_DIR': '/uploads',
        'BEAK_FTP_PUBLIC_BASE_URL': 'https://cdn.example.com',
      });

      expect(config, isA<BeakFtpConfig>());
      if (config case final BeakFtpConfig ftp) {
        expect(ftp.host, 'ftp.example.com');
        expect(ftp.port, 21);
        expect(ftp.baseDir, '/uploads');
      }
    });

    test('honours an explicit ftp port', () {
      final config = BeakStorageSettings.fromEnv(const {
        'BEAK_STORAGE_DRIVER': 'ftp',
        'BEAK_FTP_HOST': 'ftp.example.com',
        'BEAK_FTP_USER': 'beak',
        'BEAK_FTP_PASSWORD': 'secret',
        'BEAK_FTP_BASE_DIR': '/uploads',
        'BEAK_FTP_PUBLIC_BASE_URL': 'https://cdn.example.com',
        'BEAK_FTP_PORT': '2121',
      });
      expect((config! as BeakFtpConfig).port, 2121);
    });

    test('builds a local-disk config', () {
      final config = BeakStorageSettings.fromEnv(const {
        'BEAK_STORAGE_DRIVER': 'local',
        'BEAK_LOCAL_ROOT_DIR': 'var/uploads',
        'BEAK_LOCAL_PUBLIC_BASE_URL': 'http://localhost:8080/files',
      });

      expect(config, isA<BeakLocalDiskStorageConfig>());
      if (config case final BeakLocalDiskStorageConfig local) {
        expect(local.rootDir, 'var/uploads');
      }
    });

    test('selects the in-memory driver', () {
      expect(
        BeakStorageSettings.fromEnv(const {'BEAK_STORAGE_DRIVER': 'memory'}),
        isA<BeakMemoryStorageConfig>(),
      );
    });

    test('disables uploads when the driver is unset or empty', () {
      expect(BeakStorageSettings.fromEnv(const {}), isNull);
      expect(
        BeakStorageSettings.fromEnv(const {'BEAK_STORAGE_DRIVER': ''}),
        isNull,
      );
    });

    test('names the missing variable when a driver is half-configured', () {
      expect(
        () => BeakStorageSettings.fromEnv(const {'BEAK_STORAGE_DRIVER': 's3'}),
        throwsA(
          isA<BeakConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('BEAK_S3_ENDPOINT'),
          ),
        ),
      );
      expect(
        () => BeakStorageSettings.fromEnv(const {'BEAK_STORAGE_DRIVER': 'ftp'}),
        throwsA(
          isA<BeakConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('BEAK_FTP_HOST'),
          ),
        ),
      );
      expect(
        () =>
            BeakStorageSettings.fromEnv(const {'BEAK_STORAGE_DRIVER': 'local'}),
        throwsA(
          isA<BeakConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('BEAK_LOCAL_ROOT_DIR'),
          ),
        ),
      );
    });

    test('lists the supported drivers when the name is unknown', () {
      expect(
        () => BeakStorageSettings.fromEnv(const {
          'BEAK_STORAGE_DRIVER': 'carrier-pigeon',
        }),
        throwsA(
          isA<BeakConfigurationException>()
              .having((e) => e.message, 'message', contains('carrier-pigeon'))
              .having((e) => e.message, 'message', contains('s3')),
        ),
      );
    });

    test('every supported driver id is actually parseable', () {
      // Guards the doc claim: a driver listed as supported must build.
      const complete = {
        's3': {
          'BEAK_S3_ENDPOINT': 'http://e',
          'BEAK_S3_BUCKET': 'b',
          'BEAK_S3_ACCESS_KEY': 'k',
          'BEAK_S3_SECRET_KEY': 's',
          'BEAK_S3_REGION': 'r',
        },
        'ftp': {
          'BEAK_FTP_HOST': 'h',
          'BEAK_FTP_USER': 'u',
          'BEAK_FTP_PASSWORD': 'p',
          'BEAK_FTP_BASE_DIR': '/d',
          'BEAK_FTP_PUBLIC_BASE_URL': 'http://c',
        },
        'local': {
          'BEAK_LOCAL_ROOT_DIR': 'var',
          'BEAK_LOCAL_PUBLIC_BASE_URL': 'http://c',
        },
        'memory': <String, String>{},
      };
      for (final driver in BeakStorageSettings.supportedDrivers) {
        expect(
          BeakStorageSettings.fromEnv({
            'BEAK_STORAGE_DRIVER': driver,
            ...?complete[driver],
          }),
          isNotNull,
          reason: '$driver is listed as supported but did not parse',
        );
      }
    });
  });
}
