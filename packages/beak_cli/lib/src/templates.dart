/// The source `beak make:resource`, `beak eject resource` and `beak create`
/// scaffold.
///
/// Two templates. The annotated schema class is the one declaration a
/// resource's data comes from: the typed columns, the model, both sides of
/// every relationship, the typed record view and the migration are derived
/// by `beak prepare` from it, so `--fields` is written exactly once and has
/// nowhere to drift out of step. The `BeakResource` class beside it is how
/// the panel presents that model, and is the project's to edit.
library;

import 'field_spec.dart';
import 'project/beak_emitters.dart';

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

/// Returns the Dart source of a `BeakResource` subclass named [className],
/// configuring the model [modelClass] that [modelImport] declares.
///
/// The class has a `const` zero-argument constructor, which is what lets the
/// generated panel find and build it. [icon], [title] and [navigationGroup]
/// seed it with the presentation `beak.yaml` gave the model's default
/// resource, so taking the resource over changes nothing on screen until the
/// first edit. [icon] names an `OiIcons` member and falls back to the
/// generated default, `table`.
///
/// [authored] is for a project whose `lib/main.dart` it owns: nothing is
/// generated around the class there, so its doc comment says it shows up
/// once the entrypoint's `resources: [...]` lists it, rather than that
/// `beak prepare` swaps it in for a generated default.
///
/// ```dart
/// final source = generateResourceClass(
///   className: 'ProductResource',
///   modelClass: 'ProductModel',
///   modelImport: 'models/product.dart',
///   table: 'products',
/// );
/// // source declares `final class ProductResource extends BeakResource`.
/// ```
String generateResourceClass({
  required String className,
  required String modelClass,
  required String modelImport,
  required String table,
  String? icon,
  String? title,
  String? navigationGroup,
  bool authored = false,
}) {
  final String words = table.replaceAll('_', ' ');
  final arguments = <String>[
    'model: const $modelClass()',
    'icon: const BeakIconToken(OiIcons.${icon ?? 'table'})',
    if (title != null) "title: '${BeakEmitters.escape(title)}'",
    if (navigationGroup != null)
      "navigationGroup: '${BeakEmitters.escape(navigationGroup)}'",
  ];
  final String howItIsShown = authored
      ? '''
/// The panel shows it once the `resources: [...]` list in `lib/main.dart`
/// includes it, and every `BeakResource` option set here shows up there.'''
      : '''
/// `beak prepare` finds this class and uses it in place of the default
/// resource for $words, so every `BeakResource` option set here shows up in
/// the panel. Every other resource stays as Beak generates it.''';
  return """
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import '$modelImport';

/// How the panel presents $words: its table, filters, actions and pages.
///
$howItIsShown
final class $className extends BeakResource {
  /// Creates the $words resource.
  const $className() : super(${arguments.join(', ')});
}
""";
}
