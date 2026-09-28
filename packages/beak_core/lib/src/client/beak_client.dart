import '../data/beak_export_data_source.dart';
import 'dart:convert';

import '../data/beak_access_capabilities.dart';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../common/beak_exception.dart';
import '../data/beak_commit.dart';
import '../formatting/beak_format_policy.dart';
import '../query/beak_aggregate_spec.dart';
import '../query/beak_summary_spec.dart';
import '../query/beak_page.dart';
import '../query/beak_query_spec.dart';
import '../query/beak_record.dart';
import '../search/beak_search_hit.dart';
import '../storage/beak_stored_file.dart';
import 'beak_session.dart';
import '../storage/beak_upload.dart';
import '../validation/beak_validation_data_source.dart';

/// The thin typed transport over Beak's REST surface: it serializes the
/// shared `beak_core` wire types to the backend's endpoints and maps error
/// bodies back onto the typed exception family — user code never sees
/// HTTP.
///
/// It is the raw REST escape hatch; most app code should go through a
/// `BeakDataSource` (which wraps this client) instead. Reach for it directly
/// only when you need one-off access to an endpoint.
///
/// ```dart
/// final client = BeakClient(
///   baseUrl: 'http://localhost:8080',
///   tokenProvider: () => session.bearerToken, // null while logged out
/// );
///
/// final page = await client.query(
///   'products',
///   const BeakQuerySpec(table: 'products'),
/// );
///
/// client.close(); // release the underlying HTTP client when done
/// ```
///
/// Every call throws a typed [BeakException] (for example
/// [BeakValidationException] or [BeakNotFoundException]) decoded from the
/// backend's error body.
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

  /// The origin this client calls, without a trailing slash.
  String get baseUrl => _baseUrl;

  /// Resolves current field permissions through the resource API.
  Future<BeakAccessCapabilities> capabilities(
    String table, {
    Object? id,
  }) async {
    final response = await _http.get(
      _uri('/api/${Uri.encodeComponent(table)}/capabilities', {
        if (id != null) 'id': id.toString(),
      }),
      headers: _headers(),
    );
    _ensureSuccess(response);
    return BeakAccessCapabilities.fromJson(_decodeObject(response.body));
  }

  /// Checks trusted server-side model constraints without saving the candidate.
  Future<BeakValidationReport> validateRecord(
    BeakValidationRequest request,
  ) async {
    final response = await _postJson(
      '/api/${Uri.encodeComponent(request.table)}/validate',
      request.toJson(),
    );
    return BeakValidationReport.fromJson(_decodeObject(response.body));
  }

  /// Submits a complete draft graph; the response states atomic or staged mode.
  Future<BeakSaveResult> commit(BeakSavePlan plan) async {
    final response = await _postJson('/api/commits', plan.toJson());
    return BeakSaveResult.fromJson(_decodeObject(response.body));
  }

  /// Resolves a lost response through the server's authoritative receipt.
  Future<BeakSaveResult> recoverCommit(String saveId) async {
    final response = await _http.get(
      _uri('/api/commits/${Uri.encodeComponent(saveId)}'),
      headers: _headers(),
    );
    _ensureSuccess(response);
    return BeakSaveResult.fromJson(_decodeObject(response.body));
  }

  /// Signs in through the generated `/api/auth/login`.
  ///
  /// Feed the returned token back through `tokenProvider` (the panel's
  /// session store does this for you) and every later call is authenticated.
  ///
  /// Throws a [BeakAuthenticationException] when the credentials are wrong.
  Future<BeakSession> login({
    required String username,
    required String password,
  }) async {
    final response = await _postJson('/api/auth/login', {
      'username': username,
      'password': password,
    });
    return BeakSession.fromJson(_decodeObject(response.body));
  }

  /// Ends [token]'s session through `/api/auth/logout`.
  ///
  /// The server forgets the token, so a copy of it elsewhere stops working
  /// too — which is the point of an opaque session token.
  Future<void> logout(String token) async {
    final response = await _http.post(
      _uri('/api/auth/logout'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
      },
      body: jsonEncode(const <String, Object?>{}),
    );
    _ensureSuccess(response);
  }

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
  ///
  /// Pass [ifUnmodifiedSince] — the `updated_at` the record carried when it
  /// was read — to make the write conditional: if someone else saved in the
  /// meantime the API answers 409 and this throws a [BeakConflictException],
  /// instead of silently overwriting their work.
  Future<BeakRecord> update(
    String table,
    Object id,
    BeakRecord data, {
    DateTime? ifUnmodifiedSince,
  }) async {
    final response = await _http.patch(
      _uri('/api/$table/$id'),
      headers: {
        ..._headers(json: true),
        if (ifUnmodifiedSince != null)
          'if-unmodified-since': ifUnmodifiedSince.toUtc().toIso8601String(),
      },
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

  /// Restores a soft-deleted record via `POST /api/{table}/{id}/restore`.
  Future<BeakRecord> restore(String table, Object id) async {
    final response = await _postJson('/api/$table/$id/restore', const {});
    _ensureSuccess(response);
    return BeakRecord.fromJson(_decodeObject(response.body));
  }

  /// Computes an aggregate via `POST /api/{table}/aggregate`.
  Future<num> aggregate(String table, BeakAggregateSpec spec) async {
    final response = await _postJson('/api/$table/aggregate', spec.toJson());
    return switch (_decodeObject(response.body)['value']) {
      final num value => value,
      final Object? other => throw BeakConfigurationException(
        'Aggregate response must carry a numeric "value", got $other.',
      ),
    };
  }

  /// Computes named server-side aggregates over a complete query population.
  Future<BeakSummaryResult> summary(BeakSummarySpec spec) async {
    final response = await _postJson(
      '/api/${spec.table}/summary',
      spec.toJson(),
    );
    return BeakSummaryResult.fromJson(_decodeObject(response.body));
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

  /// Resolves an existing upload without assuming a public storage origin.
  Future<Uri> uploadUrl(String table, String columnKey, String key) async {
    final response = await _http.get(
      _uri('/api/$table/$columnKey/upload', {'key': key}),
      headers: _headers(),
    );
    _ensureSuccess(response);
    final body = _decodeObject(response.body);
    final url = body['url'];
    if (url is! String) {
      throw const BeakConfigurationException('Invalid upload URL response.');
    }
    return Uri.parse(url);
  }

  /// Discards an uncommitted upload, including all generated renditions.
  /// Missing files are already discarded, making interrupted cleanup retryable.
  Future<void> discardUpload(
    String table,
    String columnKey,
    BeakStoredFile file,
  ) async {
    for (final key in {...file.variants.values.map((v) => v.key), file.key}) {
      final response = await _http.delete(
        _uri('/api/$table/$columnKey/upload'),
        headers: _headers(json: true),
        body: jsonEncode({'key': key}),
      );
      if (response.statusCode != 404) _ensureSuccess(response);
    }
  }

  /// Exports [spec]'s rows as CSV via `POST /api/{table}/export`.
  Future<String> export(
    String table,
    BeakQuerySpec spec, {
    BeakFormatPolicy? formatting,
    List<String>? columns,
    Map<String, BeakExportFormat> formats = const {},
    bool raw = false,
  }) async {
    if (raw && (formatting != null || formats.isNotEmpty)) {
      throw const BeakConfigurationException(
        'Raw exports cannot also request display formatting.',
      );
    }
    final response = await _postJson('/api/$table/export', {
      ...spec.toJson(),
      'columns': ?columns,
      if (formats.isNotEmpty)
        'formats': {
          for (final entry in formats.entries) entry.key: entry.value.toJson(),
        },
      if (formatting != null) 'formatting': formatting.toJson(),
      if (raw) 'raw': true,
    });
    return response.body;
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
