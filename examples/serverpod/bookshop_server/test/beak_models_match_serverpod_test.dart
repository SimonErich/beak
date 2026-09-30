import 'package:beak_core/beak_core.dart';
import 'package:bookshop_beak/bookshop_beak.dart' as beak;
import 'package:bookshop_server/src/generated/protocol.dart' as sp;
import 'package:test/test.dart';

/// The hand-written Beak schema classes describe tables Serverpod owns.
/// Nothing generates them from the `.spy.yaml` files, so these tests are what
/// turn a rename, a retype or a new enum value on either side into a red
/// build.
void main() {
  final tables = {
    for (final table in sp.Protocol.targetTableDefinitions)
      if (table.module == 'bookshop') table.name: table,
  };

  Set<String> physicalColumns(String table) => {
    for (final column in tables[table]!.columns) column.name,
  };

  Set<String> beakColumns(BeakModel model) => {
    for (final column in model.columns) column.key,
  };

  for (final model in [const beak.AuthorModel(), const beak.BookModel()]) {
    test('every Beak column of ${model.table} is a physical column', () {
      expect(tables, contains(model.table));
      expect(
        beakColumns(model).difference(physicalColumns(model.table)),
        isEmpty,
        reason: 'Beak declares columns the Serverpod table does not have',
      );
    });
  }

  test('the supplier cost is a physical column Beak does not model', () {
    expect(physicalColumns('book'), contains('supplierCostInCents'));
    expect(
      beakColumns(const beak.BookModel()),
      isNot(contains('supplierCostInCents')),
    );
  });

  test('the BookFormat mirror lists the same values as the protocol enum', () {
    expect(
      [for (final value in beak.BookFormat.values) value.name],
      [for (final value in sp.BookFormat.values) value.name],
    );
  });
}
