import 'package:beak_core/beak_core.dart';
import 'package:beak_test/beak_test.dart';

import '../support/map_data_source.dart';

// --8<-- [start:mapDataSourceContract]
void main() {
  runBeakDataSourceContract(
    'MapDataSource',
    registry: buildBeakRegistry(),
    model: const NoteModel(),
    create: () async => MapDataSource(buildBeakRegistry()),
    seed: (source, model, records) async =>
        (source as MapDataSource).seed(model.table, records),
  );
}
// --8<-- [end:mapDataSourceContract]

/// Stands in for the model `beak prepare` generates from a schema class.
final class NoteModel extends BeakModel {
  const NoteModel();

  static const id = BeakStringColumn(key: 'id', label: 'Id');
  static const title = BeakStringColumn(
    key: 'title',
    label: 'Title',
    searchable: true,
    sortable: true,
  );

  @override
  String get table => 'notes';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const [id, title];
}

/// Stands in for the function `beak prepare` writes to `lib/beak/registry.g.dart`.
BeakModelRegistry buildBeakRegistry() =>
    BeakModelRegistry()..register(const NoteModel());
