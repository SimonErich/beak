import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';

import '../../../../domain/foodio_clock.dart';
import '../../../../models/models.dart';
import '../order_wizard_bindings.dart';

/// Delivery date, slot, and location selection step.
BeakWizardStep deliveryStep() => BeakWizardStep(
  title: 'Delivery',
  heading: 'When and where should it arrive?',
  introductionBuilder: (state, _) =>
      "The location and delivery method come from ${customerFirstName(state)}'s profile. Pick the day and a slot with free capacity.",
  dependencies: [OrderModel.customer.name],
  spacingInPixels: 24,
  continueLabel: 'Continue to dishes',
  description: 'Date, slot and location',
  completedDescription: (state, format) => [
    if (state.asOrder.deliveryDate != null)
      format.format(state.asOrder.deliveryDate, BeakValueFormat.date),
    state.asOrder.slot?.name,
    state.asOrder.location?.name,
  ].whereType<String>().join(' · '),
  footerHintBuilder: (state, format) =>
      '${format.date((state.asOrder.deliveryDate ?? const FoodioClock().today).toDateTime(), pattern: 'EEEE')}’s kitchen prep list is generated the day before at 16:00.',
  children: [
    BeakSection(
      title: 'Delivery date',
      titleStyle: const TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w600,
      ),
      gapInPixels: 8,
      trailing: BeakValueBinding<String>.computed(
        dependencies: const [],
        compute: (_) => 'Same-day orders close at 10:30.',
        icon: OiIcons.clock,
        color: BeakColor.muted,
        textStyle: const TextStyle(fontSize: 12, height: 4 / 3),
      ),
      children: [
        // --8<-- [start:deliveryDateInput]
        OrderModel.deliveryDate.inputDate(
          label: '',
          validate: const [BeakRequired()],
          shortcuts: (_) {
            const clock = FoodioClock();
            BeakDate after(int days) =>
                BeakDate.fromDateTime(clock.local.add(Duration(days: days)));
            const dates = BeakFormatPolicy(
              locale: 'en_US',
              datePattern: 'EEE d MMM',
            );
            return [
              BeakInputOption(
                clock.today,
                'Today',
                enabled: !clock.changesClosed(clock.today),
              ),
              BeakInputOption(
                after(1),
                'Tomorrow · ${dates.calendarDate(after(1))}',
              ),
              BeakInputOption(after(2), dates.calendarDate(after(2))),
            ];
          },
        ),
        // --8<-- [end:deliveryDateInput]
      ],
    ),
    BeakFormLayout(
      spacingInPixels: 8,
      children: [
        // --8<-- [start:deliverySlotCards]
        OrderModel.slot.inputCards(
          selectDefaultOption: true,
          defaultOptionMatch: (option, state) {
            final start = state.read(OrderModel.profile.preferredDeliveryStart);
            final end = state.read(OrderModel.profile.preferredDeliveryEnd);
            return start != null &&
                end != null &&
                DeliverySlotModel.startMinute.readFrom(option) ==
                    start.hour * 60 + start.minute &&
                DeliverySlotModel.endMinute.readFrom(option) ==
                    end.hour * 60 + end.minute;
          },
          compact: true,
          minCardWidthInPixels: 115,
          template: BeakRecordTemplate(
            title: BeakValueBinding.field(DeliverySlotModel.name),
            progressHeightInPixels: 8,
            progressStriped: true,
            details: [
              BeakValueBinding<String>.computed(
                dependencies: [
                  DeliverySlotModel.capacity,
                  DeliverySlotModel.reservedOrders,
                  DeliverySlotModel.active,
                ],
                visibleIf: (row) => row.read(DeliverySlotModel.active) == true,
                tone: (row) => _slotNearCapacity(row)
                    ? BeakColor.warning
                    : BeakColor.muted,
                iconFor: (row) =>
                    _slotNearCapacity(row) ? OiIcons.triangleAlert : null,
                textStyle: const TextStyle(fontSize: 12, height: 4 / 3),
                compute: (row) =>
                    '${((row.read(DeliverySlotModel.capacity) ?? 0) - (row.read(DeliverySlotModel.reservedOrders) ?? 0)).clamp(0, 99999)} left',
              ),
            ],
            progress: BeakValueBinding<num>.computed(
              dependencies: [
                DeliverySlotModel.capacity,
                DeliverySlotModel.reservedOrders,
              ],
              compute: (row) {
                final capacity = row.read(DeliverySlotModel.capacity) ?? 0;
                return capacity == 0
                    ? 0
                    : (row.read(DeliverySlotModel.reservedOrders) ?? 0) /
                          capacity;
              },
            ),
          ),
          disabledReason: (row, _) =>
              DeliverySlotModel.active.readFrom(row) != true
              ? 'Not available'
              : (DeliverySlotModel.reservedOrders.readFrom(row) ?? 0) >=
                    (DeliverySlotModel.capacity.readFrom(row) ?? 0)
              ? 'This delivery slot is full'
              : null,
          label: 'Delivery slot',
          descriptionInline: true,
          descriptionBuilder: (state) =>
              'Capacity for ${const BeakFormatPolicy(locale: 'en_US', datePattern: 'EEE d MMM').calendarDate(state.asOrder.deliveryDate ?? const FoodioClock().today)} · selected profile route ${state.asOrder.profile?.location?.routeCode ?? '—'}',
          dependencies: [
            OrderModel.deliveryDate,
            OrderModel.profile.location.routeCode,
            OrderModel.profile.location.method,
            OrderModel.profile.preferredDeliveryStart,
            OrderModel.profile.preferredDeliveryEnd,
          ],
          validate: const [BeakRequired()],
          enabledIf: (state) => state.asOrder.deliveryDate != null,
          options: (state) => DeliverySlotModel.options(
            filter: BeakAndFilter([
              DeliverySlotModel.date.eq(
                state.asOrder.deliveryDate ?? const FoodioClock().today,
              ),
              DeliverySlotModel.method.eq(
                state.read(OrderModel.profile.location.method) ?? 'office',
              ),
            ]),
          ),
        ),
        // --8<-- [end:deliverySlotCards]
        const BeakCalculated(
          value: _slotReservationHint,
          valueStyle: TextStyle(fontSize: 12, height: 4 / 3),
        ),
      ],
    ),
    BeakSection(
      title: 'Location',
      gapInPixels: 12,
      dividerAfterSpacingInPixels: 14,
      trailing: BeakValueBinding<String>.computed(
        dependencies: [OrderModel.profile.organization.name],
        compute: (row) =>
            'Delivery locations of ${row.read(OrderModel.profile.organization.name) ?? 'this profile'}',
        color: BeakColor.muted,
        textStyle: const TextStyle(fontSize: 12, height: 4 / 3),
      ),
      titleStyle: const TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w600,
      ),
      divider: true,
      children: [
        OrderModel.location.inputCards(
          cardPadding: const EdgeInsets.all(17),
          defaultOption: OrderModel.profile.location,
          dependencies: [OrderModel.profile.location],
          template: BeakRecordTemplate(
            textGapInPixels: 2,
            title: BeakValueBinding.field(
              DeliveryLocationModel.name,
              strong: true,
            ),
            subtitle: [
              BeakValueBinding.field(
                DeliveryLocationModel.handover,
                maxLines: 2,
              ),
              BeakValueBinding<String>.computed(
                dependencies: [
                  DeliveryLocationModel.street,
                  DeliveryLocationModel.postalCode,
                  DeliveryLocationModel.city,
                ],
                compute: (row) =>
                    '${row.read(DeliveryLocationModel.street)}, ${row.read(DeliveryLocationModel.postalCode)} ${row.read(DeliveryLocationModel.city)}',
                maxLines: 2,
              ),
            ],
          ),
          options: (state) => DeliveryLocationModel.options(
            filter: BeakAndFilter([
              if (state.asOrder.profile?.organizationId
                  case final organization?)
                DeliveryLocationModel.organizationId.eq(organization)
              else
                DeliveryLocationModel.id.eq(
                  state.asOrder.profile?.locationId ?? '',
                ),
              DeliveryLocationModel.active.eq(true),
            ]),
          ),
          label: '',
          validate: const [BeakRequired()],
        ),
        BeakFormNotice(
          tone: BeakColor.muted,
          icon: OiIcons.truck,
          dependencies: [
            OrderModel.location.method,
            OrderModel.location.routeCode,
            OrderModel.location.handover,
          ],
          message: (state) =>
              'Handover and transport: ${state.read(OrderModel.location.method) == 'office' ? 'Office delivery' : 'Home delivery'} · ${_transport(state.read(OrderModel.location.routeCode))}',
          caption: (_) => 'Set by the location',
          captionIcon: OiIcons.lock,
        ),
        BeakFormLayout(
          spacingInPixels: 24,
          children: [
            BeakCard(
              presentation: BeakCardPresentation.plain,
              title: 'Deliver to a different address this once',
              description: 'Only for this order; the profile stays as it is.',
              collapsible: true,
              disclosurePadding: EdgeInsets.zero,
              initiallyExpanded: false,
              children: [
                OrderModel.addressOverride.inputToggle(
                  label: 'Use a one-time delivery address',
                ),
                BeakFormLayout(
                  visibleIf: (state) => state.asOrder.addressOverride == true,
                  children: [
                    BeakFormNotice(
                      plain: true,
                      tone: BeakColor.muted,
                      message: (_) =>
                          'The address must remain in this location’s city and postal area.',
                    ),
                    OrderModel.street.inputText(
                      label: 'Street and house number',
                      validate: const [BeakRequired()],
                    ),
                    BeakColumns(
                      children: [
                        OrderModel.postalCode.inputText(
                          label: 'Postal code',
                          validate: const [BeakRequired()],
                        ),
                        OrderModel.city.inputText(
                          label: 'City',
                          validate: const [BeakRequired()],
                        ),
                      ],
                    ),
                    OrderModel.handover.inputText(
                      label: 'Handover instructions',
                    ),
                  ],
                ),
              ],
            ),
            BeakSection(
              title: 'Delivery note (optional)',
              titleStyle: const TextStyle(
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
              gapInPixels: 6,
              children: [
                // --8<-- [start:deliveryNoteInput]
                OrderModel.deliveryNote.inputText(
                  label: '',
                  description: 'Printed on the delivery note for the driver.',
                  maxLines: 3,
                  controlHeightInPixels: 88,
                ),
                // --8<-- [end:deliveryNoteInput]
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
String _transport(String? route) =>
    (route ?? '').toLowerCase().startsWith('bike')
    ? 'Bike courier'
    : 'Cooled van · Route ${route ?? '—'}';

String _slotReservationHint(BeakFormReader _) =>
    'Unavailable slots cannot be selected. Capacity is reserved when the order is placed.';

bool _slotNearCapacity(BeakDraftReader row) {
  final capacity = row.read(DeliverySlotModel.capacity) ?? 0;
  return capacity > 0 &&
      (row.read(DeliverySlotModel.reservedOrders) ?? 0) / capacity >= .9;
}
