import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';

import '../../../models/models.dart';

/// Immutable activity history is loaded automatically through its relationship.
BeakCard orderActivityCard() => BeakCard(
  title: 'Activity',
  headerTrailing: BeakValueBinding<String>.computed(
    dependencies: const [],
    compute: (_) => 'Today · newest first',
  ),
  children: [
    BeakFormTimeline(
      field: OrderModel.activities,
      compact: true,
      inlineTime: true,
      actor: BeakValueBinding<String>.computed(
        dependencies: [OrderActivityModel.actor],
        compute: (row) => row.read(OrderActivityModel.actor) == 'Automatic'
            ? null
            : row.read(OrderActivityModel.actor),
      ),
      columns: 2,
      title: OrderActivityModel.title,
      time: OrderActivityModel.occurredAt,
      description: OrderActivityModel.description,
    ),
  ],
);

/// Order identity icon used by the shared read/edit header.
IconData orderIcon(BeakDraftReader _) => OiIcons.shoppingBag;
