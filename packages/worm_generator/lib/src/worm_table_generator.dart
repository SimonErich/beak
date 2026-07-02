/// `source_gen` generator for `@Table` models.
library;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:worm/worm.dart';

import 'relation_annotation_reader.dart';

/// Reads annotated Dart classes and emits worm code.
///
/// For every class annotated with `@Table`, generates a
/// companion class, hydration extension, query starter, and
/// scope metadata via the worm codegen library.
class WormTableGenerator extends GeneratorForAnnotation<Table> {
  /// Creates a [WormTableGenerator].
  const WormTableGenerator();

  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@Table can only be applied to classes.',
        element: element,
      );
    }
    await _warnIfQueryBuilderUnresolved(buildStep);
    final tableName =
        annotation.peek('name')?.stringValue ??
        NamingConvention.tableName(element.name);
    final columns = <ColumnDescriptor>[];
    for (final field in element.fields) {
      final annotation = _columnAnnotation(field);
      if (annotation == null) continue;
      columns.add(_toColumnDescriptor(field, annotation));
    }
    final descriptor = ModelDescriptor(
      className: element.name,
      tableName: tableName,
      columns: columns,
      scopes: _readScopes(element),
      globalScopes: _readGlobalScopes(element),
      relations: readRelations(element),
    );
    final connection = annotation.peek('connection')?.stringValue ?? 'default';
    final source = WormFileGenerator(descriptor).generate();
    final accessors = _renderAccessorExtension(element);
    final annotations = _renderAnnotationsMixin(element, connection);
    final parts = <String>[
      source,
      if (accessors.isNotEmpty) accessors,
      if (annotations.isNotEmpty) annotations,
    ];
    return parts.join('\n');
  }

  /// Emits a `mixin _\$<Name>Annotations on Model` carrying the
  /// override getters wired by `@Hidden`, `@CastAs`, `@Fillable`,
  /// `@Guarded`, and a non-default `@Table(connection:)`. Users opt in
  /// by writing `class User extends Model with _$UserAnnotations`.
  ///
  /// Returns the empty string when the model has none of these
  /// annotations and targets the default connection, so models that
  /// don't need the mixin pay no source cost.
  String _renderAnnotationsMixin(ClassElement element, String connection) {
    final data = _readAnnotationMetadata(element);
    final routesConnection = connection != 'default';
    if (data.isEmpty && !routesConnection) return '';
    final lines = <String>[
      '/// Generated annotation overrides for ${element.name}.',
      'mixin _\$${element.name}Annotations on Model {',
    ];
    if (routesConnection) lines.add(_renderConnectionGetter(connection));
    if (data.hidden.isNotEmpty) lines.add(_renderHiddenGetter(data.hidden));
    if (data.fillable.isNotEmpty) {
      lines.add(_renderListGetter('fillable', data.fillable));
    }
    if (data.guarded.isNotEmpty) {
      lines.add(_renderListGetter('guarded', data.guarded));
    }
    if (data.casts.isNotEmpty) lines.add(_renderCastManager(data.casts));
    // Tautological describe() override — required by the AC even
    // though the [Model.describe] default already produces the same
    // shape. Keeping it explicit makes generator output greppable.
    lines.add(_renderDescribeOverride());
    lines.add('}');
    return lines.join('\n');
  }

  _AnnotationMetadata _readAnnotationMetadata(ClassElement element) {
    final hidden = <String>{};
    final casts = <String, String>{};
    final fillable = <String>[];
    final guarded = <String>[];

    for (final field in element.fields) {
      final dbName = _columnDbName(field);
      for (final meta in field.metadata) {
        final value = meta.computeConstantValue();
        if (value == null) continue;
        final type = value.type?.getDisplayString(withNullability: false);
        switch (type) {
          case 'Hidden':
            hidden.add(dbName);
          case 'CastAs':
            final castType = ConstantReader(value).peek('castType')?.typeValue;
            final castName = castType?.getDisplayString(withNullability: false);
            if (castName != null) casts[dbName] = castName;
        }
      }
    }
    for (final meta in element.metadata) {
      final value = meta.computeConstantValue();
      if (value == null) continue;
      final type = value.type?.getDisplayString(withNullability: false);
      switch (type) {
        case 'Fillable':
          fillable.addAll(_readStringList(ConstantReader(value), 'fields'));
        case 'Guarded':
          guarded.addAll(_readStringList(ConstantReader(value), 'fields'));
      }
    }
    return _AnnotationMetadata(
      hidden: hidden.toList(growable: false),
      casts: casts,
      fillable: fillable,
      guarded: guarded,
    );
  }

  String _columnDbName(FieldElement field) {
    for (final meta in field.metadata) {
      final reader = _readerFor(meta, 'Column');
      if (reader == null) continue;
      final explicit = reader.peek('name')?.stringValue;
      if (explicit != null) return explicit;
      break;
    }
    return NamingConvention.toSnakeCase(field.name);
  }

  List<String> _readStringList(ConstantReader reader, String name) {
    final raw = reader.peek(name)?.listValue;
    if (raw == null) return const <String>[];
    final out = <String>[];
    for (final entry in raw) {
      final str = entry.toStringValue();
      if (str != null) out.add(str);
    }
    return out;
  }

  String _renderConnectionGetter(String connection) => [
    '  @override',
    "  String get connectionName => '$connection';",
  ].join('\n');

  String _renderHiddenGetter(List<String> hidden) {
    final entries = hidden.map((h) => "'$h'").join(', ');
    return [
      '  @override',
      '  Set<String> get hiddenFromSerialization => const <String>{$entries};',
    ].join('\n');
  }

  String _renderListGetter(String name, List<String> values) {
    final entries = values.map((v) => "'$v'").join(', ');
    return [
      '  @override',
      '  List<String> get $name => const <String>[$entries];',
    ].join('\n');
  }

  String _renderCastManager(Map<String, String> casts) {
    final entries = casts.entries
        .map((e) => "        '${e.key}': const ${e.value}(),")
        .join('\n');
    return [
      '  @override',
      '  CastManager get castManager => CastManager(',
      '    <String, AttributeCast>{',
      entries,
      '    },',
      '  );',
    ].join('\n');
  }

  String _renderDescribeOverride() => [
    '  @override',
    '  SerializationDescriptor describe() => SerializationDescriptor(',
    '    fields: toRow(),',
    '    hidden: hiddenFromSerialization,',
    '    appended: computedAttributes,',
    '  );',
  ].join('\n');

  /// Emits a `extension <Parent>Accessors on <Parent>` block with one
  /// `HasManyAccessor` / `HasOneAccessor` getter per `@HasMany` /
  /// `@HasOne` field. Returns an empty string when no such field
  /// exists so unchanged callers see byte-identical output.
  String _renderAccessorExtension(ClassElement element) {
    final getters = <String>[];
    for (final field in element.fields) {
      for (final meta in field.metadata) {
        final getter = _renderAccessorGetter(element.name, field.name, meta);
        if (getter == null) continue;
        getters.add(getter);
        break;
      }
    }
    if (getters.isEmpty) return '';
    return [
      '/// Relation accessors for ${element.name}.',
      'extension ${element.name}Accessors on ${element.name} {',
      getters.join('\n\n'),
      '}',
    ].join('\n');
  }

  String? _renderAccessorGetter(
    String parentName,
    String fieldName,
    ElementAnnotation meta,
  ) {
    final value = meta.computeConstantValue();
    if (value == null) return null;
    final type = value.type?.getDisplayString(withNullability: false);
    final reader = ConstantReader(value);
    final relatedType = reader.peek('related')?.typeValue;
    if (relatedType == null) return null;
    final relatedClassName = relatedType.getDisplayString(
      withNullability: false,
    );
    switch (type) {
      case 'HasMany':
      case 'HasOne':
        return _renderHasAccessorGetter(
          parentName: parentName,
          fieldName: fieldName,
          relatedClassName: relatedClassName,
          reader: reader,
          isMany: type == 'HasMany',
        );
      case 'BelongsToMany':
        return _renderBelongsToManyAccessorGetter(
          parentName: parentName,
          fieldName: fieldName,
          relatedClassName: relatedClassName,
          reader: reader,
        );
      default:
        return null;
    }
  }

  String _renderHasAccessorGetter({
    required String parentName,
    required String fieldName,
    required String relatedClassName,
    required ConstantReader reader,
    required bool isMany,
  }) {
    final fk =
        reader.peek('foreignKey')?.stringValue ??
        '${NamingConvention.toSnakeCase(parentName)}_id';
    final accessor = isMany ? 'HasManyAccessor' : 'HasOneAccessor';
    final relation = isMany ? 'HasManyRelation' : 'HasOneRelation';
    return [
      '  /// ${isMany ? 'Has-many' : 'Has-one'} accessor for `$fieldName`.',
      '  $accessor<$parentName, $relatedClassName> get $fieldName\$ =>',
      '      $accessor<$parentName, $relatedClassName>(',
      '        parent: this,',
      '        resolveAdapter: () => Worm.adapter(connectionName),',
      '        relation: const $relation<$parentName, $relatedClassName>(',
      "          name: '$fieldName',",
      '          childTable: $relatedClassName\$.tableName,',
      "          foreignKey: '$fk',",
      '          hydrateChild: ${relatedClassName}Hydration.fromRow,',
      '        ),',
      '      );',
    ].join('\n');
  }

  String _renderBelongsToManyAccessorGetter({
    required String parentName,
    required String fieldName,
    required String relatedClassName,
    required ConstantReader reader,
  }) {
    final pivotTable =
        reader.peek('pivotTable')?.stringValue ??
        _pivotTableConvention(parentName, relatedClassName);
    final parentPivotKey =
        reader.peek('foreignPivotKey')?.stringValue ??
        '${NamingConvention.toSnakeCase(parentName)}_id';
    final relatedPivotKey =
        reader.peek('relatedPivotKey')?.stringValue ??
        '${NamingConvention.toSnakeCase(relatedClassName)}_id';
    return [
      '  /// Belongs-to-many accessor for `$fieldName`.',
      '  BelongsToManyAccessor<$parentName, $relatedClassName> '
          'get $fieldName\$ =>',
      '      BelongsToManyAccessor<$parentName, $relatedClassName>(',
      '        parent: this,',
      '        relation: const '
          'BelongsToManyRelation<$parentName, $relatedClassName>(',
      "          name: '$fieldName',",
      '          relatedTable: $relatedClassName\$.tableName,',
      "          pivotTable: '$pivotTable',",
      "          parentPivotKey: '$parentPivotKey',",
      "          relatedPivotKey: '$relatedPivotKey',",
      '          hydrateRelated: ${relatedClassName}Hydration.fromRow,',
      '        ),',
      '      );',
    ].join('\n');
  }

  /// Conventional pivot table name: snake_case of both class names,
  /// joined alphabetically (e.g. `User` × `Role` → `role_user`).
  String _pivotTableConvention(String parentName, String relatedName) =>
      NamingConvention.pivotTableName(parentName, relatedName);

  ConstantReader? _columnAnnotation(FieldElement field) {
    for (final meta in field.metadata) {
      final reader = _readerFor(meta, 'Column');
      if (reader != null) return reader;
    }
    return null;
  }

  ColumnDescriptor _toColumnDescriptor(
    FieldElement field,
    ConstantReader column,
  ) {
    final dbName =
        column.peek('name')?.stringValue ??
        NamingConvention.toSnakeCase(field.name);
    final dartType = field.type.getDisplayString(withNullability: true);
    final baseType = _stripNullable(dartType);
    return ColumnDescriptor(
      dartName: field.name,
      dbName: dbName,
      dartType: baseType,
      isNullable: field.type.nullabilitySuffix == NullabilitySuffix.question,
      fieldKind: _kindFor(baseType),
    );
  }

  List<ScopeDescriptor> _readScopes(ClassElement element) {
    final scopes = <ScopeDescriptor>[];
    for (final method in element.methods) {
      for (final meta in method.metadata) {
        final reader = _readerFor(meta, 'Scope');
        if (reader == null) continue;
        final scopeName = reader.peek('name')?.stringValue ?? method.name;
        scopes.add(
          ScopeDescriptor(
            name: scopeName,
            parameters: <ScopeParameter>[
              for (final param in method.parameters)
                ScopeParameter(
                  name: param.name,
                  type: param.type.getDisplayString(withNullability: true),
                ),
            ],
          ),
        );
        break;
      }
    }
    return scopes;
  }

  List<String> _readGlobalScopes(ClassElement element) {
    final globals = <String>[];
    for (final meta in element.metadata) {
      final reader = _readerFor(meta, 'GlobalScope');
      if (reader == null) continue;
      final type = reader.peek('scopeType')?.typeValue;
      if (type == null) continue;
      globals.add(type.getDisplayString(withNullability: false));
    }
    return globals;
  }

  ConstantReader? _readerFor(ElementAnnotation meta, String typeName) {
    final value = meta.computeConstantValue();
    if (value == null) return null;
    final type = value.type;
    if (type == null) return null;
    if (type.getDisplayString(withNullability: false) != typeName) return null;
    return ConstantReader(value);
  }

  Future<void> _warnIfQueryBuilderUnresolved(BuildStep buildStep) async {
    // Narrow catch: only the legitimate "worm asset missing" case is
    // demoted to a warning. Any other resolver failure is unexpected
    // and propagates so it cannot silently corrupt the generated code.
    final LibraryElement library;
    try {
      library = await buildStep.resolver.libraryFor(
        AssetId('worm', 'lib/worm.dart'),
      );
    } on AssetNotFoundException {
      log.warning(
        'Could not resolve package:worm/worm.dart; QueryBuilder '
        'availability cannot be verified.',
      );
      return;
    }
    if (library.exportNamespace.get('QueryBuilder') == null) {
      log.warning(
        'QueryBuilder is not exported from package:worm/worm.dart; '
        'generated query starters will not compile.',
      );
    }
  }

  FieldKind _kindFor(String dartType) => switch (dartType) {
    'String' => FieldKind.string,
    'int' || 'double' || 'num' || 'DateTime' => FieldKind.comparable,
    _ => FieldKind.plain,
  };

  String _stripNullable(String dartType) => dartType.endsWith('?')
      ? dartType.substring(0, dartType.length - 1)
      : dartType;
}

/// Pure-data carrier for the annotations consumed by the runtime
/// annotation mixin: snake_case DB column names for `@Hidden`,
/// a snake_case-name → cast-class-name map for `@CastAs`, and the
/// raw lists from `@Fillable` / `@Guarded`.
///
/// Per the constitution, the carrier only holds `String`s and
/// `List<String>`s — no analyzer types leak into data classes.
final class _AnnotationMetadata {
  const _AnnotationMetadata({
    required this.hidden,
    required this.casts,
    required this.fillable,
    required this.guarded,
  });

  final List<String> hidden;
  final Map<String, String> casts;
  final List<String> fillable;
  final List<String> guarded;

  bool get isEmpty =>
      hidden.isEmpty && casts.isEmpty && fillable.isEmpty && guarded.isEmpty;
}
