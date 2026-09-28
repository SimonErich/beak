/// Two people editing the same record is normal in an admin panel, and the
/// silent default — last write wins — is how the first one's work vanishes.
library;

import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

void main() {
  late Handler handler;
  late InMemoryAdapter adapter;
  late BeakModelRegistry registry;
  late String id;

  setUp(() async {
    Worm.seedRandom(42);
    adapter = await createApiTestDatabase();
    registry = createApiRegistry();
    handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: WormDataSource(registry, adapter: adapter),
          ),
        );

    final record = await WormDataSource(registry, adapter: adapter).create(
      'notes',
      BeakRecord(
        values: {
          'id': BeakValue.of('n1'),
          'title': BeakValue.of('original'),
          'updated_at': BeakValue.of(DateTime.utc(2026, 7, 26, 10)),
        },
      ),
    );
    id = '${record['id']?.raw}';
  });

  tearDown(Worm.reset);

  Future<Response> patch(
    Object body, {
    Map<String, String> headers = const {},
  }) async => await handler(
    Request(
      'PATCH',
      Uri.parse('http://localhost/api/notes/$id'),
      body: jsonEncode(body),
      headers: headers,
    ),
  );

  Future<String> currentTitle() async {
    final record = await WormDataSource(
      registry,
      adapter: adapter,
    ).getOne('notes', id);
    return '${record?['title']?.raw}';
  }

  Future<DateTime> currentUpdatedAt() async {
    final record = await WormDataSource(
      registry,
      adapter: adapter,
    ).getOne('notes', id);
    return switch (record?['updated_at']) {
      final BeakDateTimeValue value => value.value,
      final Object? other => throw StateError('no timestamp, got $other'),
    };
  }

  test('an update without the header applies unconditionally', () async {
    // Opt-in: a script, or a panel with one writer, should not have to know
    // about versions at all.
    expect((await patch({'title': 'edited'})).statusCode, 200);
    expect(await currentTitle(), 'edited');
  });

  test('an update matching the stored timestamp applies', () async {
    final DateTime read = await currentUpdatedAt();

    final response = await patch(
      {'title': 'edited'},
      headers: {'if-unmodified-since': read.toIso8601String()},
    );

    expect(response.statusCode, 200);
    expect(await currentTitle(), 'edited');
  });

  test('a stale timestamp is a 409, and the record is untouched', () async {
    final response = await patch(
      {'title': 'clobbered'},
      headers: {'if-unmodified-since': DateTime.utc(2020).toIso8601String()},
    );

    expect(response.statusCode, 409);
    expect(await response.readAsString(), contains('changed since it was'));
    expect(
      await currentTitle(),
      'original',
      reason: 'a rejected update must not have written anything',
    );
  });

  test('the second of two concurrent edits loses, loudly', () async {
    // Both read the same version; the first write moves it.
    final DateTime read = await currentUpdatedAt();

    final first = await patch(
      {'title': 'first'},
      headers: {'if-unmodified-since': read.toIso8601String()},
    );
    final second = await patch(
      {'title': 'second'},
      headers: {'if-unmodified-since': read.toIso8601String()},
    );

    expect(first.statusCode, 200);
    expect(second.statusCode, 409);
    expect(await currentTitle(), 'first');
  });

  test('an unparseable header is a 422, not a silent unconditional write', () {
    expect(
      patch(
        {'title': 'edited'},
        headers: const {'if-unmodified-since': 'last tuesday'},
      ).then((response) => response.statusCode),
      completion(422),
    );
  });
}
