import 'dart:typed_data';

import 'package:beak_backend/src/uploads/upload_service.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_image/beak_image.dart';
import 'package:test/test.dart';

/// A model with a file column that accepts anything, where the client's
/// filename is the only thing that could reach a stored key.
final class _DropboxModel extends BeakModel {
  const _DropboxModel();

  @override
  String get table => 'dropbox';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'title', label: 'Title'),
    BeakFileColumn(key: 'anything', label: 'Anything', storagePath: 'drop'),
  ];
}

void main() {
  late BeakMemoryStorageDriver storage;
  late UploadService service;

  setUp(() {
    storage = BeakMemoryStorageDriver();
    service = UploadService(
      registry: BeakModelRegistry()..register(const _DropboxModel()),
      storage: storage,
      transformRunner: const ImageTransformRunner(),
      generateKeyId: () => 'minted',
    );
  });

  Future<BeakStoredFile> store(String filename) => service.handle(
    table: 'dropbox',
    columnKey: 'anything',
    upload: BeakUpload(
      filename: filename,
      mimeType: 'application/octet-stream',
      bytes: Uint8List.fromList([1, 2, 3]),
    ),
  );

  test('a plain extension survives, lower-cased', () async {
    expect((await store('Notes.TXT')).key, 'drop/minted.txt');
  });

  test('no extension leaves a bare minted key', () async {
    expect((await store('README')).key, 'drop/minted');
  });

  for (final String filename in [
    'x.a/b',
    'x.png/../../evil',
    'x.a\r\nDELE /etc/passwd',
    'x.a\nb',
    'x.a\u0000b',
    r'x.a\b',
    'x.a b',
    'x.a?b',
    'x.a#b',
    'x.a%2Fb',
    'x.ünï',
    'x.${'a' * 64}',
  ]) {
    test('a hostile extension never reaches the key: $filename', () async {
      final BeakStoredFile stored = await store(filename);
      expect(stored.key, matches(RegExp(r'^drop/minted(\.[a-z0-9]{1,16})?$')));
    });
  }

  group('a key a client sends to resolve or remove a file', () {
    for (final String key in [
      'drop/a\r\nDELE /etc/passwd',
      'drop/a\nb',
      'drop/a\u0000b',
      'drop/../secret',
      r'drop/a\b',
      'drop//a',
      'other/minted',
    ]) {
      test('is refused as a client mistake: ${key.codeUnits}', () async {
        await expectLater(
          service.url('dropbox', 'anything', key),
          throwsA(isA<BeakValidationException>()),
        );
        await expectLater(
          service.remove('dropbox', 'anything', key),
          throwsA(isA<BeakValidationException>()),
        );
      });
    }
  });
}
