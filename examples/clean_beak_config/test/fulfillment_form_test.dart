import 'package:beak/panel.dart';
import 'package:beak/testing.dart';
import 'package:clean_beak_config/beak/registry.g.dart';
import 'package:clean_beak_config/resources/fulfillment/models/fulfillment_policy.dart';
import 'package:clean_beak_config/resources/fulfillment/screens/fulfillment_policy_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a policy with ordinary defaults saves without optional fields or tags',
    () async {
      final registry = buildBeakRegistry();
      final source = InMemoryBeakDataSource(registry: registry);
      final session = BeakFormSession(
        model: const FulfillmentPolicyModel(),
        dataSource: source,
        registry: registry,
        layout: fulfillmentPolicyForm(),
      );
      addTearDown(session.dispose);
      session.root.set(FulfillmentPolicyModel.name, 'Austria standard');
      session.root.set(FulfillmentPolicyModel.code, 'austria-standard');
      expect(
        await session.validate(),
        isTrue,
        reason: '${session.root.errors}',
      );
      final result = await session.save();
      expect(
        result?.complete,
        isTrue,
        reason:
            '${session.root.errors}; error=${session.error.value}; result=${result?.toJson()}',
      );
      final saved = source.rowsOf('fulfillment_policies').single;
      expect(
        FulfillmentPolicyModel.deliveryFee.readFrom(saved),
        const BeakDecimal(490, scale: 2),
      );
      expect(FulfillmentPolicyModel.tags.readFrom(saved), <String>[]);
      expect(FulfillmentPolicyModel.signatureRequired.readFrom(saved), isNull);
      expect(FulfillmentPolicyModel.origin.readFrom(saved), isNull);
    },
  );
}
