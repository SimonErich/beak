@TestOn('vm')
library;

import 'package:beak/migrations.dart';
import 'package:showcase/resources/habitats/models/habitat.dart';
import 'package:showcase/resources/keepers/models/keeper.dart';
import 'package:showcase/resources/specimens/models/specimen.dart';
import 'package:showcase/seeders/aviary_ids.dart';
import 'package:test/test.dart';

import 'support/aviary_test_api.dart';

void main() {
  late AviaryTestApi api;

  setUp(() async => api = await AviaryTestApi.start());
  tearDown(() => api.dispose());

  test('migrating and seeding fills the tables the pages read', () async {
    final specimens = await api.client.query(
      'specimens',
      const SpecimenModel().query(),
    );
    final habitats = await api.client.query(
      'habitats',
      const HabitatModel().query(),
    );
    expect(specimens.total, 14);
    expect(habitats.total, 6);
  });

  test('a specimen round-trips every column kind through the API', () async {
    final created = await api.client.create(
      'specimens',
      const SpecimenModel().record([
        SpecimenModel.commonName.to('Golden pheasant'),
        SpecimenModel.notes.to('Shy. Keep the hide closed.'),
        SpecimenModel.careGuide.to('<p>Fresh water.</p>'),
        SpecimenModel.clutchSize.to(8),
        SpecimenModel.wingspanInCentimeters.to(70),
        SpecimenModel.weightInGrams.to(650.5),
        SpecimenModel.acquisitionCost.to(const BeakDecimal(12550, scale: 2)),
        SpecimenModel.endangered.to(false),
        SpecimenModel.hatchedAt.to(DateTime.utc(2025, 4, 2, 6)),
        SpecimenModel.diet.to(Diet.granivore),
        SpecimenModel.plumageColor.to('#d4af37'),
        SpecimenModel.bandCode.to('AV-2001'),
        SpecimenModel.habitatId.to(AviaryIds.savanna),
      ]),
    );
    final fetched = await api.client.getOne('specimens', created['id']!.raw!);
    expect(fetched, isNotNull);
    expect(SpecimenModel.commonName.readFrom(fetched!), 'Golden pheasant');
    expect(SpecimenModel.clutchSize.readFrom(fetched), 8);
    expect(SpecimenModel.weightInGrams.readFrom(fetched), 650.5);
    expect(
      SpecimenModel.acquisitionCost.readFrom(fetched),
      const BeakDecimal(12550, scale: 2),
    );
    expect(SpecimenModel.diet.readFrom(fetched), Diet.granivore);
    expect(
      SpecimenModel.hatchedAt.readFrom(fetched),
      DateTime.utc(2025, 4, 2, 6),
    );
    expect(SpecimenModel.plumageColor.readFrom(fetched), '#d4af37');
  });

  test('a soft delete hides a specimen and a restore brings it back', () async {
    final page = await api.client.query(
      'specimens',
      const SpecimenModel().query(filter: SpecimenModel.commonName.eq('Kea')),
    );
    final kea = page.items.single['id']!.raw!;
    await api.client.delete('specimens', kea);
    expect(await api.client.getOne('specimens', kea), isNull);
    await api.client.restore('specimens', kea);
    expect(await api.client.getOne('specimens', kea), isNotNull);
  });

  test('a habitat loads its keepers through the pivot table', () async {
    final page = await api.client.query(
      'habitats',
      const HabitatModel().query(
        filter: HabitatModel.countryCode.eq('BR'),
        relationLoads: [BeakRelationLoad(HabitatModel.keepers.key)],
      ),
    );
    final rainforest = page.items.single;
    final keepers = rainforest.relations['keepers'] ?? const [];
    expect(
      keepers.map((keeper) => KeeperModel.name.readFrom(keeper)),
      unorderedEquals(['Ada Wing', 'Linus Talon']),
    );
  });

  test('attach and detach maintain the pivot rows', () async {
    await api.client.attach('habitats', AviaryIds.savanna, 'keepers', [
      AviaryIds.tim,
    ]);
    Future<List<BeakRecord>> keepersOfSavanna() async {
      final page = await api.client.query(
        'habitats',
        const HabitatModel().query(
          filter: HabitatModel.countryCode.eq('ZA'),
          relationLoads: [BeakRelationLoad(HabitatModel.keepers.key)],
        ),
      );
      return page.items.single.relations['keepers'] ?? const [];
    }

    expect(await keepersOfSavanna(), hasLength(2));
    await api.client.detach('habitats', AviaryIds.savanna, 'keepers', [
      AviaryIds.tim,
    ]);
    expect(await keepersOfSavanna(), hasLength(1));
  });
}
