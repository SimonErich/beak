import 'package:beak/panel.dart';
import '../models/category.dart';
import '../models/category_attribute.dart';

/// Category content, with definitions configured after an inline-created save.
BeakFormLayout categoryForm({bool includeAttributes = true}) => BeakFormLayout(
  children: [
    BeakTabs(
      tabs: [
        BeakTab(
          title: 'Overview',
          children: [
            BeakCard(
              title: 'Category',
              description: 'Organize the catalog into meaningful groups.',
              children: [
                CategoryModel.name.inputText(),
                CategoryModel.description.inputText(),
              ],
            ),
          ],
        ),
        if (includeAttributes)
          BeakTab(
            title: 'Attribute definitions',
            children: [
              BeakSection(
                title: 'Product specifications',
                description:
                    'Define the attributes that products in this category can use.',
                children: [
                  CategoryModel.attributes.tableForm(
                    label: 'Attributes',
                    removeBehavior: BeakRemoveBehavior.deleteOwned,
                    children: [
                      CategoryAttributeModel.name.inputText(),
                      CategoryAttributeModel.valueType.input(),
                      CategoryAttributeModel.required.inputToggle(),
                    ],
                    advancedForm: BeakFormLayout(
                      children: [
                        CategoryAttributeModel.description.inputText(),
                        CategoryAttributeModel.choices.inputText(
                          label: 'Allowed values',
                          description:
                              'Separate choices with commas, for example: light, medium, dark.',
                          visibleIf: (state) =>
                              state.asCategoryAttribute.valueType ==
                              AttributeValueType.choice,
                          validate: const [BeakRequired()],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    ),
  ],
);
