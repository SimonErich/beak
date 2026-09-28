import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import '../../models/models.dart';
import '../../supporting_forms.dart';

/// Scheduling, kitchen planning, customer care and persistent app metadata.
List<BeakResource> operationsResources() => [
  BeakResource(
    model: const DeliverySlotModel(),
    title: 'Delivery schedule',
    navigationGroup: 'Orders',
    navigationRank: 1,
    icon: const BeakIconToken(OiIcons.truck),
    globalSearchSources: [DeliverySlotModel.name, DeliverySlotModel.routeCode],
    screens: [
      BeakTableScreen(
        fields: [
          DeliverySlotModel.date,
          DeliverySlotModel.name,
          DeliverySlotModel.routeCode,
          DeliverySlotModel.capacity,
          DeliverySlotModel.reservedOrders,
          DeliverySlotModel.active,
        ],
      ),
      supportingForm([
        BeakColumns(
          children: [
            BeakCard(
              title: 'Delivery window',
              children: [
                DeliverySlotModel.name.inputText(),
                DeliverySlotModel.date.inputDate(),
                DeliverySlotModel.startMinute.inputSelect(
                  label: 'From',
                  options: (_) => _times(),
                ),
                DeliverySlotModel.endMinute.inputSelect(
                  label: 'Until',
                  options: (_) => _times(),
                ),
                DeliverySlotModel.routeCode.inputText(),
                DeliverySlotModel.method.inputSelect(
                  options: (_) => choices({
                    'office': 'Office route',
                    'home': 'Home delivery',
                    'pickup': 'Kitchen pickup',
                  }),
                ),
              ],
            ),
            BeakCard(
              title: 'Capacity',
              description:
                  'Capacity is counted in orders, including pending payments and approvals.',
              children: [
                DeliverySlotModel.capacity.inputNumber(label: 'Maximum orders'),
                DeliverySlotModel.reservedOrders.inputNumber(
                  label: 'Reserved orders',
                  readOnly: true,
                ),
                DeliverySlotModel.active.inputToggle(),
              ],
            ),
          ],
        ),
      ]),
    ],
  ),
  BeakResource(
    model: const ComplaintModel(),
    title: 'Complaints',
    navigationGroup: 'Orders',
    navigationRank: 3,
    icon: const BeakIconToken(OiIcons.messageSquare),
    globalSearchSources: [
      ComplaintModel.reference,
      ComplaintModel.subject,
      ComplaintModel.order.reference,
    ],
    screens: [
      BeakTableScreen(
        fields: [
          ComplaintModel.reference,
          ComplaintModel.subject,
          ComplaintModel.order.reference,
          ComplaintModel.status,
          ComplaintModel.assignee,
        ],
      ),
      supportingForm([
        BeakColumns(
          children: [
            BeakCard(
              title: 'Customer concern',
              children: [
                ComplaintModel.reference.inputText(),
                ComplaintModel.order.inputCombobox(),
                ComplaintModel.subject.inputText(),
                ComplaintModel.description.inputText(),
              ],
            ),
            BeakCard(
              title: 'Resolution',
              children: [
                ComplaintModel.status.inputSelect(
                  options: (_) => choices({
                    'open': 'Open',
                    'inProgress': 'In progress',
                    'resolved': 'Resolved',
                    'closed': 'Closed',
                  }),
                ),
                ComplaintModel.assignee.inputText(),
              ],
            ),
          ],
        ),
      ]),
    ],
  ),
  BeakResource(
    model: const MenuPlanModel(),
    title: 'Menu plans',
    navigationRank: 1,
    navigationGroup: 'Kitchen',
    icon: const BeakIconToken(OiIcons.calendarDays),
    globalSearchSources: [MenuPlanModel.name, MenuPlanModel.description],
    screens: [
      BeakTableScreen(
        fields: [
          MenuPlanModel.name,
          MenuPlanModel.description,
          MenuPlanModel.active,
        ],
      ),
      supportingForm([
        BeakCard(
          title: 'Menu plan',
          children: [
            MenuPlanModel.name.inputText(),
            MenuPlanModel.description.inputText(),
            MenuPlanModel.active.inputToggle(),
          ],
        ),
        BeakCard(
          title: 'Daily selections',
          children: [
            MenuPlanModel.items.tableForm(
              removeBehavior: BeakRemoveBehavior.deleteOwned,
              children: [
                MenuPlanItemModel.date.inputDate(),
                MenuPlanItemModel.dish.inputCombobox(),
                MenuPlanItemModel.position.inputNumber(label: 'Sort order'),
              ],
            ),
          ],
        ),
      ]),
    ],
  ),
  BeakResource(
    model: const AppSettingModel(),
    title: 'Settings',
    navigationRank: 1,
    navigationGroup: 'Settings',
    icon: const BeakIconToken(OiIcons.settings),
    canCreate: false,
    canDelete: false,
    screens: [
      BeakTableScreen(
        query: const AppSettingModel().query(
          filter: AppSettingModel.key.eq('brand'),
        ),
        fields: [
          AppSettingModel.key,
          AppSettingModel.value,
          AppSettingModel.description,
        ],
      ),
      supportingForm([
        BeakCard(
          title: 'Application metadata',
          children: [
            AppSettingModel.key.input(readOnly: true),
            AppSettingModel.value.inputText(),
            AppSettingModel.description.inputText(),
          ],
        ),
      ]),
    ],
  ),
  BeakResource(
    model: const NotificationModel(),
    title: 'Notifications',
    navigationRank: 2,
    navigationGroup: 'Settings',
    icon: const BeakIconToken(OiIcons.bell),
    canCreate: false,
    canDelete: false,
    screens: [
      BeakTableScreen(
        fields: [
          NotificationModel.title,
          NotificationModel.recipient,
          NotificationModel.occurredAt,
          NotificationModel.isRead,
        ],
      ),
      supportingForm([
        BeakCard(
          title: 'Notification',
          children: [
            NotificationModel.title.input(readOnly: true),
            NotificationModel.body.input(readOnly: true),
            NotificationModel.recipient.input(readOnly: true),
            NotificationModel.occurredAt.input(readOnly: true),
            NotificationModel.isRead.inputToggle(label: 'Read'),
          ],
        ),
      ]),
    ],
  ),
];

List<BeakInputOption<Object>> _times() => [
  for (var minute = 0; minute <= 24 * 60; minute += 15)
    BeakInputOption(
      minute,
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}',
    ),
];
