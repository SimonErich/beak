import 'package:beak/panel.dart';

import '../../models/models.dart';
import '../../supporting_forms.dart';
import '../../domain/foodio_payment.dart';

/// Contact details and dietary preferences shared by resources and inline creation.
BeakFormLayout customerForm() => BeakFormLayout(
  children: [
    BeakColumns(
      children: [
        BeakCard(
          title: 'Contact details',
          children: [
            CustomerModel.firstName.inputText(),
            CustomerModel.lastName.inputText(),
            CustomerModel.email.inputText(),
            CustomerModel.phone.inputText(),
            CustomerModel.active.inputToggle(),
          ],
        ),
        BeakCard(
          title: 'Preferences & dietary needs',
          children: [
            CustomerModel.allergens.inputText(
              description:
                  'Describe allergies so the kitchen can review each order.',
            ),
            CustomerModel.preferences.inputText(),
            CustomerModel.joinedAt.input(
              readOnly: true,
              label: 'Customer since',
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Delivery and billing preferences shared by the profile resource and order wizard.
BeakFormLayout deliveryProfileForm() => BeakFormLayout(
  children: [
    BeakTabs(
      tabs: [
        BeakTab(
          title: 'Profile',
          children: [
            BeakColumns(
              children: [
                BeakCard(
                  title: 'Customer & company',
                  children: [
                    DeliveryProfileModel.name.inputText(),
                    DeliveryProfileModel.customer.inputCombobox(),
                    DeliveryProfileModel.kind.inputSelect(
                      options: (_) =>
                          choices({'company': 'Company', 'private': 'Private'}),
                    ),
                    DeliveryProfileModel.organization.inputCombobox(),
                    DeliveryProfileModel.role.inputText(),
                    DeliveryProfileModel.isDefault.inputToggle(),
                    DeliveryProfileModel.active.inputToggle(),
                  ],
                ),
                BeakCard(
                  title: 'Delivery preferences',
                  children: [
                    DeliveryProfileModel.location.inputCombobox(),
                    DeliveryProfileModel.menuPlan.inputCombobox(),
                    DeliveryProfileModel.costCenter.inputText(),
                  ],
                ),
              ],
            ),
          ],
        ),
        BeakTab(
          title: 'Payment & budget',
          children: [
            BeakColumns(
              children: [
                BeakCard(
                  title: 'Billing preferences',
                  children: [
                    DeliveryProfileModel.paymentMode.inputSelect(
                      options: (_) => choices(foodioPaymentLabels),
                    ),
                    DeliveryProfileModel.monthlyBudgetCents.inputCurrency(
                      minorUnits: true,
                      label: 'Monthly budget',
                    ),
                    DeliveryProfileModel.approvalThresholdCents.inputCurrency(
                      minorUnits: true,
                      label: 'Approval required above',
                    ),
                    DeliveryProfileModel.approver.inputCombobox(),
                  ],
                ),
                BeakCard(
                  title: 'Monthly ledgers',
                  children: [
                    DeliveryProfileModel.budgets.tableForm(
                      allowAdding: false,
                      allowEdit: false,
                      allowRemove: false,
                      children: [
                        BudgetAccountModel.period.input(readOnly: true),
                        BudgetAccountModel.allowanceCents.inputCurrency(
                          minorUnits: true,
                          readOnly: true,
                          label: 'Allowance',
                        ),
                        BudgetAccountModel.reservedCents.inputCurrency(
                          minorUnits: true,
                          readOnly: true,
                          label: 'Reserved',
                        ),
                        BudgetAccountModel.spentCents.inputCurrency(
                          minorUnits: true,
                          readOnly: true,
                          label: 'Spent',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

/// A local demo payment instrument; the customer is inherited by inline forms.
BeakFormLayout paymentMethodForm() => BeakFormLayout(
  children: [
    PaymentMethodModel.name.inputText(label: 'Display name'),
    PaymentMethodModel.kind.inputSelect(
      options: (_) => choices({'card': 'Card', 'paypal': 'PayPal'}),
    ),
    PaymentMethodModel.lastFour.inputText(
      label: 'Last four digits',
      validate: const [BeakPattern(r'^\d{4}$')],
    ),
    PaymentMethodModel.demoOutcome.inputSelect(
      label: 'Demo payment result',
      options: (_) =>
          choices({'succeeded': 'Successful', 'failed': 'Declined'}),
    ),
    PaymentMethodModel.isDefault.inputToggle(label: 'Default payment method'),
  ],
);
