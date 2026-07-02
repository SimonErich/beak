/// Emits the typed `Model$` companion class.
library;

import 'column_descriptor.dart';
import 'model_descriptor.dart';
import 'relation_descriptor.dart';

/// Generates the companion class with typed `Field` constants
/// per `@Column`, plus typed `RelationField` constants per
/// declared relation.
final class CompanionGenerator {
  /// Creates a [CompanionGenerator] for [descriptor].
  const CompanionGenerator(this.descriptor);

  /// The model the companion is generated for.
  final ModelDescriptor descriptor;

  /// Renders the companion class source.
  String generate() {
    final buffer = StringBuffer()
      ..writeln('/// Generated companion class for ${descriptor.className}.')
      ..writeln('class ${descriptor.companionName} {')
      ..writeln('  ${descriptor.companionName}._();')
      ..writeln()
      ..writeln('  /// The database table name.')
      ..writeln("  static const String tableName = '${descriptor.tableName}';");

    for (final column in descriptor.columns) {
      buffer
        ..writeln()
        ..writeln(_renderColumnField(column));
    }
    for (final relation in descriptor.relations) {
      buffer
        ..writeln()
        ..writeln(_renderRelationField(relation));
    }
    buffer.writeln('}');
    return buffer.toString();
  }

  String _renderRelationField(RelationDescriptor relation) {
    final type =
        'RelationField<${descriptor.className}, ${relation.relatedClassName}>';
    final name = relation.dartName;
    final localKey = relation.localKey == 'id'
        ? ''
        : ', localKey: ${_quote(relation.localKey)}';
    return <String>[
      '  /// Relation reference for `$name`.',
      '  static const $type $name = RelationField(',
      '    ${_quote(name)},',
      '    foreignKey: ${_quote(relation.foreignKey)}$localKey,',
      '  );',
    ].join('\n');
  }

  String _quote(String literal) => "'$literal'";

  String _renderColumnField(ColumnDescriptor column) {
    final fieldType = _fieldType(column);
    final dartName = column.dartName;
    final dbName = column.dbName;
    return [
      '  /// Field reference for `${column.dartName}`.',
      '  static const $fieldType $dartName = $fieldType(',
      "    '$dbName',",
      '  );',
    ].join('\n');
  }

  String _fieldType(ColumnDescriptor column) => switch (column.fieldKind) {
    FieldKind.string => 'StringField',
    FieldKind.comparable => 'ComparableField<${column.dartType}>',
    FieldKind.plain => 'Field<${column.dartType}>',
  };
}
