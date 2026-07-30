/// The source `beak make:*` scaffolds.
///
/// One template: the annotated schema class. Everything downstream of it —
/// the typed columns, the model, both sides of every relationship, the typed
/// record view and the migration — is derived by `beak prepare` from that one
/// declaration, so `--fields` is written exactly once and has nowhere to
/// drift out of step.
library;

import 'field_spec.dart';

/// Returns the Dart source of the `@Resource` schema class for
/// [resourceName].
///
/// The field's Dart type selects the column kind, and its nullability decides
/// required-ness — one rule covering the form validator, the API's validation
/// and the column's `NOT NULL`. A trailing `!` in `--fields` marks a field
/// required, mirroring Dart.
///
/// ```dart
/// final specs = BeakFieldSpec.parseList('name:string!,price:decimal!');
/// final source = generateSchemaClass('Product', specs);
/// // source declares `@Resource() final class Product extends BeakSchema`.
/// ```
String generateSchemaClass(String resourceName, List<BeakFieldSpec> fields) {
  final out = StringBuffer()
    ..writeln("import 'package:beak/beak.dart';")
    ..writeln("import 'package:beak/schema.dart';")
    ..writeln()
    ..writeln("part '${snakeCaseOf(resourceName)}.beak.dart';")
    ..writeln()
    ..writeln('/// A ${snakeCaseOf(resourceName).replaceAll('_', ' ')}.')
    ..writeln('@Resource(timestamps: true)')
    ..writeln('final class $resourceName extends BeakSchema {');

  final List<BeakFieldSpec> declared = fields.isEmpty
      ? const <BeakFieldSpec>[
          BeakFieldSpec(
            name: 'name',
            kind: BeakFieldKind.string,
            isRequired: true,
          ),
        ]
      : fields;
  var wroteDisplay = false;
  for (final field in declared) {
    // The first string field is what a record is called in a picker, a link
    // and a title, which is right far more often than not.
    final bool isDisplay = !wroteDisplay && field.kind == BeakFieldKind.string;
    wroteDisplay = wroteDisplay || isDisplay;
    out.writeln('  /// ${_labelOf(field)}.');
    if (isDisplay) {
      out.writeln('  @Display()');
    }
    out
      ..writeln('  @Column(${_columnOptionsOf(field).join(', ')})')
      ..writeln(
        '  late final ${_authoringTypeOf(field.kind)}'
        '${field.isRequired ? '' : '?'} ${field.camelName};',
      )
      ..writeln();
  }
  out.writeln('}');
  return out.toString();
}

/// The `@Column` options a scaffolded field carries.
///
/// Chosen from the kind: text is worth searching, numbers and instants are
/// worth sorting, and a boolean is worth filtering. Each is one word to
/// delete when it is wrong.
List<String> _columnOptionsOf(BeakFieldSpec field) => <String>[
  if (field.kind == BeakFieldKind.string || field.kind == BeakFieldKind.text)
    'searchable: true',
  if (field.kind == BeakFieldKind.integer ||
      field.kind == BeakFieldKind.decimal ||
      field.kind == BeakFieldKind.dateTime)
    'sortable: true',
  if (field.kind == BeakFieldKind.boolean) 'filterable: true',
];

/// The authoring Dart type a [BeakFieldKind] is written as.
String _authoringTypeOf(BeakFieldKind kind) => switch (kind) {
  BeakFieldKind.string => 'String',
  BeakFieldKind.text => 'BeakText',
  BeakFieldKind.integer => 'int',
  BeakFieldKind.decimal => 'double',
  BeakFieldKind.boolean => 'bool',
  BeakFieldKind.dateTime => 'DateTime',
};

/// `released_at` -> `Released at`.
String _labelOf(BeakFieldSpec field) {
  final String spaced = field.name.replaceAll('_', ' ');
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}
