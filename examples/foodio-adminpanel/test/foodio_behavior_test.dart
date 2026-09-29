import 'package:beak/beak.dart';
import 'package:foodio_adminpanel/domain/order_behavior.dart';
import 'package:foodio_adminpanel/models/models.dart';
import 'package:test/test.dart';

BeakRecord row(
  Map<String, Object?> values, [
  Map<String, List<BeakRecord>> relations = const {},
]) =>
    BeakRecord(values: BeakRecord.fromRow(values).values, relations: relations);

void main() {
  test(
    'saved payment suggestions choose eligible defaults and retain eligible manual choices',
    () {
      final methods = [
        row({
          'id': 'inactive',
          'kind': 'card',
          'active': false,
          'is_default': true,
        }),
        row({'id': 'card', 'kind': 'card', 'active': true, 'is_default': true}),
        row({
          'id': 'second',
          'kind': 'card',
          'active': true,
          'is_default': false,
        }),
        row({
          'id': 'paypal',
          'kind': 'paypal',
          'active': true,
          'is_default': true,
        }),
      ];
      BeakRecord selection(String mode, [String? selected]) => row(
        {'payment_mode': mode, 'payment_method_id': selected},
        {
          'customer': [
            row({'id': 'customer'}, {'paymentMethods': methods}),
          ],
        },
      );
      final behavior = const OrderModel().behavior;
      expect(
        OrderModel.paymentMethodId.readFrom(
          behavior.apply(selection('card'), overriddenFields: {'payment_mode'}),
        ),
        'card',
      );
      expect(
        OrderModel.paymentMethodId.readFrom(
          behavior.apply(
            selection('card', 'second'),
            overriddenFields: {'payment_mode'},
          ),
        ),
        'second',
      );
      expect(
        OrderModel.paymentMethodId.readFrom(
          behavior.apply(
            selection('paypal', 'card'),
            overriddenFields: {'payment_mode'},
          ),
        ),
        'paypal',
      );
      expect(
        OrderModel.paymentMethodId.readFrom(
          behavior.apply(
            selection('monthlyInvoice', 'card'),
            overriddenFields: {'payment_mode'},
          ),
        ),
        isNull,
      );
    },
  );

  test(
    'operational commands exclude drafts and finished orders while notes remain available',
    () {
      expect(const OrderModel().behavior.actions, OrderActions.all);
      for (final status in [
        OrderStatus.draft,
        OrderStatus.delivered,
        OrderStatus.cancelled,
      ]) {
        final record = row({
          'status': status.name,
          'payment_status': 'failed',
          'approval_status': 'pending',
          'strict_allergy': true,
          'allergy_acknowledged': false,
          'next_action': 'reviewChange',
        });
        for (final action in [
          OrderActions.approve,
          OrderActions.reject,
          OrderActions.requestApproval,
          OrderActions.sendPaymentLink,
          OrderActions.retryPayment,
          OrderActions.acknowledgeAllergy,
          OrderActions.resolveChange,
        ]) {
          expect(
            action.isAvailable(record),
            isFalse,
            reason: '${action.name} on ${status.name}',
          );
        }
        expect(OrderActions.addNote.isAvailable(record), isTrue);
      }
    },
  );

  test('new orders suggest the active default profile and tomorrow', () {
    final customer = row(
      {'id': 'customer'},
      {
        'profiles': [
          row({'id': 'inactive', 'active': false, 'is_default': true}),
          row({'id': 'company', 'active': true, 'is_default': true}),
          row({'id': 'private', 'active': true, 'is_default': false}),
        ],
      },
    );
    final selection = row(
      {'customer_id': 'customer'},
      {
        'customer': [customer],
      },
    );
    final behavior = const OrderModel().behavior;
    final result = behavior.apply(selection);
    expect(OrderModel.profileId.readFrom(result), 'company');
    expect(
      OrderModel.deliveryDate.readFrom(result),
      const BeakDate(2026, 9, 29),
    );
    final explicit = row({
      'customer_id': 'customer',
      'profile_id': 'private',
      'delivery_date': '2026-10-01',
    }, selection.relations);
    final kept = behavior.apply(explicit, overriddenFields: {'profile_id'});
    expect(OrderModel.profileId.readFrom(kept), 'private');
    expect(OrderModel.deliveryDate.readFrom(kept), const BeakDate(2026, 10, 1));
  });

  test(
    'profile suggestions update together and preserve deliberate overrides',
    () {
      BeakRecord order(String profile, String street) => row(
        {'profile_id': profile},
        {
          'profile': [
            row(
              {
                'id': profile,
                'location_id': 'location-$profile',
                'organization_id': 'company-$profile',
                'payment_mode': profile == 'company'
                    ? 'monthlyInvoice'
                    : 'card',
                'cost_center': profile == 'company' ? '4100' : '',
              },
              {
                'location': [
                  row({
                    'street': street,
                    'postal_code': '1010',
                    'city': 'Wien',
                    'method': 'office',
                    'route_code': 'VIE-03',
                  }),
                ],
              },
            ),
          ],
          'customer': [
            row({'phone': '+436642184471'}),
          ],
        },
      );
      final behavior = const OrderModel().behavior;
      final initial = behavior.apply(order('company', 'Office 1'));
      expect(OrderModel.locationId.readFrom(initial), 'location-company');
      expect(OrderModel.street.readFrom(initial), 'Office 1');
      expect(OrderModel.paymentMode.readFrom(initial), 'monthlyInvoice');
      expect(OrderModel.contactPhone.readFrom(initial), '+436642184471');
      final next = order('private', 'Home 2');
      final changed = row({
        ...initial.toRow(),
        ...next.toRow(),
      }, next.relations);
      final computed = behavior.apply(changed, initial: initial);
      expect(OrderModel.locationId.readFrom(computed), 'location-private');
      expect(OrderModel.street.readFrom(computed), 'Home 2');
      expect(OrderModel.paymentMode.readFrom(computed), 'card');
      expect(OrderModel.costCenter.readFrom(computed), '');
      final override = row({
        ...changed.toRow(),
        'street': 'Side entrance',
      }, changed.relations);
      expect(
        OrderModel.street.readFrom(
          behavior.apply(
            override,
            initial: initial,
            overriddenFields: {'street'},
          ),
        ),
        'Side entrance',
      );
    },
  );

  test(
    'variant-only catalog selection supplies required fields and preserves saved prices',
    () {
      BeakRecord selection(String variant, int price) => row(
        {'variant_id': variant},
        {
          'variant': [
            row(
              {
                'id': variant,
                'dish_id': 'dish',
                'name': 'Regular',
                'price_cents': price,
              },
              {
                'dish': [
                  row({
                    'id': 'dish',
                    'name': 'Pumpkin risotto',
                    'tax_basis_points': 1000,
                    'food': true,
                    'allergens': 'G,L',
                  }),
                ],
              },
            ),
          ],
        },
      );
      final behavior = const OrderItemModel().behavior;
      final initial = behavior.apply(selection('regular', 1190));
      expect(OrderItemModel.dishId.readFrom(initial), 'dish');
      expect(OrderItemModel.label.readFrom(initial), 'Pumpkin risotto');
      expect(OrderItemModel.unitPriceCents.readFrom(initial), 1190);
      expect(OrderItemModel.taxBasisPoints.readFrom(initial), 1000);
      expect(OrderItemModel.food.readFrom(initial), isTrue);
      expect(OrderItemModel.allergens.readFrom(initial), 'G,L');
      expect(behavior.relationLoads.toString(), isNotEmpty);
      final repriced = selection('regular', 1290);
      final editedDish = row({'id': 'dish', 'food': false, 'allergens': 'H'});
      final sameDish = row(initial.toRow(), {
        'dish': [editedDish],
      });
      final retained = behavior.apply(sameDish, initial: initial);
      expect(OrderItemModel.food.readFrom(retained), isTrue);
      expect(OrderItemModel.allergens.readFrom(retained), 'G,L');
      final existing = row(initial.toRow(), repriced.relations);
      expect(
        OrderItemModel.unitPriceCents.readFrom(
          behavior.apply(existing, initial: initial),
        ),
        1190,
      );
      final large = selection('large', 1490);
      final changed = row({
        ...initial.toRow(),
        ...large.toRow(),
      }, large.relations);
      expect(
        OrderItemModel.unitPriceCents.readFrom(
          behavior.apply(changed, initial: initial),
        ),
        1490,
      );
    },
  );

  test(
    'catalog option supplies its label and add-on price without a controller',
    () {
      final result = const OrderItemOptionModel().behavior.apply(
        row(
          {'option_id': 'extra'},
          {
            'option': [
              row({
                'id': 'extra',
                'name': 'Extra vegetables',
                'price_cents': 150,
                'allergens': 'G',
              }),
            ],
          },
        ),
      );
      expect(OrderItemOptionModel.label.readFrom(result), 'Extra vegetables');
      expect(OrderItemOptionModel.unitPriceCents.readFrom(result), 150);
      expect(OrderItemOptionModel.allergens.readFrom(result), 'G');
    },
  );
}
