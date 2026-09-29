import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import '../../../../models/models.dart';
import '../../../people/people_forms.dart';
import '../../presentations/order_presentations.dart';
import '../order_wizard_bindings.dart';

/// Customer and delivery-profile selection step.
BeakWizardStep customerAndProfileStep() => BeakWizardStep(
  title: 'Customer & profile',
  heading: 'Who is this order for?',
  introduction:
      'Search a customer, then choose the profile to order with. The profile decides who pays and where the food goes.',
  spacingInPixels: 24,
  continueLabel: 'Continue to delivery',
  description: 'Search, then choose a profile',
  completedDescription: (state, _) => [
    state.asOrder.customer?.name,
    state.asOrder.profile?.name,
  ].whereType<String>().join(' · '),
  footerHint: 'Delivery and payment are filled in from this profile.',
  children: [
    OrderModel.customer.inputSearch(
      template: customerIdentity(),
      exclusive: false,
      createLabel: 'Create a new customer',
      createIcon: OiIcons.userRoundPlus,
      createDescription: 'Not in the list? Add them first, then come back.',
      createForm: customerForm(),
      searchSources: [
        CustomerModel.name,
        CustomerModel.email,
        CustomerModel.phone,
        CustomerModel.profiles.search(DeliveryProfileModel.organization.name),
      ],
      label: 'Customer',
      description: 'Search by name, email, phone number or company.',
      validate: const [BeakRequired()],
    ),
    OrderModel.profile.inputCards(
      template: profileIdentity(),
      exclusive: false,
      createLabel: 'Add a profile',
      createLabelBuilder: (state) =>
          'Add a profile for ${customerFirstName(state)}',
      createForm: deliveryProfileForm(),
      label: 'Profile',
      description:
          'The default is selected. Delivery and payment follow this profile.',
      descriptionBuilder: (state) {
        final count = state.read(OrderModel.customer.profiles)?.length ?? 0;
        return '${customerFirstName(state)} has $count ${count == 1 ? 'profile' : 'profiles'}. The default is selected.';
      },
      dependencies: [OrderModel.customer.name, OrderModel.customer.profiles],
      divider: true,
      validate: const [BeakRequired()],
      options: (state) => DeliveryProfileModel.options(
        filter: DeliveryProfileModel.customerId.eq(
          state.asOrder.customerId ?? '',
        ),
      ),
    ),
  ],
);
