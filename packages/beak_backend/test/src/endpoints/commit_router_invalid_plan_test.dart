import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_test/beak_test.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

BeakSaveOperation _create(
  String id,
  String draft, {
  Map<String, Object?> row = const {'title': 'Fine'},
  List<String> dependsOn = const [],
  String table = 'notes',
}) => BeakSaveOperation(
  id: id,
  kind: BeakSaveOperationKind.create,
  target: BeakRecordRef.draft(table, draft),
  values: BeakRecord.fromRow(row),
  dependsOn: dependsOn,
);

BeakSavePlan _plan(List<BeakSaveOperation> operations, {String? table}) =>
    BeakSavePlan(
      saveId: 'invalid',
      root: table == null
          ? operations.first.target
          : BeakRecordRef.draft(table, 'root'),
      operations: operations,
    );

/// A plan that decodes but cannot be executed is the caller's mistake: a 422
/// that names the problem, whichever data source answers.
void main() {
  late BeakModelRegistry registry;

  setUp(() => registry = createApiRegistry());
  tearDown(Worm.reset);

  final invalidPlans = <String, (BeakSavePlan, String)>{
    'an unknown field': (
      _plan([
        _create('a', 'a', row: {'nope': 'x'}),
      ]),
      'Unknown field "nope"',
    ),
    'a duplicate operation id': (
      _plan([_create('same', 'a'), _create('same', 'b')]),
      'Duplicate or empty operation id',
    ),
    'a dependency cycle': (
      _plan([
        _create('a', 'a', dependsOn: const ['b']),
        _create('b', 'b', dependsOn: const ['a']),
      ]),
      'Cyclic save dependencies',
    ),
    'an unregistered table': (
      _plan([_create('a', 'a', table: 'ghosts')]),
      'ghosts',
    ),
    'a dependency on nothing': (
      _plan([
        _create('a', 'a', dependsOn: const ['missing']),
      ]),
      'Unknown dependency',
    ),
  };

  Future<Response> post(Handler handler, BeakSavePlan plan) async => handler(
    Request(
      'POST',
      Uri.parse('http://localhost/api/commits'),
      body: jsonEncode(plan.toJson()),
    ),
  );

  Future<Handler> wormHandler() async {
    final adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    return const Pipeline()
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: WormDataSource(registry, adapter: adapter),
          ),
        );
  }

  Handler stagedHandler() => const Pipeline()
      .addMiddleware(beakErrorMappingMiddleware())
      .addHandler(
        beakApiRouter(
          registry: registry,
          dataSource: InMemoryBeakDataSource(registry: registry),
        ),
      );

  for (final MapEntry(key: name, value: (plan, message))
      in invalidPlans.entries) {
    test('$name is a 422 over a worm source', () async {
      final response = await post(await wormHandler(), plan);
      final body = jsonDecode(await response.readAsString());

      expect(response.statusCode, 422);
      expect(body, containsPair('code', 'validation'));
      expect(body, containsPair('message', contains(message)));
    });

    test('$name is a 422 over any other source', () async {
      final response = await post(stagedHandler(), plan);
      final body = jsonDecode(await response.readAsString());

      expect(response.statusCode, 422);
      expect(body, containsPair('code', 'validation'));
      expect(body, containsPair('message', contains(message)));
    });
  }

  test('an invalid plan writes nothing and leaves no receipt', () async {
    final handler = await wormHandler();
    await post(handler, invalidPlans['an unknown field']!.$1);

    final recovered = await handler(
      Request('GET', Uri.parse('http://localhost/api/commits/invalid')),
    );

    expect(recovered.statusCode, 404);
  });
}
