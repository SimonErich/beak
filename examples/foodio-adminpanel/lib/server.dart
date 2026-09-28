import 'package:beak/server.dart';

import 'domain/foodio_effects.dart';
import 'domain/foodio_order_preparer.dart';

/// Generated registration plus the example's transaction and provider rules.
BeakServer beakServer(BeakServerDefaults defaults) => defaults.build(
  preparePlan: FoodioOrderPreparer(defaults.registry).prepare,
  finalizePlan: const FoodioEffects().finalize,
  graphOnlyTables: const {
    'app_settings',
    'orders',
    'order_items',
    'order_item_options',
    'order_notes',
    'order_activities',
    'budget_accounts',
    'delivery_profiles',
    'delivery_slots',
    'payment_attempts',
    'message_deliveries',
  },
);
