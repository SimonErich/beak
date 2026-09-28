import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/panel_fixtures.dart';

void main() {
  test(
    'a detail without relation requests uses the record lookup contract',
    () async {
      final source = _LookupOnlySource();
      final result = await beakLoadRecordWithRelations(
        BeakResourceRepository(source),
        model: const NoteModel(),
        id: 'n1',
        relations: const [],
      );

      expect(result, isA<BeakOk<BeakRecord>>());
      if (result case BeakOk(:final value)) {
        expect(value['title'], const BeakStringValue('One'));
        expect(value.relations['labels'], hasLength(1));
      }
      expect(source.getOneCalls, hasLength(1));
    },
  );

  test('a missing detail keeps the typed not-found result', () async {
    final result = await beakLoadRecordWithRelations(
      BeakResourceRepository(_LookupOnlySource()),
      model: const NoteModel(),
      id: 'missing',
      relations: const [],
    );

    expect(result, isA<BeakErr<BeakRecord>>());
    if (result case BeakErr(:final error)) {
      expect(error, isA<BeakNotFoundException>());
    }
  });
}

/// A transport with dedicated record lookups and an allowlisted list query.
final class _LookupOnlySource extends FakeDataSource {
  _LookupOnlySource()
    : super(
        records: {
          'notes': {
            'n1': BeakRecord(
              values: const {
                'id': BeakStringValue('n1'),
                'title': BeakStringValue('One'),
              },
              relations: {
                'labels': [
                  BeakRecord.fromRow(const {'name': 'Included'}),
                ],
              },
            ),
          },
        },
      );

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async =>
      throw const BeakConfigurationException('Unsupported list filter.');
}
