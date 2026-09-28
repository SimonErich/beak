import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodio_adminpanel/resources/orders/order_presentations.dart';
import 'package:foodio_adminpanel/resources/orders/order_items.dart';
import 'package:foodio_adminpanel/theme/gabel_theme.dart';
import 'package:foodio_adminpanel/theme/gabel_tokens.dart';

void main() {
  for (final allergens in ['G', 'H']) {
    testWidgets(
      'options disclose only allergens additional to their dish $allergens',
      (tester) async {
        final table = orderItems(
          catalog: true,
        ).advancedForm!.children.whereType<BeakRelationTable>().single;
        await tester.pumpWidget(
          OiApp(
            theme: gabelTheme(),
            home: BeakRecordTemplateView(
              template: table.catalog!.template,
              record: BeakRecord(
                values: {
                  'id': BeakValue.of('option'),
                  'name': BeakValue.of('Extra'),
                  'price_cents': BeakValue.of(150),
                  'allergens': BeakValue.of(allergens),
                },
                relations: {
                  'dish': [
                    BeakRecord.fromRow({'id': 'dish', 'allergens': 'G,L,O'}),
                  ],
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('contains H · tree nuts'),
          allergens == 'H' ? findsOneWidget : findsNothing,
        );
        expect(find.text('G'), findsNothing);
        expect(
          find.text('H'),
          allergens == 'H' ? findsOneWidget : findsNothing,
        );
        expect(find.textContaining(RegExp(r'^\+.*1[.,]50$')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final sample in [
    ('Soups', 'vegetarian', GabelLight.secondarySoft, OiIcons.soup),
    ('Mains', '', GabelLight.primarySoft, OiIcons.utensils),
    ('Mains', 'vegetarian', GabelLight.catalogVegetableSoft, OiIcons.salad),
    (
      'Mains',
      'vegan,mildly spicy',
      GabelLight.catalogVegetableSoft,
      OiIcons.leaf,
    ),
    (
      'Desserts',
      'vegetarian',
      GabelLight.catalogDessertSoft,
      OiIcons.cakeSlice,
    ),
  ]) {
    testWidgets(
      'catalog ${sample.$1}/${sample.$2} renders its categorical identity',
      (tester) async {
        await tester.pumpWidget(
          OiApp(
            theme: gabelTheme(),
            home: SizedBox(
              width: 650,
              child: BeakRecordTemplateView(
                template: variantIdentity(),
                record: BeakRecord(
                  values: {'id': BeakValue.of('variant')},
                  relations: {
                    'dish': [
                      BeakRecord.fromRow({
                        'id': 'dish',
                        'name': 'Catalog dish',
                        'category': sample.$1,
                        'diet': sample.$2,
                        'allergens': 'H',
                      }),
                    ],
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).color == sample.$3,
          ),
          findsWidgets,
        );
        expect(
          find.byWidgetPredicate(
            (widget) => widget is OiIcon && widget.icon == sample.$4,
          ),
          findsWidgets,
        );
        if (sample.$2.contains('mildly spicy')) {
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is OiBadge &&
                  widget.label == 'Mildly spicy' &&
                  widget.icon == OiIcons.flame,
            ),
            findsOneWidget,
          );
        }
        if (sample.$1 == 'Soups') {
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is OiBadge &&
                  widget.label == 'Vegetarian' &&
                  widget.icon == OiIcons.leaf,
            ),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
