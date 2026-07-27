import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';

import '../panel/details/details.dart';

/// The orders resource, with the parts Beak cannot derive.
///
/// Its model, label, icon and section still come from the schema class and
/// `beak.yaml`; this adds what a person decided.
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  detail: orderLayout,
  formLayout: orderLayout,
  filters: [
    const BeakSelectFilter(column: OrderColumns.status, label: 'Status'),
    const BeakSelectFilter(column: OrderColumns.source, label: 'Source'),
  ],
  viewModes: [
    const BeakTableView(),
    const BeakKanbanView(
      groupField: OrderColumns.status,
      titleField: OrderColumns.reference,
      subtitleField: OrderColumns.total,
      sortField: OrderColumns.placedAt,
      sortDescending: true,
    ),
  ],
);
