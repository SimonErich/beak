import '../introspect/beak_schema_introspection.dart' show isSecretColumnName;
import 'database_definition.dart';
import 'definition_paths.dart';
import 'definition_checks.dart';
import 'spy_model.dart';

/// Writes a read-only definition class for [spy] into [area].
///
/// [libraryOf] maps an exposed definition class to its library under the
/// definitions package's `lib/`, so a relation imports the real file. The
/// result is the file content; the caller writes it.
String scaffoldDefinition(
  SpyClass spy,
  SpyProject project,
  DatabaseDefinition database, {
  required String area,
  required String package,
  required Map<String, String> libraryOf,
  required String? classDoc,
  required Map<String, String> fieldDocs,
}) {
  final buffer = StringBuffer();
  final enums = <String>{};
  final imports = <String>{};
  final fields = project.fieldsOf(spy);
  for (final field in fields) {
    if (field.relation != null) {
      final target = field.isCollection
          ? field.elementType!
          : _targetOf(field, project);
      if (target == null) continue;
      if (target != spy.name) {
        final library = libraryOf[target];
        if (library == null) {
          throw DefinitionScaffoldException(
            '${spy.name}.${field.name} points at $target, which no definition '
            'class exposes yet. Generate $target first.',
          );
        }
        imports.add('package:$package/$library');
      }
    } else if (project.enums.containsKey(field.baseType)) {
      enums.add('package:$package/src/generated/definitions_support.dart');
    }
  }
  buffer
    ..writeln("import 'package:beak_core/beak_core.dart';")
    ..writeln("import 'package:beak_serverpod/schema.dart';");
  for (final uri in {...enums, ...imports}.toList()..sort()) {
    buffer.writeln("import '$uri';");
  }
  buffer
    ..writeln()
    ..writeln(
      "part 'package:$package/${definitionPartPath(area: area, name: spy.name)}';",
    )
    ..writeln();
  if (classDoc == null || classDoc.trim().isEmpty) {
    buffer.writeln('/// The ${spy.name} admin model.');
  } else {
    for (final line in _docLines(classDoc)) {
      buffer.writeln(line);
    }
  }
  buffer
    ..writeln('@Resource()')
    ..writeln('@ServerpodAdminModel(')
    ..writeln("  area: '${_escape(area)}',")
    ..writeln("  reason: 'Read-only until its admin writes are opened.',")
    ..writeln(')')
    ..writeln('final class ${spy.name} extends BeakSchema {');
  var first = true;
  for (final field in fields) {
    if (field.name == 'id' || !field.persist || field.isServerOnly) continue;
    if (isSecretColumnName(field.name) ||
        isSecretColumnName(field.columnName)) {
      continue;
    }
    if (!first) buffer.writeln();
    first = false;
    final doc = fieldDocs[field.name];
    if (doc != null) {
      for (final line in _docLines(doc)) {
        buffer.writeln('  $line');
      }
    }
    buffer.write(_field(field, project, database, spy));
  }
  buffer.writeln('}');
  return buffer.toString();
}

/// A scaffold that cannot produce compilable code.
final class DefinitionScaffoldException implements Exception {
  /// Creates an exception described by [message].
  const DefinitionScaffoldException(this.message);

  /// What is wrong, and how to fix it.
  final String message;

  @override
  String toString() => message;
}

String _field(
  SpyField field,
  SpyProject project,
  DatabaseDefinition database,
  SpyClass spy,
) {
  final name = field.name;
  final buffer = StringBuffer();
  if (field.relation != null) {
    final kind = field.isCollection
        ? 'HasMany'
        : _relationKind(field, database, spy);
    buffer.write('  @$kind()\n');
    final type = field.isCollection
        ? 'List<${field.elementType}>'
        : field.baseType;
    buffer.write('  late final $type${field.nullable ? '?' : ''} $name;\n');
    return buffer.toString();
  }
  if (const {
    'createdAt',
    'updatedAt',
    'deletedAt',
    'isDeleted',
    'version',
  }.contains(name)) {
    buffer.write('  @ReadOnly()\n');
  }
  final type = field.isCollection ? 'BeakJson' : declaredTypeOf(field, project);
  buffer.write('  late final $type${field.nullable ? '?' : ''} $name;\n');
  return buffer.toString();
}

String? _targetOf(SpyField field, SpyProject project) {
  final relation = field.relation;
  if (relation == null) return null;
  if (relation.parent case final String table) {
    return project.classOfTable(table)?.name;
  }
  return field.baseType;
}

String _relationKind(
  SpyField field,
  DatabaseDefinition database,
  SpyClass spy,
) {
  final table = database.tables[spy.table];
  final key = field.relation?.field ?? '${field.name}Id';
  if (table?.columns.containsKey(key) ?? false) return 'BelongsTo';
  return 'HasOne';
}

String _escape(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

List<String> _docLines(String doc) => [
  for (final line in doc.trim().split('\n')) '/// ${line.trim()}',
];

/// The Serverpod `###` comments above the class and each field.
({String? classDoc, Map<String, String> fields}) readSpyDocs(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  String? classDoc;
  final fields = <String, String>{};
  var inFields = false;
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    if (line.startsWith('class:')) {
      classDoc = _above(lines, index);
      inFields = false;
    } else if (line.trimRight() == 'fields:') {
      inFields = true;
    } else if (inFields && RegExp(r'^  ([A-Za-z_]\w*):').hasMatch(line)) {
      final match = RegExp(r'^  ([A-Za-z_]\w*):').firstMatch(line)!;
      final doc = _above(lines, index, indent: '  ');
      if (doc != null) fields[match.group(1)!] = doc;
    } else if (inFields && line.isNotEmpty && !line.startsWith(' ')) {
      inFields = false;
    }
  }
  return (classDoc: classDoc, fields: fields);
}

String? _above(List<String> lines, int index, {String indent = ''}) {
  final doc = <String>[];
  for (var cursor = index - 1; cursor >= 0; cursor--) {
    final line = lines[cursor];
    if (!line.startsWith('$indent###')) break;
    doc.insert(0, line.substring(indent.length + 3).trimLeft());
  }
  return doc.isEmpty ? null : doc.join('\n');
}
