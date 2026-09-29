import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:beak_test/beak_test.dart';
import 'package:worm/worm.dart';

import '../test_tools/serverpod_test_tools.dart';
import 'support/contract_note.dart';
import 'support/zone_bound_adapter.dart';
import 'support/zoned_data_source.dart';

/// Beak's own `BeakDataSource` contract, on `WormDataSource` over the session
/// adapter, with every call entering the session zone exactly as the engine's
/// `dispatch` does.
void main() {
  withServerpod(
    'BeakDataSource contract',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, endpoints) {
      late ZoneBoundAdapter admin;
      final registry = BeakModelRegistry()..register(const ContractNoteModel());

      runBeakDataSourceContract(
        'WormDataSource over ServerpodSessionAdapter',
        registry: registry,
        model: const ContractNoteModel(),
        create: () async {
          final session = sessionBuilder.build();
          admin = ZoneBoundAdapter(session, ServerpodSessionAdapter());
          for (final ddl in contractNoteSchema) {
            await admin.executeSchema(ddl);
          }
          return ZonedBeakDataSource(
            session,
            WormDataSource(registry, adapter: ServerpodSessionAdapter()),
          );
        },
        seed: (source, model, records) async {
          for (final record in records) {
            await admin.insert(
              InsertDescriptor(table: model.table, values: record.toRow()),
            );
          }
        },
        sortableTextColumn: ContractNoteColumns.title,
        numericColumn: ContractNoteColumns.rating,
      );
    },
  );
}
