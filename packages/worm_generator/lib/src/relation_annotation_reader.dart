/// Reads relation annotations from `@Table` model classes.
library;

import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';
import 'package:worm/worm.dart';

const Map<String, RelationDescriptorKind> _supportedRelations =
    <String, RelationDescriptorKind>{
      'HasOne': RelationDescriptorKind.one,
      'BelongsTo': RelationDescriptorKind.one,
      'MorphOne': RelationDescriptorKind.one,
      'HasOneThrough': RelationDescriptorKind.one,
      'HasMany': RelationDescriptorKind.many,
      'BelongsToMany': RelationDescriptorKind.many,
      'MorphMany': RelationDescriptorKind.many,
      'MorphToMany': RelationDescriptorKind.many,
      'HasManyThrough': RelationDescriptorKind.many,
    };

/// Reads every supported relation annotation on [element] and
/// returns the matching [RelationDescriptor]s in field-declaration
/// order.
///
/// Fields without a recognised relation annotation are skipped.
/// `@MorphTo` is intentionally not emitted as a single
/// [RelationDescriptor] — its child type is dynamic at runtime
/// and the foundation epic emits only typed constants.
List<RelationDescriptor> readRelations(ClassElement element) {
  final relations = <RelationDescriptor>[];
  for (final field in element.fields) {
    final descriptor = _readRelationField(field, parentClassName: element.name);
    if (descriptor != null) relations.add(descriptor);
  }
  return relations;
}

RelationDescriptor? _readRelationField(
  FieldElement field, {
  required String parentClassName,
}) {
  for (final meta in field.metadata) {
    final entry = _matchRelationAnnotation(meta);
    if (entry == null) continue;
    final relatedClassName = _relatedClassName(entry.reader);
    if (relatedClassName == null) continue;
    final foreignKey =
        _stringFromReader(entry.reader, 'foreignKey') ??
        _defaultForeignKey(parentClassName);
    final localKey = _stringFromReader(entry.reader, 'localKey') ?? 'id';
    return RelationDescriptor(
      dartName: field.name,
      relatedClassName: relatedClassName,
      kind: entry.kind,
      foreignKey: foreignKey,
      localKey: localKey,
    );
  }
  return null;
}

String? _stringFromReader(ConstantReader reader, String name) {
  final field = reader.peek(name);
  if (field == null || field.isNull) return null;
  if (!field.isString) return null;
  return field.stringValue;
}

/// Default `snake_case_parent_id` convention used when an
/// annotation does not pin an explicit foreign key.
String _defaultForeignKey(String parentClassName) {
  final snake = StringBuffer();
  for (var i = 0; i < parentClassName.length; i++) {
    final ch = parentClassName[i];
    final lower = ch.toLowerCase();
    if (ch != lower && i > 0) snake.write('_');
    snake.write(lower);
  }
  return '${snake}_id';
}

_RelationAnnotation? _matchRelationAnnotation(ElementAnnotation meta) {
  final value = meta.computeConstantValue();
  if (value == null) return null;
  final type = value.type;
  if (type == null) return null;
  final typeName = type.getDisplayString(withNullability: false);
  final kind = _supportedRelations[typeName];
  if (kind == null) return null;
  return _RelationAnnotation(reader: ConstantReader(value), kind: kind);
}

String? _relatedClassName(ConstantReader reader) {
  final related = reader.peek('related')?.typeValue;
  if (related == null) return null;
  return related.getDisplayString(withNullability: false);
}

final class _RelationAnnotation {
  const _RelationAnnotation({required this.reader, required this.kind});

  final ConstantReader reader;
  final RelationDescriptorKind kind;
}
