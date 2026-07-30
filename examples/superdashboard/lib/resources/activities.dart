import 'package:beak/panel.dart';

import '../panel/details/details.dart';

/// The activities resource, with the parts Beak cannot derive.
///
/// Its model, label, icon and section still come from the schema class and
/// `beak.yaml`; this adds what a person decided.
BeakResource beakResource(BeakResource generated) =>
    generated.copyWith(detail: activityDetail);
