import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'category.dart';
part 'category_attribute.beak.dart';

/// How a category attribute should be interpreted.
enum AttributeValueType {
  /// Free text.
  text,

  /// A numeric value.
  number,

  /// The literal value true or false.
  boolean,

  /// One of the configured choices.
  choice,
}

/// A reusable category attribute, such as roast or material.
@Resource()
final class CategoryAttribute extends BeakSchema {
  /// Attribute label.
  @Display()
  @Column(searchable: true)
  late final String name;

  /// Optional guidance for entering the value.
  late final String? description;

  /// Expected value shape.
  @Column(defaultValue: AttributeValueType.text)
  late final AttributeValueType valueType;

  /// Comma-separated choices when the type is choice.
  late final String? choices;

  /// Whether products should supply this attribute.
  late final bool required;

  /// Category that owns this definition.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final Category category;
}
