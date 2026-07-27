import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';

import '../panel/details/details.dart';

/// The cards resource, with the parts Beak cannot derive.
///
/// Its model, label, icon and section still come from the schema class and
/// `beak.yaml`; this adds what a person decided.
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  detail: cardDetail,
  formLayout: cardDetail,
  filters: [
    const BeakSelectFilter(column: CardColumns.priority, label: 'Priority'),
  ],
  viewModes: [
    const BeakTableView(),
    const BeakKanbanView(
      groupField: CardColumns.priority,
      titleField: CardColumns.title,
      sortField: CardColumns.sortIndex,
    ),
  ],
);
