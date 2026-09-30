import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import '../../models/models.dart';
import '../../supporting_forms.dart';
import 'people_forms.dart';

/// Contacts, company agreements and the delivery profiles used by ordering.
List<BeakResource> peopleResources() => [
  BeakResource(
    model: const CustomerModel(),
    title: 'Customers',
    navigationGroup: 'People',
    icon: const BeakIconToken(OiIcons.users),
    globalSearchSources: [
      CustomerModel.name,
      CustomerModel.email,
      CustomerModel.phone,
    ],
    filters: [CustomerModel.email.textFilter()],
    screens: [
      BeakTableScreen(
        fields: [
          CustomerModel.name,
          CustomerModel.email,
          CustomerModel.phone,
          CustomerModel.active,
        ],
      ),
      supportingForm(customerForm().children),
    ],
  ),
  BeakResource(
    model: const OrganizationModel(),
    title: 'Organizations',
    navigationRank: 1,
    navigationGroup: 'People',
    icon: const BeakIconToken(OiIcons.building2),
    globalSearchSources: [
      OrganizationModel.name,
      OrganizationModel.legalName,
      OrganizationModel.billingEmail,
    ],
    screens: [
      BeakTableScreen(
        fields: [
          OrganizationModel.name,
          OrganizationModel.billingEmail,
          OrganizationModel.defaultBudgetCents.currency(
            minorUnits: true,
            label: 'Default budget',
          ),
          OrganizationModel.active,
        ],
      ),
      supportingForm([
        BeakTabs(
          tabs: [
            BeakTab(
              title: 'Company & billing',
              children: [
                BeakColumns(
                  children: [
                    BeakCard(
                      title: 'Company',
                      children: [
                        OrganizationModel.name.inputText(),
                        OrganizationModel.legalName.inputText(),
                        OrganizationModel.active.inputToggle(),
                      ],
                    ),
                    BeakCard(
                      title: 'Billing',
                      children: [
                        OrganizationModel.billingEmail.inputText(),
                        OrganizationModel.billingAddress.inputText(),
                        OrganizationModel.invoiceFrequency.inputSelect(
                          options: (_) => choices({
                            'monthly': 'Monthly',
                            'weekly': 'Weekly',
                            'perOrder': 'Per order',
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            BeakTab(
              title: 'Budget & approval',
              children: [
                BeakColumns(
                  children: [
                    BeakCard(
                      title: 'Spending policy',
                      children: [
                        OrganizationModel.defaultBudgetCents.inputCurrency(
                          minorUnits: true,
                          label: 'Default monthly budget',
                        ),
                        OrganizationModel.approvalThresholdCents.inputCurrency(
                          minorUnits: true,
                          label: 'Approval required above',
                        ),
                        OrganizationModel.approver.inputCombobox(),
                      ],
                    ),
                    BeakCard(
                      title: 'Cost centers',
                      children: [
                        OrganizationModel.costCenters.inputText(
                          description:
                              'Separate allowed cost centers with commas.',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ]),
    ],
  ),
  BeakResource(
    model: const DeliveryProfileModel(),
    title: 'Delivery profiles',
    navigationRank: 2,
    navigationGroup: 'People',
    icon: const BeakIconToken(OiIcons.contact),
    globalSearchSources: [
      DeliveryProfileModel.name,
      DeliveryProfileModel.customer.email,
      DeliveryProfileModel.organization.name,
    ],
    screens: [
      BeakTableScreen(
        fields: [
          DeliveryProfileModel.name,
          DeliveryProfileModel.customer.name,
          DeliveryProfileModel.organization.name,
          DeliveryProfileModel.costCenter,
          DeliveryProfileModel.active,
        ],
      ),
      supportingForm(deliveryProfileForm().children),
    ],
  ),
  BeakResource(
    model: const StaffMemberModel(),
    title: 'Team',
    navigationRank: 3,
    navigationGroup: 'People',
    icon: const BeakIconToken(OiIcons.userRound),
    globalSearchSources: [StaffMemberModel.name, StaffMemberModel.email],
    screens: [
      BeakTableScreen(
        fields: [
          StaffMemberModel.name,
          StaffMemberModel.email,
          StaffMemberModel.role,
          StaffMemberModel.active,
        ],
      ),
      supportingForm([
        BeakCard(
          title: 'Team member',
          children: [
            StaffMemberModel.name.inputText(),
            StaffMemberModel.email.inputText(),
            StaffMemberModel.role.inputSelect(
              options: (_) => choices({
                'administrator': 'Administrator',
                'operations': 'Operations',
                'kitchen': 'Kitchen',
                'driver': 'Driver',
                'approver': 'Approver',
              }),
            ),
            StaffMemberModel.active.inputToggle(),
          ],
        ),
      ]),
    ],
  ),
  BeakResource(
    model: const DeliveryLocationModel(),
    title: 'Locations',
    navigationGroup: 'Settings',
    icon: const BeakIconToken(OiIcons.mapPin),
    globalSearchSources: [
      DeliveryLocationModel.name,
      DeliveryLocationModel.street,
      DeliveryLocationModel.organization.name,
    ],
    screens: [
      BeakTableScreen(
        fields: [
          DeliveryLocationModel.name,
          DeliveryLocationModel.organization.name,
          DeliveryLocationModel.street,
          DeliveryLocationModel.city,
          DeliveryLocationModel.active,
        ],
      ),
      supportingForm([
        BeakColumns(
          children: [
            BeakCard(
              title: 'Delivery address',
              children: [
                DeliveryLocationModel.name.inputText(),
                DeliveryLocationModel.organization.inputCombobox(),
                DeliveryLocationModel.street.inputText(),
                DeliveryLocationModel.postalCode.inputText(),
                DeliveryLocationModel.city.inputText(),
                DeliveryLocationModel.active.inputToggle(),
              ],
            ),
            BeakCard(
              title: 'Handover & routing',
              children: [
                DeliveryLocationModel.method.inputSelect(
                  options: (_) => choices({
                    'office': 'Office delivery',
                    'home': 'Home delivery',
                    'pickup': 'Kitchen pickup',
                  }),
                ),
                DeliveryLocationModel.routeCode.inputText(),
                DeliveryLocationModel.handover.inputText(),
                DeliveryLocationModel.instructions.inputText(),
              ],
            ),
          ],
        ),
      ]),
    ],
  ),
];
