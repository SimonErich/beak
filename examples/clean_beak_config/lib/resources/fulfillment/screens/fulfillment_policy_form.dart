import 'package:beak/panel.dart';
import '../models/fulfillment_policy.dart';

/// Reusable structured policy form; all data and validation come from the model.
BeakFormLayout fulfillmentPolicyForm() => BeakFormLayout(
  children: [
    BeakTabs(
      tabs: [
        BeakTab(
          title: 'Service',
          children: [
            BeakColumns(
              children: [
                BeakCard(
                  title: 'Policy identity',
                  children: [
                    FulfillmentPolicyModel.name.input(),
                    FulfillmentPolicyModel.code.input(
                      description:
                          'A unique lowercase code, such as standard-europe.',
                    ),
                    FulfillmentPolicyModel.speed.inputRadio(),
                    FulfillmentPolicyModel.tags.inputTags(
                      label: 'Operational tags',
                    ),
                  ],
                ),
                BeakCard(
                  title: 'Carrier contact',
                  children: [
                    FulfillmentPolicyModel.supportEmail.input(),
                    FulfillmentPolicyModel.supportPhone.input(),
                    FulfillmentPolicyModel.trackingUrl.input(),
                  ],
                ),
              ],
            ),
            BeakCard(
              title: 'Destination coverage',
              children: [
                FulfillmentPolicyModel.regions.inputCheckboxGroup(
                  options: (_) => const [
                    BeakInputOption('AT', 'Austria'),
                    BeakInputOption('DE', 'Germany'),
                    BeakInputOption('CH', 'Switzerland'),
                    BeakInputOption('IT', 'Italy'),
                    BeakInputOption('FR', 'France'),
                    BeakInputOption('GB', 'United Kingdom'),
                  ],
                ),
                FulfillmentPolicyModel.signatureRequired.input(
                  description: 'Leave unset to use the carrier default.',
                ),
              ],
            ),
          ],
        ),
        BeakTab(
          title: 'Pricing and timing',
          children: [
            BeakColumns(
              children: [
                BeakCard(
                  title: 'Delivery charges',
                  description:
                      'Set the delivery and insurance charges for this service.',
                  children: [
                    FulfillmentPolicyModel.currency.inputSelect(
                      options: (_) => const [
                        BeakInputOption('EUR', 'EUR · Euro'),
                        BeakInputOption('USD', 'USD · US dollar'),
                        BeakInputOption('GBP', 'GBP · Pound sterling'),
                      ],
                    ),
                    FulfillmentPolicyModel.deliveryFee.input(),
                    FulfillmentPolicyModel.insuranceRate.input(
                      label: 'Insurance markup',
                    ),
                    FulfillmentPolicyModel.maximumWeight.input(),
                  ],
                ),
                BeakCard(
                  title: 'Dispatch schedule',
                  children: [
                    FulfillmentPolicyModel.effectiveDate.input(),
                    FulfillmentPolicyModel.dispatchCutoff.input(
                      description: 'Warehouse local time.',
                    ),
                    FulfillmentPolicyModel.handlingTime.input(),
                  ],
                ),
              ],
            ),
            BeakSection(
              title: 'Promotional validity',
              description: 'Use a start and end date for time-limited offers.',
              children: [
                BeakColumns(
                  children: [
                    FulfillmentPolicyModel.promotionStartsAt.input(),
                    FulfillmentPolicyModel.promotionEndsAt.input(),
                  ],
                ),
              ],
            ),
          ],
        ),
        BeakTab(
          title: 'Origin and integration',
          children: [
            BeakColumns(
              children: [
                BeakCard(
                  title: 'Dispatch address',
                  description: 'The warehouse used for this service.',
                  children: [
                    FulfillmentPolicyModel.origin.input(
                      label: 'Warehouse address',
                    ),
                  ],
                ),
                BeakCard(
                  title: 'Carrier integration',
                  children: [
                    FulfillmentPolicyModel.attachmentLimit.input(),
                    FulfillmentPolicyModel.providerOptions.input(
                      description:
                          'Optional settings supplied by your carrier.',
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
