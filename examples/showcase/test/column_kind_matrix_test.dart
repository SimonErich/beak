import 'package:beak/beak.dart';
import 'package:showcase/resources/specimens/models/specimen.dart';
import 'package:test/test.dart';

/// Every column kind Beak has, one enum value each.
///
/// [BeakColumn] is a sealed hierarchy, and Dart cannot list a sealed type's
/// subtypes at runtime, so [_kindOf] switches over it exhaustively. Adding a
/// column kind stops this file compiling until someone adds an arm; the arm
/// forces a value here; and this test then demands the `Specimen` schema class
/// has a field of that kind.
///
/// The docs quote `Specimen` for every column kind, so a kind it lacks is a
/// kind nobody can see declared.
// --8<-- [start:ColumnKind]
enum _ColumnKind {
  string,
  text,
  richText,
  int,
  decimal,
  bool,
  dateTime,
  enumeration,
  json,
  color,
  file,
  image,
  custom,
}
// --8<-- [end:ColumnKind]

/// The kind of [column]. There is no default branch on purpose.
// --8<-- [start:kindOf]
_ColumnKind _kindOf(BeakColumn column) => switch (column) {
  BeakStringColumn() => _ColumnKind.string,
  BeakTextColumn() => _ColumnKind.text,
  BeakRichTextColumn() => _ColumnKind.richText,
  BeakIntColumn() => _ColumnKind.int,
  BeakDecimalColumn() => _ColumnKind.decimal,
  BeakBoolColumn() => _ColumnKind.bool,
  BeakDateTimeColumn() => _ColumnKind.dateTime,
  BeakEnumColumn() => _ColumnKind.enumeration,
  BeakJsonColumn() => _ColumnKind.json,
  BeakColorColumn() => _ColumnKind.color,
  BeakFileColumn() => _ColumnKind.file,
  BeakImageColumn() => _ColumnKind.image,
  BeakCustomColumn() => _ColumnKind.custom,
};
// --8<-- [end:kindOf]

void main() {
  test('Specimen declares a field of every column kind', () {
    final declared = {
      for (final column in SpecimenColumns.values) _kindOf(column),
    };

    final missing = [
      for (final kind in _ColumnKind.values)
        if (!declared.contains(kind)) kind.name,
    ];
    expect(
      missing,
      isEmpty,
      reason:
          'The docs quote Specimen for every column kind. Add a field of '
          'each missing kind to lib/resources/specimens/models/specimen.dart '
          'and run `beak prepare`.',
    );
  });

  test('Specimen turns on soft deletes and timestamps', () {
    const specimen = SpecimenModel();
    final keys = {for (final column in specimen.columns) column.key};

    expect(specimen.softDeletes, isTrue);
    expect(keys, containsAll(['created_at', 'updated_at', 'deleted_at']));
  });

  test('semantic fields carry their meaning on the column', () {
    expect(
      SpecimenColumns.acquisitionCost.semantic.kind,
      BeakSemanticKind.money,
    );
    expect(SpecimenColumns.reporterEmail.semantic.kind, BeakSemanticKind.email);
    expect(SpecimenColumns.referenceUrl.semantic.kind, BeakSemanticKind.url);
  });
}
