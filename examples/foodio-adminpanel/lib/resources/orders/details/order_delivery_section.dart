import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';

import '../../../domain/foodio_clock.dart';
import '../../../models/models.dart';

/// Shared delivery layout respects the model's stage-based edit permissions.
BeakCard orderDeliveryCard() => BeakCard(
  title: 'Delivery',
  headerTrailing: BeakValueBinding<String>.computed(
    dependencies: [OrderModel.customer.firstName, OrderModel.profile.name],
    compute: (row) =>
        "From ${row.read(OrderModel.customer.firstName) ?? 'the customer'}'s ${row.read(OrderModel.profile.name) ?? 'delivery'} profile",
    maxLines: 1,
  ),
  children: [
    BeakModeLayout(
      read: BeakFormLayout(
        children: [
          BeakColumns(
            children: [
              BeakCalculated(
                label: 'Date',
                presentation: BeakCalculatedPresentation.detail,
                value: (state) => state.asOrder.deliveryDate,
                display: (value, format) => value is BeakDate
                    ? format.calendarDate(value, pattern: 'EEE d MMM yyyy')
                    : format.emptyValue,
                description: (state) =>
                    state.asOrder.deliveryDate == const FoodioClock().today
                    ? 'Today'
                    : 'Scheduled delivery',
              ),
              BeakCalculated(
                label: 'Slot',
                presentation: BeakCalculatedPresentation.detail,
                value: (state) => state.asOrder.slot?.name,
                dependencies: [
                  OrderModel.slot.name,
                  OrderModel.slot.startMinute,
                  OrderModel.slot.reservedOrders,
                  OrderModel.slot.capacity,
                ],
                description: _slotDescription,
              ),
            ],
          ),
          BeakCalculated(
            label: 'Delivery method',
            presentation: BeakCalculatedPresentation.detail,
            value: (state) => orderDeliveryMethod(state.asOrder.deliveryMethod),
            description: (state) => state.asOrder.handover?.isNotEmpty == true
                ? state.asOrder.handover!
                : 'Delivery instructions follow the selected location.',
          ),
          BeakColumns(
            children: [
              BeakCalculated(
                label: 'Location',
                presentation: BeakCalculatedPresentation.detail,
                value: (state) =>
                    [state.asOrder.location?.name, state.asOrder.handover]
                        .whereType<String>()
                        .where((part) => part.isNotEmpty)
                        .join(' — '),
                dependencies: [
                  OrderModel.location.name,
                  OrderModel.location.street,
                  OrderModel.location.postalCode,
                  OrderModel.location.city,
                ],
                description: (state) =>
                    '${state.asOrder.street ?? ''}, ${state.asOrder.postalCode ?? ''} ${state.asOrder.city ?? ''}',
              ),
              BeakCalculated(
                label: 'Contact phone on arrival',
                presentation: BeakCalculatedPresentation.detail,
                value: (state) => state.asOrder.contactPhone,
                description: (_) => 'Used by the driver on arrival.',
              ),
            ],
          ),
          BeakColumns(
            children: [
              BeakCalculated(
                label: 'Delivery note',
                presentation: BeakCalculatedPresentation.detail,
                value: (state) =>
                    state.asOrder.deliveryNote?.trim().isEmpty == true
                    ? null
                    : state.asOrder.deliveryNote,
                description: (state) =>
                    state.asOrder.deliveryNote?.trim().isNotEmpty == true
                    ? 'Visible to the driver'
                    : 'Nothing for the driver',
              ),
              _shippingDetails(BeakCalculatedPresentation.detail),
            ],
          ),
        ],
      ),
      edit: BeakFormLayout(
        children: [
          BeakColumns(
            children: [
              BeakModeLayout(
                read: const BeakFormLayout(children: []),
                edit: BeakFormLayout(
                  children: [
                    BeakCalculated(
                      label: 'Date',
                      presentation: BeakCalculatedPresentation.field,
                      icon: OiIcons.calendar,
                      visibleIf: (state) => !orderIdentityEditable(state),
                      value: (state) => state.asOrder.deliveryDate,
                      display: (value, format) => value is BeakDate
                          ? format.calendarDate(
                              value,
                              pattern: 'EEE d MMM yyyy',
                            )
                          : format.emptyValue,
                      description: (_) =>
                          "The kitchen has started, so the day can't change.",
                    ),
                    OrderModel.deliveryDate.input(
                      label: 'Date',
                      visibleIf: orderIdentityEditable,
                    ),
                  ],
                ),
              ),
              BeakFormLayout(
                spacing: 6,
                children: [
                  OrderModel.slot.inputCombobox(
                    label: 'Slot',
                    validate: const [BeakRequired()],
                    template: BeakRecordTemplate.fields(
                      title: DeliverySlotModel.name,
                    ),
                    options: (state) => DeliverySlotModel.options(
                      filter: BeakAndFilter([
                        DeliverySlotModel.date.eq(
                          state.asOrder.deliveryDate ??
                              const FoodioClock().today,
                        ),
                        DeliverySlotModel.active.eq(true),
                      ]),
                    ),
                  ),
                  BeakCalculated(
                    value: _slotEditDescription,
                    dependencies: [
                      OrderModel.slot.startMinute,
                      OrderModel.slot.reservedOrders,
                      OrderModel.slot.capacity,
                    ],
                    valueStyle: const TextStyle(fontSize: 12, height: 4 / 3),
                  ),
                ],
              ),
            ],
          ),
          OrderModel.deliveryMethod.inputRadio(
            label: 'Delivery method',
            groupLabelAsField: true,
            cards: true,
            minCardWidth: 180,
            cardPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            options: (_) => const [
              BeakInputOption(
                'office',
                'Office delivery',
                description: 'Reception, 3rd floor',
              ),
              BeakInputOption(
                'fridge',
                'Smart fridge',
                description: 'Simmering location only',
              ),
              BeakInputOption(
                'pickup',
                'Pickup at kitchen',
                description: 'Obere Donaustraße 14',
              ),
            ],
          ),
          BeakColumns(
            children: [
              BeakRelationInput(
                field: OrderModel.location,
                label: 'Location',
                validate: const [BeakRequired()],
                descriptionBuilder: (state) =>
                    '${state.asOrder.location?.street ?? ''}, ${state.asOrder.location?.postalCode ?? ''} ${state.asOrder.location?.city ?? ''}',
                template: BeakRecordTemplate(
                  title: BeakValueBinding<String>.computed(
                    dependencies: [
                      DeliveryLocationModel.name,
                      DeliveryLocationModel.handover,
                    ],
                    compute: (row) =>
                        [
                              row.read(DeliveryLocationModel.name),
                              row.read(DeliveryLocationModel.handover),
                            ]
                            .whereType<String>()
                            .where((part) => part.isNotEmpty)
                            .join(' — '),
                  ),
                ),
              ),
              OrderModel.contactPhone.inputText(
                label: 'Contact phone on arrival',
              ),
            ],
          ),
          BeakColumns(
            children: [
              OrderModel.deliveryNote.inputText(
                label: 'Delivery note (optional)',
                multilineContentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                maxLines: 2,
                showCounter: false,
                placeholder: 'Anything the driver should know',
              ),
              _shippingDetails(BeakCalculatedPresentation.field),
            ],
          ),
        ],
      ),
    ),
  ],
);

/// Human-readable delivery method label.
String orderDeliveryMethod(String? method) => switch (method) {
  'office' => 'Office delivery',
  'fridge' => 'Smart fridge',
  'pickup' => 'Pickup at kitchen',
  _ => '—',
};

String _slotDescription(BeakFormReader state) {
  final slot = state.asOrder.slot;
  if (slot == null) return 'Choose a delivery slot';
  final expected = (slot.startMinute + 10).clamp(0, 1439);
  return 'Expected at ${(expected ~/ 60).toString().padLeft(2, '0')}:${(expected % 60).toString().padLeft(2, '0')} · slot ${slot.reservedOrders} of ${slot.capacity} booked';
}

String _slotEditDescription(BeakFormReader state) {
  final slot = state.asOrder.slot;
  if (slot == null) return 'Choose a delivery slot';
  final before = OrderModel.slot.name.readFrom(state.draft.initialRecord);
  final expected = (slot.startMinute + 10).clamp(0, 1439);
  final time =
      '${(expected ~/ 60).toString().padLeft(2, '0')}:${(expected % 60).toString().padLeft(2, '0')}';
  return before != null && before != slot.name
      ? 'Moved from $before · expected at $time'
      : 'Expected at $time · slot ${slot.reservedOrders} of ${slot.capacity} booked';
}

BeakCalculated _shippingDetails(
  BeakCalculatedPresentation presentation,
) => BeakCalculated(
  label: 'Shipping',
  presentation: presentation,
  icon: presentation == BeakCalculatedPresentation.field ? OiIcons.truck : null,
  value: (state) => 'Cooled van · Route ${state.asOrder.routeCode ?? '—'}',
  description: (state) => presentation == BeakCalculatedPresentation.field
      ? 'Set by the location · driver ${state.asOrder.driverName ?? 'not assigned'}'
      : 'Driver ${state.asOrder.driverName ?? 'not assigned'}',
);

/// Whether customer and delivery identity can still be changed at this stage.
bool orderIdentityEditable(BeakFormReader state) => !{
  OrderStatus.inKitchen,
  OrderStatus.outForDelivery,
  OrderStatus.delivered,
  OrderStatus.cancelled,
}.contains(state.asOrder.status);
