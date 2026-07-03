import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

void main() {
  late Handler handler;
  late WormDataSource dataSource;

  setUp(() async {
    Worm.seedRandom(42);
    final adapter = await createApiTestDatabase();
    final registry = createApiRegistry();
    dataSource = WormDataSource(registry, adapter: adapter);
    handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(beakApiRouter(registry: registry, dataSource: dataSource));

    for (final (index, title) in [
      'Laser manual',
      'Laser tag rules',
      'Laser safety',
      'Grocery list',
    ].indexed) {
      await dataSource.create(
        'notes',
        BeakRecord.fromRow({
          'id': 'n${index + 1}',
          'title': title,
          'body': 'Body mentioning lasers everywhere.',
        }),
      );
    }
    await dataSource.create(
      'labels',
      BeakRecord.fromRow(const {'id': 'l1', 'name': 'laser-tagged'}),
    );
    await dataSource.create(
      'comments',
      BeakRecord.fromRow(const {
        'id': 'c1',
        'note_id': 'n1',
        'message': 'laser laser laser',
      }),
    );
  });

  tearDown(Worm.reset);

  Future<Map<String, Object?>> search(String query) async {
    final response = await handler(
      Request('GET', Uri.parse('http://localhost/api/search?$query')),
    );
    expect(response.statusCode, 200);
    return switch (jsonDecode(await response.readAsString())) {
      final Map<String, Object?> map => map,
      final Object? other => throw StateError('expected object: $other'),
    };
  }

  Map<String, Object?> hitOf(Object? json) => switch (json) {
    final Map<String, Object?> map => map,
    final Object? other => throw StateError('expected a hit: $other'),
  };

  List<Object?> hitsFor(Map<String, Object?> body, String table) =>
      switch (switch (body['results']) {
        final Map<String, Object?> results => results[table],
        final Object? other => throw StateError('expected results: $other'),
      }) {
        final List<Object?> hits => hits,
        null => const [],
        final Object? other => throw StateError('expected hits: $other'),
      };

  test('groups hits per model over searchable columns only', () async {
    final body = await search('q=laser');

    final noteHits = hitsFor(body, 'notes');
    expect(noteHits, hasLength(3), reason: 'three note titles match');
    final first = hitOf(noteHits.first);
    expect(first['table'], 'notes');
    expect(first['displayLabel'], 'Laser manual');
    expect(first['matchedColumnKey'], 'title');

    expect(
      hitsFor(body, 'labels'),
      hasLength(1),
      reason: 'labels.name is searchable',
    );
    expect(
      hitsFor(body, 'comments'),
      isEmpty,
      reason: 'comments has no searchable column — body matches never count',
    );
  });

  test('limits hits per model', () async {
    final body = await search('q=laser&perModel=2');
    expect(hitsFor(body, 'notes'), hasLength(2));
  });

  test('narrows to the requested tables', () async {
    final body = await search('q=laser&tables=labels');
    expect(hitsFor(body, 'notes'), isEmpty);
    expect(hitsFor(body, 'labels'), hasLength(1));
  });

  test('a blank query is a 422', () async {
    final response = await handler(
      Request('GET', Uri.parse('http://localhost/api/search?q=%20')),
    );
    expect(response.statusCode, 422);
  });

  test('a non-numeric perModel is a 422', () async {
    final response = await handler(
      Request(
        'GET',
        Uri.parse('http://localhost/api/search?q=x&perModel=lots'),
      ),
    );
    expect(response.statusCode, 422);
  });

  test('a restrictive policy hides unviewable tables from search', () async {
    final registry = createApiRegistry();
    final restricted = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: dataSource,
            policy: const _NotesOnlyPolicy(),
          ),
        );

    final response = await restricted(
      Request('GET', Uri.parse('http://localhost/api/search?q=laser')),
    );
    final body = switch (jsonDecode(await response.readAsString())) {
      final Map<String, Object?> map => map,
      final Object? other => throw StateError('expected object: $other'),
    };
    expect(hitsFor(body, 'notes'), isNotEmpty);
    expect(hitsFor(body, 'labels'), isEmpty);
  });
}

/// Allows viewing only the notes table.
final class _NotesOnlyPolicy implements BeakPolicy {
  const _NotesOnlyPolicy();

  @override
  bool canView(BeakPrincipal? principal, String table) => table == 'notes';

  @override
  bool canCreate(BeakPrincipal? principal, String table) => false;

  @override
  bool canUpdate(BeakPrincipal? principal, String table, Object id) => false;

  @override
  bool canDelete(BeakPrincipal? principal, String table, Object id) => false;

  @override
  bool canDeleteUpload(
    BeakPrincipal? principal,
    String table,
    String columnKey,
    String storageKey,
  ) => false;
}
