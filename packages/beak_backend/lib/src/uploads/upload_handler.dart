import 'dart:convert';
import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/shelf_multipart.dart';

import '../auth/beak_policy.dart';
import '../server/middleware/auth_middleware.dart';
import '../server/middleware/json_middleware.dart';
import 'upload_service.dart';

/// The thin Shelf handlers behind one model's upload surface: they consult
/// the [policy], parse the multipart body into a typed [BeakUpload]
/// (bounded by the column's size limit before buffering the whole part),
/// and delegate to the service.
final class BeakUploadHandlers {
  /// Creates upload handlers for [model] delegating to [service], gated by
  /// [policy].
  const BeakUploadHandlers({
    required this.model,
    required this.service,
    this.policy = const BeakAllowAllPolicy(),
  });

  /// The model whose file columns these handlers serve.
  final BeakModel model;

  /// The upload service the handlers delegate to.
  final UploadService service;

  /// The authorization gate consulted before storing or removing files.
  final BeakPolicy policy;

  /// The multipart field the file must arrive under.
  static const String fileFieldName = 'file';

  /// `POST /<columnKey>/upload` — stores a validated upload (allowed for
  /// principals that may create records of this model).
  // --8<-- [start:upload]
  Future<Response> upload(Request request, String columnKey) async {
    enforcePolicyDecision(
      allowed: policy.canCreate(beakPrincipal(request), model.table),
      principal: beakPrincipal(request),
      action: 'upload to',
      table: model.table,
    );
    final upload = await _readUpload(request, _sizeLimitFor(columnKey));
    final stored = await service.handle(
      table: model.table,
      columnKey: columnKey,
      upload: upload,
    );
    return Response(201, body: jsonEncode(stored.toJson()));
  }
  // --8<-- [end:upload]

  /// `DELETE /<columnKey>/upload` — removes the stored file named by the
  /// posted `{"key": ...}` (allowed for principals that may delete records
  /// of this model).
  Future<Response> remove(Request request, String columnKey) async {
    final body = await readJsonObject(request);
    final String key = switch (body['key']) {
      final String value => value,
      final Object? other => throw BeakValidationException(
        'Request body must carry a "key" string, got $other.',
      ),
    };
    enforcePolicyDecision(
      allowed: policy.canDeleteUpload(
        beakPrincipal(request),
        model.table,
        columnKey,
        key,
      ),
      principal: beakPrincipal(request),
      action: 'delete uploads of',
      table: model.table,
    );
    await service.remove(model.table, columnKey, key);
    return Response(204);
  }

  int? _sizeLimitFor(String columnKey) =>
      switch (model.columnByKey(columnKey)) {
        BeakFileColumn(:final maxSizeInBytes) => maxSizeInBytes,
        BeakImageColumn(:final maxSizeInBytes) => maxSizeInBytes,
        _ => null,
      };

  Future<BeakUpload> _readUpload(Request request, int? maxSizeInBytes) async {
    final form = request.formData();
    if (form == null) {
      throw const BeakValidationException(
        'Upload requests must be multipart/form-data with a '
        '"$fileFieldName" field.',
      );
    }
    await for (final data in form.formData) {
      if (data.name != fileFieldName) {
        await data.part.drain<void>();
        continue;
      }
      final Uint8List bytes = await _readBounded(data.part, maxSizeInBytes);
      final String mimeType =
          data.part.headers['content-type']?.split(';').first.trim() ??
          'application/octet-stream';
      return BeakUpload(
        filename: data.filename ?? fileFieldName,
        mimeType: mimeType,
        bytes: bytes,
      );
    }
    throw const BeakValidationException(
      'The multipart body has no "$fileFieldName" field.',
    );
  }

  /// Buffers [source], failing as soon as it grows past [maxSizeInBytes] —
  /// oversize uploads never buffer fully.
  Future<Uint8List> _readBounded(
    Stream<List<int>> source,
    int? maxSizeInBytes,
  ) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in source) {
      builder.add(chunk);
      if (maxSizeInBytes != null && builder.length > maxSizeInBytes) {
        throw BeakValidationException(
          'Upload rejected.',
          fieldErrors: {
            'size': ['The file exceeds the limit of $maxSizeInBytes bytes.'],
          },
        );
      }
    }
    return builder.takeBytes();
  }
}
