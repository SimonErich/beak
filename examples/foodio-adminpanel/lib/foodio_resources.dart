import 'package:beak/panel.dart';

import 'resources/catalog/dish_resource.dart';
import 'resources/finance/finance_resources.dart';
import 'resources/operations/operations_resources.dart';
import 'resources/orders/order_resource.dart';
import 'resources/people/people_resources.dart';

/// Typed declarative resources, separated by the team's operational areas.
List<BeakResource> foodioResources() {
  const groups = {
    'Orders': 0,
    'People': 1,
    'Kitchen': 2,
    'Finance': 3,
    'Settings': 4,
  };
  return [
    OrderResource(),
    dishResource(),
    ...peopleResources(),
    ...financeResources(),
    ...operationsResources(),
  ]..sort((a, b) {
    final group = (groups[a.navigationGroup] ?? 5).compareTo(
      groups[b.navigationGroup] ?? 5,
    );
    return group != 0 ? group : a.navigationRank.compareTo(b.navigationRank);
  });
}
