import 'package:beak/testing.dart';
import 'package:beak/beak.dart';
import 'package:showcase/beak/registry.g.dart';
import 'package:showcase/resources/assets/models/asset.dart';
import 'package:showcase/resources/candles/models/price_candle.dart';
import 'package:showcase/resources/faqs/models/faq.dart';
import 'package:showcase/resources/habitats/models/habitat.dart';
import 'package:showcase/resources/invoices/models/invoice.dart';
import 'package:showcase/resources/invoices/models/invoice_item.dart';
import 'package:showcase/resources/keepers/models/keeper.dart';
import 'package:showcase/resources/messages/models/message.dart';
import 'package:showcase/resources/plans/models/plan.dart';
import 'package:showcase/resources/plans/models/plan_perk.dart';
import 'package:showcase/resources/sightings/models/sighting.dart';
import 'package:showcase/resources/specimens/models/specimen.dart';
import 'package:showcase/resources/tasks/models/task.dart';
import 'package:showcase/seeders/aviary_ids.dart';

/// An in-memory source holding a few rows of every model the pages read.
///
/// Rows come from [BeakRecordFactory], which derives a valid value for every
/// column from the model itself, so the fixture cannot drift from the schema.
/// Only what a page looks up by identity, or groups by, is overridden.
InMemoryBeakDataSource aviarySource() {
  final factory = BeakRecordFactory();
  final source = InMemoryBeakDataSource(registry: buildBeakRegistry());
  final now = DateTime.now().toUtc();

  BeakRecord row(BeakModel model, Map<String, Object?> overrides) =>
      factory.build(
        model,
        overrides: {
          for (final MapEntry(:key, :value) in overrides.entries)
            key: BeakValue.of(value),
        },
      );

  List<BeakRecord> rows(
    BeakModel model,
    int count,
    Map<String, Object?> Function(int index) overrides,
  ) => [
    for (var index = 0; index < count; index++) row(model, overrides(index)),
  ];

  const keeperIds = [
    AviaryIds.ada,
    AviaryIds.linus,
    AviaryIds.grace,
    AviaryIds.tim,
  ];
  const keeperNames = ['Ada Wing', 'Linus Talon', 'Grace Beak', 'Tim Plume'];
  const habitatIds = [
    AviaryIds.rainforest,
    AviaryIds.outback,
    AviaryIds.savanna,
    AviaryIds.cliffs,
    AviaryIds.cloudForest,
    AviaryIds.wetlands,
  ];
  const countries = ['BR', 'AU', 'ZA', 'NZ', 'PE', 'IN'];
  // Short, because the test font is as wide as it is tall and a pie chart
  // keeps its legend to one row.
  const habitatNames = [
    'Canopy',
    'Outback',
    'Savanna',
    'Cliffs',
    'Cloud',
    'Wetlands',
  ];

  source
    ..seed(
      const KeeperModel(),
      rows(
        const KeeperModel(),
        keeperIds.length,
        (index) => {
          'id': keeperIds[index],
          'name': keeperNames[index],
          'email':
              '${keeperNames[index].split(' ').first.toLowerCase()}'
              '@aviary.example',
          'bio': 'Looks after the ${habitatNames[index]}.',
          'avatar': null,
        },
      ),
    )
    ..seed(
      const HabitatModel(),
      rows(
        const HabitatModel(),
        habitatIds.length,
        (index) => {
          'id': habitatIds[index],
          'name': habitatNames[index],
          'country_code': countries[index],
          'capacity': 20 + index * 5,
          'latitude': -20.0 + index * 10,
          'longitude': -60.0 + index * 25,
        },
      ),
    )
    ..seed(
      const SpecimenModel(),
      rows(
        const SpecimenModel(),
        8,
        (index) => {
          'id': 'specimen-$index',
          'habitat_id': habitatIds[index % habitatIds.length],
          'band_code': 'AV-${1000 + index}',
          'photo': null,
          'health_certificate': null,
        },
      ),
    )
    ..seed(
      const TaskModel(),
      rows(
        const TaskModel(),
        9,
        (index) => {
          'status': TaskStatus.values[index % TaskStatus.values.length].name,
          'starts_at': now.add(Duration(hours: index * 5 - 20)),
          'ends_at': now.add(Duration(hours: index * 5 - 18)),
          'assignee_id': keeperIds[index % keeperIds.length],
        },
      ),
    )
    ..seed(
      const SightingModel(),
      rows(
        const SightingModel(),
        28,
        (index) => {
          'spotted_on': DateTime.utc(2026, 9, 1 + index),
          'birds_seen': 15 + (index * 7) % 23,
          'habitat_id': null,
        },
      ),
    )
    ..seed(
      const PriceCandleModel(),
      rows(
        const PriceCandleModel(),
        8,
        (index) => {
          'traded_on': DateTime.utc(2026, 9, 1 + index),
          'open': 4.0 + index * 0.1,
          'high': 4.6 + index * 0.1,
          'low': 3.8 + index * 0.1,
          'close': 4.3 + index * 0.1,
        },
      ),
    )
    ..seed(
      const MessageModel(),
      rows(
        const MessageModel(),
        4,
        (index) => {
          'is_mine': index.isOdd,
          'is_read': index < 2,
          'sent_at': now.subtract(Duration(hours: 10 - index)),
        },
      ),
    )
    ..seed(
      const AssetModel(),
      rows(
        const AssetModel(),
        9,
        (index) => {
          'collection': AssetCollection.values[index % 4].name,
          'is_folder': index == 3,
          'position': index,
          'url': 'assets/photos/aviary-${index % 6 + 1}.jpg',
        },
      ),
    )
    ..seed(const InvoiceModel(), [
      row(const InvoiceModel(), {
        'id': AviaryIds.invoice,
        'ordered_by_id': AviaryIds.linus,
      }),
    ])
    ..seed(
      const InvoiceItemModel(),
      rows(
        const InvoiceItemModel(),
        3,
        (_) => {'invoice_id': AviaryIds.invoice},
      ),
    )
    ..seed(
      const PlanModel(),
      rows(
        const PlanModel(),
        3,
        (index) => {
          'id': 'plan-$index',
          'featured': index == 1,
          'monthly_price': 5.0 + index * 10,
          'yearly_price': 50.0 + index * 100,
        },
      ),
    )
    ..seed(
      const PlanPerkModel(),
      rows(
        const PlanPerkModel(),
        6,
        (index) => {'plan_id': 'plan-${index % 3}'},
      ),
    )
    ..seed(
      const FaqModel(),
      rows(
        const FaqModel(),
        4,
        (index) => {
          'category': index.isEven ? 'Visiting' : 'Sponsoring',
          'position': index,
        },
      ),
    );
  return source;
}
