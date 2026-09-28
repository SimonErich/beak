import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;

part 'resource_generator.dart';

/// Resolves [types] from [library] in the consumer's [packageRoot].
///
/// Generation never modifies models or database migrations. Unsupported source
/// shapes fail explicitly instead of becoming stringly typed JSON payloads.
Future<String> generateServerpodCompanions({
  required String packageRoot,
  required String library,
  required List<String> types,
  List<String> models = const [],
  String client = 'Client',
}) async {
  final root = p.normalize(p.absolute(packageRoot));
  final contexts = AnalysisContextCollection(includedPaths: [root]);
  try {
    final session = contexts.contextFor(root).currentSession;
    final result = await session.getLibraryByUri(library);
    if (result is! LibraryElementResult) {
      throw FormatException('Cannot resolve library $library from $root.');
    }
    final emitter = _Emitter();
    for (final name in {...types, ...models}) {
      final element = result.element.exportNamespace.get2(name);
      if (element is! ClassElement) {
        throw FormatException('$library does not export a model named $name.');
      }
      emitter.collect(element);
    }
    if (models.isNotEmpty) {
      final clientType = result.element.exportNamespace.get2(client);
      if (clientType is! ClassElement) {
        throw FormatException('$library does not export client $client.');
      }
      for (final name in models) {
        emitter.resources.add(
          _ResourceEmitter(emitter, emitter.models[name]!, clientType),
        );
      }
    }
    return DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format(emitter.emit());
  } finally {
    await contexts.dispose();
  }
}

final class _Emitter {
  final Map<String, _Model> models = {};
  final Map<String, String> imports = {};
  final List<_ResourceEmitter> resources = [];
  final Map<
    String,
    List<({String name, String key, DartType type, bool nullable})>
  >
  fieldRefs = {};

  void collect(ClassElement element) {
    final name = element.name!;
    final previous = models[name];
    if (previous != null) {
      if (previous.element != element) {
        throw FormatException('Two distinct model types are named $name.');
      }
      return;
    }
    final fields = <String, FieldElement>{};
    for (final parent in element.allSupertypes.reversed) {
      _collectFields(parent.element, fields);
    }
    _collectFields(element, fields);
    final constructor = element.unnamedConstructor;
    if (constructor == null ||
        constructor.isPrivate ||
        constructor.formalParameters.any((parameter) => !parameter.isNamed)) {
      throw FormatException(
        '$name needs a public constructor with named parameters.',
      );
    }
    final model = _Model(element, fields.values.toList());
    models[name] = model;
    _name(element.thisType);
    for (final field in model.fields) {
      _collectType(field.type, '$name.${field.name}');
    }
  }

  void _collectFields(
    InterfaceElement element,
    Map<String, FieldElement> target,
  ) {
    for (final field in element.fields) {
      if (!field.isStatic && field.isOriginDeclaration && !field.isPrivate) {
        target[field.name!] = field;
      }
    }
  }

  void _collectType(DartType type, String path) {
    if (_scalar(type) != null) return;
    if (type is InterfaceType) {
      if (type.isDartCoreList) {
        _collectType(type.typeArguments.single, '$path[]');
        return;
      }
      if (type.element case final ClassElement element
          when !element.library.uri.toString().startsWith('dart:')) {
        collect(element);
        return;
      }
    }
    throw FormatException('Unsupported Serverpod property $path: $type.');
  }

  String _name(DartType type, {bool forceNullable = false}) {
    if (type is! InterfaceType) {
      throw FormatException('Unsupported type $type.');
    }
    final element = type.element;
    final uri = element.library.uri.toString();
    final prefix = uri == 'dart:core'
        ? ''
        : '${imports.putIfAbsent(uri, () => 'i${imports.length}')}.';
    final arguments = type.typeArguments.isEmpty
        ? ''
        : '<${type.typeArguments.map(_name).join(', ')}>';
    return '$prefix${element.name}$arguments${_nullable(type) || forceNullable ? '?' : ''}';
  }

  bool _nullable(DartType type) =>
      type.nullabilitySuffix == NullabilitySuffix.question;

  String? _scalar(DartType type, {bool forceNullable = false}) {
    if (type is! InterfaceType) return null;
    final element = type.element;
    final base = switch (element.name) {
      'String' when type.isDartCoreString => 'ServerpodCodecs.string',
      'int' when type.isDartCoreInt => 'ServerpodCodecs.integer',
      'double' when type.isDartCoreDouble => 'ServerpodCodecs.decimal',
      'bool' when type.isDartCoreBool => 'ServerpodCodecs.boolean',
      'DateTime' when element.library.uri.toString() == 'dart:core' =>
        'ServerpodCodecs.dateTime',
      'Uri' when element.library.uri.toString() == 'dart:core' =>
        'ServerpodCodecs.uri',
      'UuidValue'
          when element.library.uri.toString().startsWith('package:uuid/') =>
        'ServerpodCodecs.uuid',
      _ => null,
    };
    String? codec = base;
    if (element is EnumElement) {
      final enumName = _name(type).replaceAll('?', '');
      codec = 'ServerpodCodecs.enumeration($enumName.values)';
    } else if (type.isDartCoreList || type.isDartCoreSet) {
      final item = _scalar(type.typeArguments.single);
      if (item != null) codec = '$item.${type.isDartCoreList ? 'list' : 'set'}';
    }
    return codec == null
        ? null
        : '$codec${_nullable(type) || forceNullable ? '.nullable' : ''}';
  }

  String emit() {
    final body = StringBuffer();
    for (final model in models.values) {
      body.write(_emitFields(model));
      body.write(_emitRelations(model));
      body.write(_emitCodec(model));
    }
    for (final resource in resources) {
      body.write(resource.emit());
    }
    final orderedImports = imports.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return '''
// GENERATED BY beak_serverpod_generator — DO NOT EDIT.
import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/beak_serverpod.dart';
${orderedImports.map((entry) => "import '${entry.key}' as ${entry.value};").join('\n')}
$body
''';
  }

  String _emitFields(_Model model) {
    final out = StringBuffer('''
/// Typed properties of the existing ${model.name} model.
abstract final class ${model.name}Fields {
''');
    final projections =
        <
          ({
            List<String> path,
            FieldElement field,
            String getter,
            String codec,
            bool nullable,
          })
        >[];
    void walk(
      _Model nested,
      List<String> path,
      String access,
      bool nullable,
      Set<String> ancestors,
    ) {
      for (final field in nested.fields) {
        final key = [...path, field.name!];
        final getter = '$access${nullable ? '?.' : '.'}${field.name}';
        final codec = _scalar(field.type, forceNullable: nullable);
        if (codec != null) {
          projections.add((
            path: key,
            field: field,
            getter: getter,
            codec: codec,
            nullable: nullable,
          ));
        } else if (field.type case final InterfaceType type
            when !type.isDartCoreList &&
                !ancestors.contains(type.element.name)) {
          final child = models[type.element.name];
          if (child != null) {
            walk(child, key, getter, nullable || _nullable(type), {
              ...ancestors,
              child.name,
            });
          }
        }
      }
    }

    walk(model, [], 'value', false, {model.name});
    final counts = <String, int>{};
    for (final projection in projections) {
      counts.update(
        _identifier(projection.path),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final refs = <({String name, String key, DartType type, bool nullable})>[];
    fieldRefs[model.name] = refs;
    for (final projection in projections) {
      final key = projection.path.join('.');
      final compactName = _identifier(projection.path);
      final name = counts[compactName] == 1
          ? compactName
          : projection.path.join('__');
      refs.add((
        name: name,
        key: key,
        type: projection.field.type,
        nullable: projection.nullable || _nullable(projection.field.type),
      ));
      final source = _name(model.element.thisType);
      final value = _name(
        projection.field.type,
        forceNullable: projection.nullable,
      );
      out.writeln('''
/// Generated reference to $key.
static final ServerpodField<$source, $value> $name = ServerpodField(
  key: '$key',
  get: (value) => ${projection.getter},
  codec: ${projection.codec},
  buildColumn: (label, options) => ${_column(projection.field.type, key)},
);
''');
    }
    out.writeln('''
}
/// Enum slots sized to the resolved model's scalar form fields.
enum ${model.name}FormSlot {${List.generate(projections.isEmpty ? 1 : projections.length, (index) => 'field$index').join(', ')}}
''');
    return out.toString();
  }

  String _identifier(List<String> path) =>
      path.first +
      path
          .skip(1)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join();

  String _emitRelations(_Model model) {
    final out = StringBuffer();
    final names = <String>{};
    void walk(
      _Model nested,
      List<String> path,
      String access,
      bool nullable,
      Set<String> ancestors,
    ) {
      for (final field in nested.fields) {
        if (_scalar(field.type) != null) continue;
        final key = [...path, field.name!];
        final compactName = _identifier(key);
        final name = names.add(compactName) ? compactName : key.join('__');
        final getter = '$access${nullable ? '?.' : '.'}${field.name}';
        final shape = _objectShape(field.type);
        out.writeln('''
/// Generated reference to ${key.join('.')} in a complete loaded record.
static final ServerpodRelationField<${_name(model.element.thisType)}, ${_name(field.type, forceNullable: nullable)}> $name = ServerpodRelationField(
  key: '${key.join('.')}',
  get: (value) => $getter,
  codec: const ${model.name}Codec(),
);
''');
        if (!shape.list && !ancestors.contains(shape.model.name)) {
          walk(shape.model, key, getter, nullable || _nullable(field.type), {
            ...ancestors,
            shape.model.name,
          });
        }
      }
    }

    walk(model, [], 'value', false, {model.name});
    if (out.isEmpty) return '';
    return '''
/// Typed object and collection references of the existing ${model.name} model.
abstract final class ${model.name}Relations {
$out
}
''';
  }

  String _column(DartType type, String key) {
    if (type is! InterfaceType) throw FormatException('Unsupported $type.');
    final common =
        "key: '$key', label: label, visibleOn: options.visibleOn, "
        'sortable: options.sortable, searchable: options.searchable, '
        'filterable: options.filterable, rules: options.rules';
    if (type.element is EnumElement) {
      final name = _name(type).replaceAll('?', '');
      return 'BeakEnumColumn<$name>($common, values: $name.values, labelOf: (value) => options.enumLabels[value] ?? value.name)';
    }
    final kind = switch (type.element.name) {
      'int' => 'BeakIntColumn',
      'double' => 'BeakDecimalColumn',
      'bool' => 'BeakBoolColumn',
      'DateTime' => 'BeakDateTimeColumn',
      'List' || 'Set' => 'BeakCustomColumn',
      _ => 'BeakStringColumn',
    };
    return '$kind($common${kind == 'BeakCustomColumn' ? ", tag: const BeakColumnTag('serverpod.collection')" : ''})';
  }

  String _emitCodec(_Model model) {
    final type = _name(model.element.thisType);
    final locals = StringBuffer();
    final values = StringBuffer();
    final relations = StringBuffer();
    for (final field in model.fields) {
      final key = field.name!;
      if (_scalar(field.type) != null) {
        values.writeln("'$key': ${model.name}Fields.$key.encode(value),");
        continue;
      }
      final shape = _objectShape(field.type);
      final child = '${shape.model.name}Codec';
      if (shape.list) {
        final input = _nullable(field.type)
            ? 'value.$key ?? const []'
            : 'value.$key';
        final condition = _nullable(field.type)
            ? 'if (value.$key != null)'
            : '';
        relations.writeln(
          "$condition '$key': [for (final item in $input) const $child().encode(item)],",
        );
      } else {
        final expr = _nullable(field.type)
            ? 'value.$key == null ? null : const $child().encode(value.$key!)'
            : 'const $child().encode(value.$key)';
        locals.writeln('final nested${_capitalize(key)} = $expr;');
        final variable = 'nested${_capitalize(key)}';
        if (_nullable(field.type)) {
          values.writeln(
            "if ($variable == null) '$key': const BeakNullValue(),",
          );
          values.writeln(
            "if ($variable != null) ...serverpodFlatten('$key', $variable),",
          );
          relations.writeln("if ($variable != null) '$key': [$variable],");
        } else {
          values.writeln("...serverpodFlatten('$key', $variable),");
          relations.writeln("'$key': [$variable],");
        }
      }
    }
    final arguments = StringBuffer();
    for (final parameter
        in model.element.unnamedConstructor!.formalParameters) {
      final name = parameter.name!;
      final field = model.fields
          .where((field) => field.name == name)
          .firstOrNull;
      if (field == null) {
        throw FormatException('${model.name}.$name is not a readable field.');
      }
      String value;
      final scalar = _scalar(parameter.type);
      if (scalar != null) {
        final sameType = parameter.type == field.type;
        if (sameType) {
          value =
              '${model.name}Fields.$name.${parameter.isRequiredNamed ? 'readRequired' : 'read'}(record)';
        } else {
          value = "$scalar.decode(record['$name'])";
        }
        if (!parameter.isRequiredNamed &&
            !_nullable(parameter.type) &&
            parameter.defaultValueCode != null) {
          var fallback = parameter.defaultValueCode!;
          if (parameter.type case InterfaceType(element: EnumElement())) {
            final enumType = _name(parameter.type);
            fallback = '$enumType.${fallback.split('.').last}';
          }
          value = "record.values.containsKey('$name') ? $value : $fallback";
        }
      } else {
        final shape = _objectShape(parameter.type);
        final child = '${shape.model.name}Codec';
        if (shape.list) {
          final rows = "requireServerpodRelatedInputs(record, '$name')";
          value = '[for (final item in $rows) const $child().decode(item)]';
          if (_nullable(parameter.type)) {
            value = "record.relations.containsKey('$name') ? $value : null";
          }
        } else {
          value =
              "const $child().decode(requireServerpodNestedInput(record, '$name'))";
          if (_nullable(parameter.type)) {
            value =
                "serverpodNestedInput(record, '$name') == null ? null : $value";
          }
        }
      }
      arguments.writeln('$name: $value,');
    }
    return '''
/// Generated typed conversion for $type.
final class ${model.name}Codec extends ServerpodCodec<$type> {
  /// Creates a stateless generated codec.
  const ${model.name}Codec();
  @override
  BeakRecord encode($type value) {
    $locals
    return BeakRecord(values: {$values}, relations: {$relations});
  }
  @override
  $type decode(BeakRecord record) => $type($arguments);
}
''';
  }

  ({_Model model, bool list}) _objectShape(DartType type) {
    if (type is! InterfaceType) {
      throw FormatException('Unsupported type $type.');
    }
    final list = type.isDartCoreList;
    final child = list ? type.typeArguments.single : type;
    if (child is! InterfaceType ||
        models[child.element.name] == null ||
        (list && _nullable(child))) {
      throw FormatException('Unsupported nested shape $type.');
    }
    return (model: models[child.element.name]!, list: list);
  }

  String _capitalize(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}

final class _Model {
  const _Model(this.element, this.fields);
  final ClassElement element;
  final List<FieldElement> fields;
  String get name => element.name!;
}
