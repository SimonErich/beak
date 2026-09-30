import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import '../models/models.dart';
import '../resources/orders/dashboard/order_overview.dart';

/// The home destination: the day at a glance and the orders needing attention.
final BeakScreen overviewScreen = BeakScreen(
  path: '/overview',
  title: 'Good morning, Marie',
  navigationGroup: 'Home',
  icon: const BeakIconToken(OiIcons.layoutDashboard),
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [
      const BeakTextBlock(
        'Monday, 28 September 2026 · Here is what is happening at Gabel today.',
      ),
      orderOverview(),
      BeakCardBlock(
        title: 'Orders that need attention',
        child: BeakTableBlock(
          model: const OrderModel(),
          fields: [
            OrderModel.reference,
            OrderModel.customerName,
            OrderModel.attentionReason,
            OrderModel.nextAction,
          ],
          baseFilter: OrderModel.needsAttention.eq(true),
          enableDelete: false,
        ),
      ),
    ],
  ),
);

/// Portions of each dish across today's orders.
final _portions = BeakSummaryMeasure.sum(
  'portions',
  field: OrderItemModel.quantity,
);

/// Today's preparation list, derived from the same orders.
final BeakScreen kitchenScreen = BeakScreen(
  path: '/kitchen',
  title: 'Kitchen summary',
  navigationGroup: 'Orders',
  icon: const BeakIconToken(OiIcons.clipboardList),
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [
      const BeakTextBlock('Today’s preparation list · Changes close at 10:30'),
      BeakSummaryBlock(
        title: 'Portions by dish',
        presentation: BeakSummaryPresentation.table,
        scope: BeakSummaryScope.standalone,
        query: const OrderItemModel().summary(
          groupBy: OrderItemModel.label,
          filter: BeakAndFilter([
            OrderItemModel.order.deliveryDate.eq(const BeakDate(2026, 9, 28)),
            OrderItemModel.order.status.notEq(OrderStatus.cancelled),
          ]),
          measures: [_portions],
        ),
        values: [BeakSummaryValue(measure: _portions, label: 'Portions')],
      ),
      BeakCardBlock(
        title: 'Kitchen notes and allergies',
        child: BeakTableBlock(
          model: const OrderModel(),
          fields: [
            OrderModel.reference,
            OrderModel.customerName,
            OrderModel.allergenNote,
            OrderModel.customerNote,
            OrderModel.allergyAcknowledged,
          ],
          baseFilter: BeakAndFilter([
            OrderModel.deliveryDate.eq(const BeakDate(2026, 9, 28)),
            OrderModel.strictAllergy.eq(true),
          ]),
          enableDelete: false,
        ),
      ),
    ],
  ),
);

/// Supporting destinations use the same declarative query and display blocks.
List<BeakScreen> foodioPages() => [overviewScreen, kitchenScreen];
