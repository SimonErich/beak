import 'dart:convert';
import 'dart:typed_data';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_backend/src/uploads/upload_handler.dart';
import 'package:beak_backend/src/uploads/upload_service.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_image/beak_image.dart';
import 'package:test/test.dart';

/// A model whose file column sets no size limit of its own.
final class _ArchiveModel extends BeakModel {
  const _ArchiveModel();

  @override
  String get table => 'archive';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'title', label: 'Title'),
    BeakFileColumn(key: 'blob', label: 'Blob', storagePath: 'blobs'),
    BeakFileColumn(
      key: 'huge',
      label: 'Huge',
      storagePath: 'huge',
      maxSizeInBytes: 1000,
    ),
  ];
}

Request multipart(String path, List<int> bytes) {
  const boundary = 'beak-limit-boundary';
  final body = BytesBuilder(copy: false)
    ..add(
      utf8.encode(
        '--$boundary\r\n'
        'content-disposition: form-data; name="file"; filename="a.bin"\r\n'
        'content-type: application/octet-stream\r\n\r\n',
      ),
    )
    ..add(bytes)
    ..add(utf8.encode('\r\n--$boundary--\r\n'));
  return Request(
    'POST',
    Uri.parse('http://localhost$path'),
    headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
    body: body.takeBytes(),
  );
}

void main() {
  late Handler handler;

  setUp(() {
    const model = _ArchiveModel();
    final service = UploadService(
      registry: BeakModelRegistry()..register(model),
      storage: BeakMemoryStorageDriver(),
      transformRunner: const ImageTransformRunner(),
    );
    final router = Router();
    final handlers = BeakUploadHandlers(
      model: model,
      service: service,
      fallbackMaxSizeInBytes: 100,
    );
    router.post('/<columnKey>/upload', handlers.upload);
    handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(router.call);
  });

  test('a column with no limit is held to the server default', () async {
    final within = await handler(multipart('/blob/upload', Uint8List(100)));
    expect(within.statusCode, 201);
    final over = await handler(multipart('/blob/upload', Uint8List(101)));
    expect(over.statusCode, 422);
    expect(await over.readAsString(), contains('exceeds the limit of 100'));
  });

  test(
    'a limit the column sets wins over the default, larger or smaller',
    () async {
      final larger = await handler(multipart('/huge/upload', Uint8List(500)));
      expect(larger.statusCode, 201);
      final over = await handler(multipart('/huge/upload', Uint8List(1001)));
      expect(over.statusCode, 422);
    },
  );

  test('the default limit is 100 MiB', () {
    expect(BeakUploadHandlers.defaultMaxSizeInBytes, 100 * 1024 * 1024);
  });
}
