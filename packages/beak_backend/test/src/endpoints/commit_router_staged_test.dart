import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_test/beak_test.dart';
import 'package:test/test.dart';

import '../../support/api_models.dart';

/// Refuses to create authors and nothing else.
final class _NoAuthorsPolicy extends BeakAllowAllPolicy {
  const _NoAuthorsPolicy();

  @override
  bool canCreate(BeakPrincipal? principal, BeakModel model) =>
      model.table != 'authors';
}

BeakSaveOperation _create(String id, String table, Map<String, Object?> row) =>
    BeakSaveOperation(
      id: id,
      kind: BeakSaveOperationKind.create,
      target: BeakRecordRef.draft(table, id),
      values: BeakRecord.fromRow(row),
    );

BeakSavePlan _plan(String saveId, List<BeakSaveOperation> operations) =>
    BeakSavePlan(
      saveId: saveId,
      root: operations.first.target,
      operations: operations,
    );

/// A server whose data source is not worm: the panel's saves go through
/// `POST /api/commits` all the same.
void main() {
  late BeakModelRegistry registry;
  late InMemoryBeakDataSource source;

  setUp(() {
    registry = createApiRegistry();
    source = InMemoryBeakDataSource(registry: registry);
  });

  Handler serve({
    BeakPolicy policy = const BeakAllowAllPolicy(),
    BeakAuthGuard? guard,
  }) => const Pipeline()
      .addMiddleware(beakErrorMappingMiddleware())
      .addMiddleware(beakAuthMiddleware(guard: guard))
      .addHandler(
        beakApiRouter(registry: registry, dataSource: source, policy: policy),
      );

  Future<Response> post(
    Handler handler,
    BeakSavePlan plan, {
    Map<String, String> headers = const {},
  }) async => handler(
    Request(
      'POST',
      Uri.parse('http://localhost/api/commits'),
      body: jsonEncode(plan.toJson()),
      headers: headers,
    ),
  );

  Future<BeakSaveResult> resultOf(Response response) async =>
      switch (jsonDecode(await response.readAsString())) {
        final Map<String, Object?> map => BeakSaveResult.fromJson(map),
        final Object? other => throw StateError('not an object: $other'),
      };

  test('saves a graph through the per-record writes, staged', () async {
    final handler = serve();

    final response = await post(
      handler,
      _plan('one', [
        _create('n', 'notes', {'title': 'Saved'}),
      ]),
    );
    final result = await resultOf(response);

    expect(response.statusCode, 200);
    expect(result.mode, BeakSaveMode.staged);
    expect(result.complete, isTrue);
    expect(result.rootRecord?['title']?.raw, 'Saved');
    expect(source.rowsOf('notes'), hasLength(1));
  });

  test('a replayed save answers from its receipt and writes nothing', () async {
    final handler = serve();
    final plan = _plan('replay', [
      _create('n', 'notes', {'title': 'Once'}),
    ]);

    final first = await resultOf(await post(handler, plan));
    final second = await resultOf(await post(handler, plan));

    expect(second.toJson(), first.toJson());
    expect(source.rowsOf('notes'), hasLength(1));
  });

  test('a lost response is recovered from the receipt', () async {
    final handler = serve();
    await post(
      handler,
      _plan('lost', [
        _create('n', 'notes', {'title': 'Lost'}),
      ]),
    );

    final recovered = await handler(
      Request('GET', Uri.parse('http://localhost/api/commits/lost')),
    );

    expect(recovered.statusCode, 200);
    expect((await resultOf(recovered)).complete, isTrue);
  });

  test('an unknown save id is a 404', () async {
    final response = await serve()(
      Request('GET', Uri.parse('http://localhost/api/commits/never-sent')),
    );

    expect(response.statusCode, 404);
  });

  test('a saveId reused with different content is a 409', () async {
    final handler = serve();
    await post(
      handler,
      _plan('same', [
        _create('n', 'notes', {'title': 'A'}),
      ]),
    );

    final response = await post(
      handler,
      _plan('same', [
        _create('n', 'notes', {'title': 'B'}),
      ]),
    );

    expect(response.statusCode, 409);
    expect(source.rowsOf('notes'), hasLength(1));
  });

  test(
    'a refused operation refuses the whole graph before any write',
    () async {
      final handler = serve(policy: const _NoAuthorsPolicy());

      final response = await post(
        handler,
        _plan('denied', [
          _create('n', 'notes', {'title': 'Would be written first'}),
          _create('a', 'authors', {'name': 'Nope'}),
        ]),
      );
      final result = await resultOf(response);

      expect(response.statusCode, 200);
      expect(result.complete, isFalse);
      expect(
        result.outcomes.map((outcome) => outcome.status),
        everyElement(BeakWriteOutcome.unapplied),
      );
      expect(
        result.outcomes.map((outcome) => outcome.error?.code),
        contains('authentication'),
      );
      expect(source.rowsOf('notes'), isEmpty);
    },
  );

  test('a rule failure stops the save, and earlier writes stay', () async {
    final handler = serve();

    final result = await resultOf(
      await post(
        handler,
        _plan('half', [
          _create('good', 'notes', {'title': 'Fine'}),
          _create('bad', 'notes', {'title': 'x' * 41}),
        ]),
      ),
    );

    expect(result.mode, BeakSaveMode.staged);
    expect(result.complete, isFalse);
    expect(result.outcomes.first.status, BeakWriteOutcome.applied);
    expect(result.outcomes.last.status, BeakWriteOutcome.unapplied);
    expect(result.outcomes.last.error?.code, 'validation');
    expect(source.rowsOf('notes'), hasLength(1));
  });

  test('receipts belong to the principal that saved', () async {
    final handler = serve(guard: _HeaderGuard());
    await post(
      handler,
      _plan('mine', [
        _create('n', 'notes', {'title': 'Mine'}),
      ]),
      headers: const {'x-user': 'sam'},
    );

    final theirs = await handler(
      Request(
        'GET',
        Uri.parse('http://localhost/api/commits/mine'),
        headers: const {'x-user': 'mia'},
      ),
    );
    final ours = await handler(
      Request(
        'GET',
        Uri.parse('http://localhost/api/commits/mine'),
        headers: const {'x-user': 'sam'},
      ),
    );

    expect(theirs.statusCode, 404);
    expect(ours.statusCode, 200);
  });

  test('keeps a bounded number of receipts', () async {
    final handler = const Pipeline()
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: source,
            maxStagedReceipts: 2,
          ),
        );
    for (final id in ['one', 'two', 'three']) {
      await post(
        handler,
        _plan(id, [
          _create(id, 'notes', {'title': id}),
        ]),
      );
    }

    Future<int> recoverStatus(String id) async => (await handler(
      Request('GET', Uri.parse('http://localhost/api/commits/$id')),
    )).statusCode;

    expect(await recoverStatus('one'), 404);
    expect(await recoverStatus('two'), 200);
    expect(await recoverStatus('three'), 200);
  });

  test('there are no durable receipts to prune over another source', () {
    final service = BeakGraphCommitService(registry: registry, source: source);

    expect(
      () => service.pruneReceipts(olderThan: const Duration(days: 30)),
      throwsA(isA<BeakConfigurationException>()),
    );
  });

  test('a service that keeps no receipts is refused', () {
    expect(
      () => BeakGraphCommitService(
        registry: registry,
        source: source,
        maxStagedReceipts: 0,
      ),
      throwsA(isA<BeakConfigurationException>()),
    );
  });

  test('a model behavior still needs an atomic source', () {
    expect(
      () => beakApiRouter(
        registry: registry,
        dataSource: source,
        preparePlan: (plan, transaction, principal) async => plan,
      ),
      throwsA(isA<BeakConfigurationException>()),
    );
  });
}

/// Names the principal from the `x-user` header.
final class _HeaderGuard implements BeakAuthGuard {
  @override
  Future<BeakPrincipal?> authenticate(Request request) async {
    final String? user = request.headers['x-user'];
    return user == null ? null : BeakPrincipal(id: user);
  }
}
