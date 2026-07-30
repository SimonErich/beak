import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_test/beak_test.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../../support/api_models.dart';

/// Runs the shared [BeakDataSource] contract against [WormDataSource].
///
/// This is the point of having an executable contract: the same suite that
/// pins `InMemoryBeakDataSource`'s behaviour now holds the real worm-backed
/// source to it. Where the two disagree, one of them is wrong — and until
/// this existed, nothing said which.
void main() {
  late InMemoryAdapter adapter;

  tearDown(Worm.reset);

  runBeakDataSourceContract(
    'WormDataSource',
    registry: createApiRegistry(),
    model: const NoteModel(),
    create: () async {
      adapter = await createApiTestDatabase();
      return WormDataSource(createApiRegistry(), adapter: adapter);
    },
    seed: (source, model, records) async {
      for (final record in records) {
        await adapter.insert(
          InsertDescriptor(table: model.table, values: record.toRow()),
        );
      }
    },
    sortableTextColumn: NoteColumns.title,
    numericColumn: NoteColumns.rating,
  );
}
