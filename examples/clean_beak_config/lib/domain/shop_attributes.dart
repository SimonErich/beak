import 'package:beak/beak.dart';
import '../resources/categories/models/category_attribute.dart';

/// One adapter supplies both dynamic controls and authoritative validation.
BeakAttributeDefinition shopAttributeDefinition(
  BeakRecord record, {
  String? identity,
}) {
  final definition = record.asCategoryAttribute;
  return BeakAttributeDefinition(
    id: identity ?? definition.id ?? definition.name,
    label: definition.name,
    description: definition.description,
    type: switch (definition.valueType) {
      AttributeValueType.text => BeakAttributeType.text,
      AttributeValueType.number => BeakAttributeType.number,
      AttributeValueType.boolean => BeakAttributeType.boolean,
      AttributeValueType.choice => BeakAttributeType.choice,
    },
    required: definition.required,
    choices: shopAttributeChoices(definition.choices),
  );
}

/// Existing catalog choices retain their storage while becoming typed metadata.
List<String> shopAttributeChoices(String? value) => (value ?? '')
    .split(',')
    .map((choice) => choice.trim())
    .where((choice) => choice.isNotEmpty)
    .toSet()
    .toList();
