import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import '../models/order.dart';

/// The orders resource: a wizard instead of one long form.
///
/// A create form with nine inputs is a wall; four explained steps is a
/// conversation. Each step validates before the next unlocks, and every form
/// column appears in exactly one of them.
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  formSteps: const [
    BeakFormStep(
      title: 'Customer',
      subtitle: 'Who is buying',
      icon: OiIcons.user,
      description:
          'Pick the customer this order belongs to. Their past orders appear '
          'on their own page once this one is saved.',
      columns: [OrderColumns.customerId],
    ),
    BeakFormStep(
      title: 'Order',
      subtitle: 'Reference & status',
      icon: OiIcons.receipt,
      description:
          'The reference is what the customer quotes when they write in, so '
          'it has to be unique. Status drives the badge on the list.',
      columns: [OrderColumns.reference, OrderColumns.status],
    ),
    BeakFormStep(
      title: 'Money',
      subtitle: 'Total & date',
      icon: OiIcons.creditCard,
      description:
          'The total is the amount actually charged, including shipping — '
          'the lines below it are what was bought.',
      columns: [OrderColumns.total, OrderColumns.placedAt],
    ),
    BeakFormStep(
      title: 'Delivery',
      subtitle: 'Anything the courier needs',
      icon: OiIcons.truck,
      description: 'Optional. Gate codes, delivery windows, doorbell names.',
      columns: [OrderColumns.notes],
    ),
  ],
);
