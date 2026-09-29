import 'package:beak/panel.dart';
import '../../../domain/order_behavior.dart';
import 'order_summary_layout.dart';
import 'order_review_step.dart';
import 'steps/order_customer_step.dart';
import 'steps/order_delivery_step.dart';
import 'steps/order_dishes_step.dart';
import 'steps/order_payment_step.dart';

export 'order_items_table.dart';
export 'order_summary_layout.dart';

/// Five stages over one draft; the final action saves the complete order graph.
BeakWizardScreen orderWizard() => BeakWizardScreen(
  roles: const {BeakScreenRole.create},
  fullScreen: true,
  navigation: BeakWizardNavigation.rail,
  navigationDescription:
      "Places an order on a customer's behalf, for example during a phone call.",
  header: const BeakFormHeader(title: 'New order'),
  submitAction: OrderActions.place,
  submitLabel: 'Place order',
  drafts: const BeakFormDrafts(
    store: BeakBrowserDraftStore(),
    key: 'foodio-order',
    context: 'foodio-demo:marie-novak',
    schemaVersion: 1,
  ),
  aside: BeakFormLayout(children: [orderSummary(), orderReviewAside()]),
  asideFooter: orderSummaryFooter(),
  steps: [
    customerAndProfileStep(),
    deliveryStep(),
    dishesStep(),
    paymentAndVouchersStep(),
    orderReviewStep(),
  ],
);
