import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';

import '../panel/details/details.dart';

/// The users resource, with the parts Beak cannot derive.
///
/// Its model, label, icon and section still come from the schema class and
/// `beak.yaml`; this adds what a person decided.
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  detail: userDetail,
  formLayout: userDetail,
  filters: [
    const BeakSelectFilter(column: UserColumns.role, label: 'Role'),
    const BeakSelectFilter(column: UserColumns.status, label: 'Status'),
  ],
);
