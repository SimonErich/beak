import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import 'models/specimen.dart';

/// The birds: every column kind in one table, filterable and searchable.
final class SpecimenResource extends BeakResource {
  /// Creates the specimens section.
  SpecimenResource()
    : super(
        model: const SpecimenModel(),
        title: 'Specimens',
        icon: const BeakIconToken(OiIcons.bird),
        navigationGroup: 'Collection',
        navigationRank: 1,
        globalSearchSources: [
          SpecimenModel.commonName,
          SpecimenModel.scientificName,
          SpecimenModel.habitat.name,
        ],
        filters: [
          SpecimenModel.diet.selectFilter(),
          SpecimenModel.endangered.boolFilter(),
          SpecimenModel.habitat.relationFilter(),
          SpecimenModel.weightInGrams.numberRangeFilter(),
        ],
        screens: [
          BeakTableScreen(
            fields: [
              SpecimenModel.photo,
              SpecimenModel.commonName,
              SpecimenModel.diet,
              SpecimenModel.habitat.name.formatted(
                BeakValueFormat.text,
                label: 'Habitat',
              ),
              SpecimenModel.weightInGrams,
              SpecimenModel.endangered,
              SpecimenModel.bandCode,
            ],
          ),
        ],
      );
}
