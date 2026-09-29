import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../../habitats/models/habitat.dart';

part 'specimen.beak.dart';

/// What a specimen eats, which decides its feeder and its feed order.
enum Diet {
  /// Eats seeds and grain.
  granivore,

  /// Eats fruit and berries.
  frugivore,

  /// Eats insects.
  insectivore,

  /// Eats fish.
  piscivore,

  /// Drinks nectar.
  nectarivore,
}

/// The kitchen sink: one field of every column kind Beak has.
///
/// Every file that names a column kind in the docs points here, and
/// `test/column_kind_matrix_test.dart` fails to compile when Beak gains a kind
/// this class does not use.
// --8<-- [start:Specimen]
@Resource(softDeletes: true, timestamps: true)
final class Specimen extends BeakSchema {
  /// The name keepers call the bird by (string column).
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(120)])
  late final String commonName;

  /// The Latin binomial (string column, searchable).
  @Column(searchable: true)
  late final String? scientificName;

  /// A reference page with the species account (url semantic).
  @Column(semantic: BeakSemantic.url())
  late final String? referenceUrl;

  /// Who reported the bird, for follow-up (email semantic).
  @Column(semantic: BeakSemantic.email())
  late final String? reporterEmail;

  /// Free-form keeper notes (text column).
  late final BeakText? notes;

  /// The care guide, formatted (rich-text column).
  late final BeakRichText? careGuide;

  /// Eggs in the last clutch (int column).
  @Column(rules: [BeakMin(0), BeakMax(30)])
  late final int clutchSize;

  /// Wingspan tip to tip (int column with a unit in its name).
  @Column(suffix: 'cm', rules: [BeakMin(1)])
  late final int wingspanInCentimeters;

  /// Body weight (decimal column).
  @Column(suffix: 'g', precision: 1, rules: [BeakMin(0)])
  late final double weightInGrams;

  /// What the bird cost to acquire (exact money, in the currency below).
  @Column(
    semantic: BeakSemantic.money(scale: 2),
    currencyFrom: #currency,
    defaultValue: BeakDecimal(0, scale: 2),
  )
  late final BeakDecimal acquisitionCost;

  /// ISO currency of [acquisitionCost].
  @Column(
    defaultValue: 'EUR',
    rules: [
      BeakInList(['EUR', 'USD']),
    ],
  )
  late final String currency;

  /// Whether the species is on a conservation list (bool column).
  @Column(filterable: true, trueLabel: 'Endangered', falseLabel: 'Stable')
  late final bool endangered;

  /// When the bird hatched (date-time column).
  @Column(sortable: true)
  late final DateTime? hatchedAt;

  /// The bird's diet (enum column with badges).
  @Column(defaultValue: Diet.granivore, filterable: true)
  @EnumLabels<Diet>({
    Diet.granivore: 'Granivore',
    Diet.frugivore: 'Frugivore',
    Diet.insectivore: 'Insectivore',
    Diet.piscivore: 'Piscivore',
    Diet.nectarivore: 'Nectarivore',
  })
  @Badges<Diet>({
    Diet.granivore: BeakColor.warning,
    Diet.frugivore: BeakColor.error,
    Diet.insectivore: BeakColor.success,
    Diet.piscivore: BeakColor.info,
    Diet.nectarivore: BeakColor.secondary,
  })
  late final Diet diet;

  /// Tracker readings as structured data (json column).
  late final BeakJson? telemetry;

  /// The dominant feather colour (color column).
  late final BeakHexColor? plumageColor;

  /// A portrait, resized on upload (image column).
  @Image(
    storagePath: 'specimens',
    maxSizeInBytes: 5242880,
    allowedTypes: [BeakFileType.png, BeakFileType.jpeg, BeakFileType.webp],
    transforms: [
      BeakThumbnailTransform(
        size: BeakDimensions.square(320),
        name: 'thumbnail',
      ),
    ],
  )
  late final BeakImageRef? photo;

  /// The vet's health certificate (file column).
  @FileField(
    storagePath: 'certificates',
    maxSizeInBytes: 10485760,
    allowedTypes: [BeakFileType.pdf],
  )
  late final BeakFileRef? healthCertificate;

  // --8<-- [start:SpecimenBandCode]
  /// The leg band, drawn by a renderer the app registers (custom column).
  @Custom('band-code')
  late final Object? bandCode;
  // --8<-- [end:SpecimenBandCode]

  /// Where the bird lives (belongs-to relationship).
  @BelongsTo(onDelete: BeakOnDelete.setNull)
  late final Habitat? habitat;
}
// --8<-- [end:Specimen]
