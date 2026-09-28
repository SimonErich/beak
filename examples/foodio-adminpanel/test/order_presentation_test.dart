import 'package:beak/panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodio_adminpanel/resources/orders/forms/order_items_table.dart';
import 'package:foodio_adminpanel/resources/orders/presentations/order_presentations.dart';

void main() {
  test('private profile metadata uses active saved payment methods', () {
    final profile = BeakRecord(
      values: BeakRecord.fromRow({
        'kind': 'private',
        'payment_mode': 'card',
      }).values,
      relations: {
        'customer': [
          BeakRecord(
            values: const {},
            relations: {
              'paymentMethods': [
                BeakRecord.fromRow({
                  'id': 'visa',
                  'name': 'Visa •••• 4242',
                  'kind': 'card',
                  'active': true,
                  'is_default': true,
                }),
                BeakRecord.fromRow({
                  'id': 'paypal',
                  'name': 'PayPal',
                  'kind': 'paypal',
                  'active': true,
                }),
                BeakRecord.fromRow({
                  'id': 'inactive',
                  'name': 'Old account',
                  'kind': 'paypal',
                  'active': false,
                }),
              ],
            },
          ),
        ],
      },
    );
    expect(
      profileIdentity().details.first.readFrom(profile),
      'Visa •••• 4242 · PayPal as backup',
    );
  });

  test(
    'review previews overrides while saved addresses retain their snapshot',
    () {
      BeakRecord order(bool override) => BeakRecord(
        values: BeakRecord.fromRow({
          'address_override': override,
          'street': 'One-time street 12',
          'postal_code': '1040',
          'city': 'Wien',
        }).values,
        relations: {
          'location': [
            BeakRecord.fromRow({
              'street': 'Saved location 3',
              'postal_code': '1040',
              'city': 'Wien',
            }),
          ],
        },
      );
      expect(
        orderAddress().readFrom(order(true)),
        'One-time street 12, 1040 Wien',
      );
      expect(
        orderAddress().readFrom(order(false)),
        'Saved location 3, 1040 Wien',
      );
      expect(
        orderAddress(saved: true).readFrom(order(false)),
        'One-time street 12, 1040 Wien',
      );
    },
  );

  test('menu catalog shows allergens and excludes exact allergen tokens', () {
    final catalog = orderItems(catalog: true).catalog!;
    BeakRecord variant(String allergens, {String diet = 'vegetarian'}) =>
        BeakRecord(
          values: BeakRecord.fromRow({
            'id': 'regular',
            'name': 'Regular',
            'price_cents': 1190,
          }).values,
          relations: {
            'dish': [
              BeakRecord.fromRow({
                'id': 'dish',
                'name': 'Risotto',
                'category': 'Mains',
                'allergens': allergens,
                'diet': diet,
              }),
            ],
          },
        );
    expect(catalog.presentation, BeakCatalogPresentation.rows);
    final gluten = catalog.filters.singleWhere(
      (filter) => filter.label == 'Without A · gluten',
    );
    final milk = catalog.filters.singleWhere(
      (filter) => filter.label == 'Without G · milk',
    );
    expect(gluten.matches!(variant('G,L,O')), isTrue);
    expect(milk.matches!(variant('G,L,O')), isFalse);
    expect(gluten.matches!(variant(' A , C , G , H ')), isFalse);
    expect(gluten.matches!(variant('')), isTrue);
    expect(
      catalog.template.subtitle
          .firstWhere((binding) => binding.badge)
          .readFrom(variant('G,L,O')),
      ['G', 'L', 'O'],
    );
    expect(
      catalog.template.subtitle.first.readFrom(variant('G,L,O')),
      'Vegetarian main',
    );
    expect(
      catalog.template.subtitle.first.readFrom(
        variant('G,L,O', diet: 'vegan,mildly spicy'),
      ),
      'Vegan main',
    );
    expect(
      catalog.template.subtitle.first.readFrom(variant('G,L,O', diet: '')),
      'Classic main',
    );
  });

  test(
    'cancelled order identity wins over unresolved approval and payment flags',
    () {
      final binding = orderStatus();
      expect(
        binding.readFrom(
          BeakRecord.fromRow({
            'status': 'cancelled',
            'approval_status': 'pending',
            'payment_status': 'pending',
          }),
        ),
        'Cancelled',
      );
      expect(
        binding.readFrom(
          BeakRecord.fromRow({
            'status': 'confirmed',
            'approval_status': 'pending',
            'payment_status': 'pending',
          }),
        ),
        'Approval needed',
      );
    },
  );
}
