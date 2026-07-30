import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:beak_core/io.dart';
import 'package:test/test.dart';

/// A driver stub for registration tests; no operation is ever invoked.
final class _StubDriver implements BeakStorageDriver {
  const _StubDriver();

  @override
  String get id => 'stub';

  @override
  Future<BeakStoredFile> put(BeakUpload upload, {required String path}) =>
      throw UnimplementedError();

  @override
  Future<Uint8List> get(String key) => throw UnimplementedError();

  @override
  Future<void> delete(String key) => throw UnimplementedError();

  @override
  Future<Uri> url(String key, {Duration? expiresIn}) =>
      throw UnimplementedError();

  @override
  Future<bool> exists(String key) => throw UnimplementedError();
}

void main() {
  BeakS3Config s3Config() => BeakS3Config(
    endpoint: Uri.parse('https://minio.example.com'),
    bucket: 'beak',
    accessKey: 'key',
    secretKey: 'secret',
    region: 'eu-central-1',
  );

  group('BeakStorageRegistry', () {
    test('pre-registers only the web-safe memory driver', () {
      // `local` needs dart:io, so it is registered by the server side
      // (beak_backend's createDefaultStorageRegistry) rather than here —
      // that is what keeps this barrel importable from a Flutter web build.
      expect(BeakStorageRegistry().driverIds, const ['memory']);
    });

    test('driverIds is unmodifiable', () {
      expect(
        () => BeakStorageRegistry().driverIds.add('hack'),
        throwsUnsupportedError,
      );
    });

    test('resolves the memory driver from its config', () {
      expect(
        BeakStorageRegistry().resolve(const BeakMemoryStorageConfig()),
        isA<BeakMemoryStorageDriver>(),
      );
    });

    test('resolves the local-disk driver once it is registered', () {
      final driver =
          (BeakStorageRegistry()
                ..register('local', BeakLocalDiskStorageDriver.fromConfig))
              .resolve(
                BeakLocalDiskStorageConfig(
                  rootDir: '/tmp/beak',
                  publicBaseUrl: Uri.parse('http://localhost:8080/files'),
                ),
              );
      expect(driver, isA<BeakLocalDiskStorageDriver>());
    });

    test('throws for a config whose driver is not registered', () {
      expect(
        () => BeakStorageRegistry().resolve(s3Config()),
        throwsA(
          isA<BeakConfigurationException>().having(
            (exception) => exception.message,
            'message',
            contains('s3'),
          ),
        ),
      );
    });

    test('rejects duplicate driver ids', () {
      expect(
        () => BeakStorageRegistry().register(
          'memory',
          (config) => const _StubDriver(),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('resolves additionally registered drivers', () {
      final registry = BeakStorageRegistry()
        ..register('s3', (config) => const _StubDriver());
      expect(registry.driverIds, const ['memory', 's3']);
      expect(registry.resolve(s3Config()), isA<_StubDriver>());
    });
  });
}
