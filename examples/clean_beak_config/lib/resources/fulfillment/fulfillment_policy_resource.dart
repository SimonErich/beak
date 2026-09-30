import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'models/fulfillment_policy.dart';
import 'screens/fulfillment_policy_form.dart';

/// Fulfillment configuration demonstrating semantic fields in a shop workflow.
final class FulfillmentPolicyResource extends BeakResource {
  /// Registers navigation, search, filters and reusable read/create/edit layout.
  FulfillmentPolicyResource()
    : super(
        model: const FulfillmentPolicyModel(),
        title: 'Fulfillment policies',
        icon: const BeakIconToken(OiIcons.truck),
        navigationGroup: 'Settings',
        navigationRank: 11,
        globalSearchSources: [
          FulfillmentPolicyModel.name,
          FulfillmentPolicyModel.code,
          FulfillmentPolicyModel.supportEmail,
        ],
        filters: [
          FulfillmentPolicyModel.speed.selectFilter(),
          FulfillmentPolicyModel.signatureRequired.boolFilter(),
        ],
        screens: [
          BeakTableScreen(
            fields: [
              FulfillmentPolicyModel.name,
              FulfillmentPolicyModel.code,
              FulfillmentPolicyModel.deliveryFee,
              FulfillmentPolicyModel.speed,
              FulfillmentPolicyModel.dispatchCutoff,
              FulfillmentPolicyModel.handlingTime,
            ],
          ),
          BeakFormScreen(
            roles: const {
              BeakScreenRole.read,
              BeakScreenRole.create,
              BeakScreenRole.edit,
            },
            layout: fulfillmentPolicyForm(),
          ),
        ],
      );
}
