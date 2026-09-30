import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../../habitats/models/habitat.dart';

part 'sighting.beak.dart';

/// Wild birds counted from the aviary's roof, one row per day.
///
/// The charts page reads these rows: a line and an area chart over the days,
/// and a heat map of weekdays against weeks.
@Resource()
final class Sighting extends BeakSchema {
  /// The day of the count.
  @Display()
  @Column(sortable: true)
  late final DateTime spottedOn;

  /// How many birds were counted.
  @Column(sortable: true, rules: [BeakMin(0)])
  late final int birdsSeen;

  /// The habitat whose visitors were counted.
  @BelongsTo(onDelete: BeakOnDelete.setNull, inverse: false)
  late final Habitat? habitat;
}
