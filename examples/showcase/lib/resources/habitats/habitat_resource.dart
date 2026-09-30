import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import 'models/habitat.dart';

/// The exhibits, with the birds and keepers each one connects to.
final class HabitatResource extends BeakResource {
  /// Creates the habitats section.
  HabitatResource()
    : super(
        model: const HabitatModel(),
        title: 'Habitats',
        icon: const BeakIconToken(OiIcons.trees),
        navigationGroup: 'Collection',
        navigationRank: 2,
        globalSearchSources: [HabitatModel.name, HabitatModel.countryCode],
        filters: [HabitatModel.capacity.numberRangeFilter()],
      );
}
