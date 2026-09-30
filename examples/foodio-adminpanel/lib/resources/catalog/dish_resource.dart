import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import '../../models/models.dart';

/// Menu items, sellable sizes and additions share a single staged graph.
BeakResource dishResource() => BeakResource(
  model: const DishModel(),
  title: 'Dishes',
  navigationGroup: 'Kitchen',
  icon: const BeakIconToken(OiIcons.chefHat),
  globalSearchSources: [
    DishModel.name,
    DishModel.description,
    DishModel.allergens,
  ],
  filters: [DishModel.category.textFilter()],
  screens: [
    BeakTableScreen(
      fields: [
        DishModel.name,
        DishModel.category,
        DishModel.diet,
        DishModel.allergens,
        DishModel.active,
      ],
    ),
    BeakFormScreen(
      roles: const {
        BeakScreenRole.create,
        BeakScreenRole.edit,
        BeakScreenRole.read,
      },
      layout: BeakFormLayout(
        children: [
          BeakTabs(
            tabs: [
              BeakTab(
                title: 'Dish details',
                children: [
                  BeakColumns(
                    children: [
                      BeakCard(
                        title: 'On the menu',
                        children: [
                          DishModel.name.inputText(),
                          DishModel.description.inputText(),
                          DishModel.category.inputText(),
                          DishModel.active.inputToggle(),
                        ],
                      ),
                      BeakCard(
                        title: 'Dietary information',
                        children: [
                          DishModel.diet.inputText(),
                          DishModel.allergens.inputText(),
                          DishModel.food.inputToggle(),
                          DishModel.taxBasisPoints.inputNumber(
                            label: 'VAT rate (basis points)',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              BeakTab(
                title: 'Sizes & pricing',
                children: [
                  DishModel.variants.tableForm(
                    label: 'Available sizes',
                    removeBehavior: BeakRemoveBehavior.deleteOwned,
                    minRows: 1,
                    children: [
                      DishVariantModel.name.inputText(),
                      DishVariantModel.priceCents.inputCurrency(
                        label: 'Price',
                        minorUnits: true,
                      ),
                      DishVariantModel.active.inputToggle(),
                    ],
                  ),
                ],
              ),
              BeakTab(
                title: 'Options',
                children: [
                  DishModel.fields.options.tableForm(
                    label: 'Extras and preferences',
                    removeBehavior: BeakRemoveBehavior.deleteOwned,
                    children: [
                      DishOptionModel.name.inputText(),
                      DishOptionModel.priceCents.inputCurrency(
                        label: 'Additional price',
                        minorUnits: true,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  ],
);
