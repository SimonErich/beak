import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

void main() {
  late Handler handler;
  late WormDataSource source;
  setUp(() async {
    Worm.seedRandom(42);
    final adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    final registry = createApiRegistry();
    source = WormDataSource(registry, adapter: adapter);
    handler = const Pipeline()
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(beakApiRouter(registry: registry, dataSource: source));
  });
  tearDown(Worm.reset);

  test(
    'lost response is recovered over HTTP and replay does not duplicate',
    () async {
      final plan = BeakSavePlan(
        saveId: 'delivery',
        root: const BeakRecordRef.draft('notes', 'draft'),
        operations: [
          BeakSaveOperation(
            id: 'create',
            kind: BeakSaveOperationKind.create,
            target: const BeakRecordRef.draft('notes', 'draft'),
            values: BeakRecord.fromRow({'title': 'Saved'}),
          ),
        ],
      );
      Future<Response> post() async => handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/commits'),
          body: jsonEncode(plan.toJson()),
        ),
      );
      expect((await post()).statusCode, 200); // response deliberately discarded
      final recovered = await handler(
        Request('GET', Uri.parse('http://localhost/api/commits/delivery')),
      );
      expect(recovered.statusCode, 200);
      final decoded = jsonDecode(await recovered.readAsString());
      if (decoded is! Map<String, Object?>) fail('Expected a JSON object.');
      final receipt = BeakSaveResult.fromJson(decoded);
      expect(receipt.complete, isTrue);
      expect(receipt.rootRecord?['title']?.raw, 'Saved');
      expect((await post()).statusCode, 200);
      expect(
        (await source.query(const BeakQuerySpec(table: 'notes'))).total,
        1,
      );
    },
  );

  test('malformed plan is a validation response', () async {
    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/commits'),
        body: '{"operations":[]}',
      ),
    );
    expect(response.statusCode, 422);
  });
}
