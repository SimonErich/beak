import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../../keepers/models/keeper.dart';
import '../../specimens/models/specimen.dart';

part 'habitat.beak.dart';

/// A biome the aviary keeps, with the place its birds come from.
// --8<-- [start:Habitat]
@Resource(timestamps: true)
final class Habitat extends BeakSchema {
  /// The exhibit's name.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// ISO 3166-1 alpha-2 code of the country the birds come from.
  @Column(filterable: true, rules: [BeakMinLength(2), BeakMaxLength(2)])
  late final String countryCode;

  /// How many birds the exhibit holds at most.
  @Column(sortable: true, rules: [BeakMin(0)])
  late final int capacity;

  /// Latitude of the wild range's centre.
  @Column(precision: 4)
  late final double latitude;

  /// Longitude of the wild range's centre.
  @Column(precision: 4)
  late final double longitude;

  /// The birds that live here (has-many relationship).
  @HasMany(onDelete: BeakOnDelete.setNull)
  late final List<Specimen> specimens;

  /// The keepers who look after it (many-to-many, through a pivot table).
  @BelongsToMany(pivotTable: 'habitat_keeper', inverse: false)
  late final List<Keeper> keepers;
}
// --8<-- [end:Habitat]
