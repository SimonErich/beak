import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

/// Exhaustive mapping over the sealed config family: adding a variant breaks
/// compilation here until it is handled.
String configKindOf(BeakStorageConfig config) => switch (config) {
  BeakMemoryStorageConfig() => 'memory',
  BeakLocalDiskStorageConfig() => 'local',
  BeakS3Config() => 's3',
  BeakFtpConfig() => 'ftp',
};

void main() {
  final s3 = BeakS3Config(
    endpoint: Uri.parse('https://minio.example.com:9000'),
    bucket: 'beak-uploads',
    accessKey: 'AKIAEXAMPLEKEY',
    secretKey: 'sup3r-s3cret-key',
    region: 'eu-central-1',
  );
  final ftp = BeakFtpConfig(
    host: 'ftp.example.com',
    user: 'uploader',
    password: 'hunter2-password',
    baseDir: '/var/uploads',
    publicBaseUrl: Uri.parse('https://files.example.com'),
  );

  group('BeakStorageConfig', () {
    test('every config names its driver', () {
      expect(const BeakMemoryStorageConfig().driverId, 'memory');
      expect(
        BeakLocalDiskStorageConfig(
          rootDir: '/tmp/beak',
          publicBaseUrl: Uri.parse('http://localhost:8080/files'),
        ).driverId,
        'local',
      );
      expect(s3.driverId, 's3');
      expect(ftp.driverId, 'ftp');
    });

    test('the family switches exhaustively onto driver ids', () {
      final configs = <BeakStorageConfig>[
        const BeakMemoryStorageConfig(),
        BeakLocalDiskStorageConfig(
          rootDir: '/tmp/beak',
          publicBaseUrl: Uri.parse('http://localhost:8080/files'),
        ),
        s3,
        ftp,
      ];
      for (final config in configs) {
        expect(configKindOf(config), config.driverId);
      }
    });
  });

  group('BeakLocalDiskStorageConfig', () {
    test('carries root directory and public base URL', () {
      final config = BeakLocalDiskStorageConfig(
        rootDir: '/var/beak/files',
        publicBaseUrl: Uri.parse('http://localhost:8080/files'),
      );
      expect(config.rootDir, '/var/beak/files');
      expect(config.publicBaseUrl.port, 8080);
    });
  });

  group('BeakS3Config', () {
    test('carries endpoint, bucket and credentials', () {
      expect(s3.endpoint.host, 'minio.example.com');
      expect(s3.bucket, 'beak-uploads');
      expect(s3.accessKey, 'AKIAEXAMPLEKEY');
      expect(s3.secretKey, 'sup3r-s3cret-key');
      expect(s3.region, 'eu-central-1');
    });

    test('defaults to virtual-host style and no public base URL', () {
      expect(s3.usePathStyle, isFalse);
      expect(s3.publicBaseUrl, isNull);
    });

    test('toString redacts the credentials', () {
      final printed = s3.toString();
      expect(printed, isNot(contains('sup3r-s3cret-key')));
      expect(printed, isNot(contains('AKIAEXAMPLEKEY')));
      expect(printed, contains('minio.example.com'));
      expect(printed, contains('beak-uploads'));
      expect(printed, contains('eu-central-1'));
    });
  });

  group('BeakFtpConfig', () {
    test('carries connection settings', () {
      expect(ftp.host, 'ftp.example.com');
      expect(ftp.port, 21);
      expect(ftp.user, 'uploader');
      expect(ftp.password, 'hunter2-password');
      expect(ftp.baseDir, '/var/uploads');
      expect(ftp.publicBaseUrl.host, 'files.example.com');
    });

    test('toString redacts the password', () {
      final printed = ftp.toString();
      expect(printed, isNot(contains('hunter2-password')));
      expect(printed, contains('ftp.example.com'));
      expect(printed, contains('uploader'));
    });
  });
}
