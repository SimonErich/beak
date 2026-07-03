import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// The thin typed transport over Beak's REST surface: it serializes the
/// shared `beak_core` wire types to the backend's endpoints and maps error
/// bodies back onto the typed exception family — user code never sees
/// HTTP.
final class BeakClient {
  /// Creates a client against [baseUrl] (e.g. `http://localhost:8080`).
  ///
  /// [httpClient] injects the transport for tests; [tokenProvider] supplies
  /// the Bearer token attached to every request (return `null` while
  /// logged out).
  BeakClient({
    required String baseUrl,
    http.Client? httpClient,
    String? Function()? tokenProvider,
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _http = httpClient ?? http.Client(),
       _tokenProvider = tokenProvider;

  final String _baseUrl;
  final http.Client _http;
  final String? Function()? _tokenProvider;

  /// Runs [spec] against `POST /api/{table}/query`.
  Future<BeakPage<BeakRecord>> query(String table, BeakQuerySpec spec) async {
    final response = await _postJson('/api/$table/query', spec.toJson());
    return BeakPage.fromJson(
      _decodeObject(response.body),
      (item) => BeakRecord.fromJson(_asObject(item)),
    );
  }

  /// Fetches one record; `null` when the backend answers 404.
  Future<BeakRecord?> getOne(String table, Object id) async {
    final response = await _http.get(
      _uri('/api/$table/$id'),
      headers: _headers(),
    );
    if (response.statusCode == 404) {
      return null;
    }
    _ensureSuccess(response);
    return BeakRecord.fromJson(_decodeObject(response.body));
  }

  /// Creates a record via `POST /api/{table}`.
  Future<BeakRecord> create(String table, BeakRecord data) async {
    final response = await _postJson('/api/$table', _flatValues(data));
    return BeakRecord.fromJson(_decodeObject(response.body));
  }

  /// Partially updates a record via `PATCH /api/{table}/{id}`.
  Future<BeakRecord> update(String table, Object id, BeakRecord data) async {
    final response = await _http.patch(
      _uri('/api/$table/$id'),
      headers: _headers(json: true),
      body: jsonEncode(_flatValues(data)),
    );
    _ensureSuccess(response);
    return BeakRecord.fromJson(_decodeObject(response.body));
  }

  /// Deletes a record via `DELETE /api/{table}/{id}` (`?force=true` hard
  /// deletes).
  Future<void> delete(String table, Object id, {bool force = false}) async {
    final response = await _http.delete(
      _uri('/api/$table/$id', {if (force) 'force': 'true'}),
      headers: _headers(),
    );
    _ensureSuccess(response);
  }

  /// Fetches many records in one round trip via `POST /api/{table}/batch`.
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) async {
    final response = await _postJson('/api/$table/batch', {'ids': ids});
    return [
      for (final item in _decodeList(response.body))
        BeakRecord.fromJson(_asObject(item)),
    ];
  }

  /// Links [relatedIds] through a to-many relation.
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async {
    await _postJson('/api/$table/$id/relations/$relationKey/attach', {
      'ids': relatedIds,
    });
  }

  /// Unlinks [relatedIds] from a to-many relation.
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async {
    await _postJson('/api/$table/$id/relations/$relationKey/detach', {
      'ids': relatedIds,
    });
  }

  /// Uploads [file] to a file/image column via multipart form data.
  Future<BeakStoredFile> upload(
    String table,
    String columnKey,
    BeakUpload file,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/$table/$columnKey/upload'),
    );
    request.headers.addAll(_headers());
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        file.bytes,
        filename: file.filename,
        contentType: MediaType.parse(file.mimeType),
      ),
    );
    final response = await http.Response.fromStream(await _http.send(request));
    _ensureSuccess(response);
    return BeakStoredFile.fromJson(_decodeObject(response.body));
  }

  /// Searches every searchable model via `GET /api/search`, flattening the
  /// grouped response in table order.
  Future<List<BeakSearchHit>> search(String term) async {
    final response = await _http.get(
      _uri('/api/search', {'q': term}),
      headers: _headers(),
    );
    _ensureSuccess(response);
    final results = switch (_decodeObject(response.body)['results']) {
      final Map<String, Object?> grouped => grouped,
      final Object? other => throw BeakConfigurationException(
        'Search response must carry a "results" object, got $other.',
      ),
    };
    return [
      for (final hits in results.values)
        for (final hit in switch (hits) {
          final List<Object?> list => list,
          final Object? other => throw BeakConfigurationException(
            'Search results must be lists of hits, got $other.',
          ),
        })
          BeakSearchHit.fromJson(_asObject(hit)),
    ];
  }

  /// Releases the underlying HTTP client.
  void close() => _http.close();

  Future<http.Response> _postJson(String path, Object body) async {
    final response = await _http.post(
      _uri(path),
      headers: _headers(json: true),
      body: jsonEncode(body),
    );
    _ensureSuccess(response);
    return response;
  }

  Uri _uri(String path, [Map<String, String>? queryParameters]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: queryParameters);

  Map<String, String> _headers({bool json = false}) {
    final String? token = _tokenProvider?.call();
    return {
      if (json) 'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    };
  }

  /// Flattens a record to the `{column: wireValue}` body the write
  /// endpoints expect.
  Map<String, Object?> _flatValues(BeakRecord data) => {
    for (final MapEntry(:key, :value) in data.values.entries)
      key: value.toJson(),
  };

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    final Map<String, Object?> body = _errorBody(response);
    final String message = switch (body['message']) {
      final String text => text,
      _ => 'HTTP ${response.statusCode}.',
    };
    throw switch (body['code']) {
      'validation' => BeakValidationException(
        message,
        fieldErrors: _fieldErrors(body),
      ),
      'not_found' => BeakNotFoundException(message),
      'authentication' => BeakAuthenticationException(message),
      'authorization' => BeakAuthorizationException(message),
      'conflict' => BeakConflictException(message),
      'storage' => BeakStorageException(message),
      _ => BeakConfigurationException(message),
    };
  }

  Map<String, Object?> _errorBody(http.Response response) {
    try {
      return _decodeObject(response.body);
    } on FormatException {
      return const {};
    } on BeakConfigurationException {
      return const {};
    }
  }

  Map<String, List<String>> _fieldErrors(Map<String, Object?> body) =>
      switch (body['fieldErrors']) {
        final Map<String, Object?> raw => {
          for (final MapEntry(:key, :value) in raw.entries)
            key: [
              for (final message in switch (value) {
                final List<Object?> list => list,
                _ => const <Object?>[],
              })
                message.toString(),
            ],
        },
        _ => const {},
      };

  Map<String, Object?> _decodeObject(String body) =>
      _asObject(jsonDecode(body));

  List<Object?> _decodeList(String body) => switch (jsonDecode(body)) {
    final List<Object?> list => list,
    final Object? other => throw BeakConfigurationException(
      'Expected a JSON array response, got $other.',
    ),
  };

  Map<String, Object?> _asObject(Object? json) => switch (json) {
    final Map<String, Object?> map => map,
    final Object? other => throw BeakConfigurationException(
      'Expected a JSON object, got $other.',
    ),
  };
}
