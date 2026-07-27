import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';

import '../panel/details/details.dart';

/// The products resource, with the parts Beak cannot derive.
///
/// Its model, label, icon and section still come from the schema class and
/// `beak.yaml`; this adds what a person decided.
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  detail: productLayout,
  formLayout: productLayout,
  filters: [
    const BeakSelectFilter(column: ProductColumns.status, label: 'Status'),
    const BeakTextFilter(column: ProductColumns.name, label: 'Name'),
  ],
);
