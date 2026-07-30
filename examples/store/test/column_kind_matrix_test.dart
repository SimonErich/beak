import 'package:beak/beak.dart';
import 'package:store/beak/registry.g.dart';
import 'package:test/test.dart';

/// Every column kind Beak has, one enum value each.
///
/// The point of the enum is that it can be enumerated: [BeakColumn] is a
/// sealed hierarchy, and Dart cannot list a sealed type's subtypes at
/// runtime. So [_kindOf] switches over the hierarchy exhaustively — adding a
/// fourteenth column type stops this file compiling until someone adds an arm
/// — and the arm forces a value here, which this test then demands the store
/// demonstrate.
///
/// That chain is the whole mechanism: a new column kind cannot ship without
/// an example, and the docs that quote `examples/store` cannot fall behind
/// the framework.
enum _ColumnKind {
  string,
  text,
  richText,
  integer,
  decimal,
  boolean,
  dateTime,
  enumeration,
  json,
  color,
  image,
  file,
  custom,
}

/// Which kind [column] is.
_ColumnKind _kindOf(BeakColumn column) => switch (column) {
  BeakStringColumn() => _ColumnKind.string,
  BeakTextColumn() => _ColumnKind.text,
  BeakRichTextColumn() => _ColumnKind.richText,
  BeakIntColumn() => _ColumnKind.integer,
  BeakDecimalColumn() => _ColumnKind.decimal,
  BeakBoolColumn() => _ColumnKind.boolean,
  BeakDateTimeColumn() => _ColumnKind.dateTime,
  BeakEnumColumn() => _ColumnKind.enumeration,
  BeakJsonColumn() => _ColumnKind.json,
  BeakColorColumn() => _ColumnKind.color,
  BeakImageColumn() => _ColumnKind.image,
  BeakFileColumn() => _ColumnKind.file,
  BeakCustomColumn() => _ColumnKind.custom,
};

void main() {
  test('every column kind is demonstrated by a model in this example', () {
    final registry = buildBeakRegistry();
    final demonstrated = <_ColumnKind, List<String>>{};
    for (final model in registry.all) {
      for (final column in model.columns) {
        demonstrated
            .putIfAbsent(_kindOf(column), () => [])
            .add('${model.table}.${column.key}');
      }
    }

    final missing = [
      for (final kind in _ColumnKind.values)
        if (!demonstrated.containsKey(kind)) kind.name,
    ];
    expect(
      missing,
      isEmpty,
      reason:
          'examples/store is the sole source for the Schema and Panel doc '
          'pages, so a column kind with no model here is a kind with no '
          'documentation. Add a field of that kind to a schema class under '
          'lib/models/ and run `beak prepare`.\n'
          'Demonstrated: ${demonstrated.keys.map((k) => k.name).join(', ')}',
    );
  });
}
