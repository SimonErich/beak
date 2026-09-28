import 'package:beak/server.dart';

import 'domain/foodio_effects.dart';
import 'domain/foodio_order_preparer.dart';
import 'models/models.dart';

/// Generated registration plus the example's transaction and provider rules.
///
/// The host drains the persistent demo providers while it serves, so the
/// generated `bin/serve.dart` needs nothing of its own.
BeakServer beakServer(BeakServerDefaults defaults) => defaults.build(
  preparePlan: FoodioOrderPreparer(defaults.registry).prepare,
  finalizePlan: const FoodioEffects().finalize,
  outbox: const FoodioEffects().schedule(defaults.dataSource.adapter),
  graphOnly: const [
    AppSettingModel(),
    OrderModel(),
    OrderItemModel(),
    OrderItemOptionModel(),
    OrderNoteModel(),
    OrderActivityModel(),
    BudgetAccountModel(),
    DeliveryProfileModel(),
    DeliverySlotModel(),
    PaymentAttemptModel(),
    MessageDeliveryModel(),
  ],
);
