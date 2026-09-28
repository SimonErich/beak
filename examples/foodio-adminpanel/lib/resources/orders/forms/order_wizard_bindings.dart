import 'package:beak/panel.dart';

import '../../../models/models.dart';

/// Customer label used while describing profile-dependent wizard choices.
String customerFirstName(BeakFormReader state) =>
    (state.asOrder.customer?.name ?? 'the customer').split(' ').first;
