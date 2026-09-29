import 'package:beak/migrations.dart';

import 'aviary_dates.dart';
import 'aviary_ids.dart';

/// One seeded bird: the columns that differ from bird to bird.
typedef _Bird = ({
  String name,
  String latin,
  String habitat,
  String diet,
  double grams,
  int wingspan,
  int clutch,
  bool endangered,
  String color,
  int costInCents,
});

/// One trading day's price movement as `(change, high, low)` around the open.
typedef _Move = (double, double, double);

const List<_Bird> _birds = [
  (
    name: 'Scarlet macaw',
    latin: 'Ara macao',
    habitat: AviaryIds.rainforest,
    diet: 'frugivore',
    grams: 1000,
    wingspan: 90,
    clutch: 2,
    endangered: false,
    color: '#e03c31',
    costInCents: 250000,
  ),
  (
    name: 'Toco toucan',
    latin: 'Ramphastos toco',
    habitat: AviaryIds.rainforest,
    diet: 'frugivore',
    grams: 540,
    wingspan: 55,
    clutch: 2,
    endangered: false,
    color: '#f28c28',
    costInCents: 180000,
  ),
  (
    name: 'Hyacinth macaw',
    latin: 'Anodorhynchus hyacinthinus',
    habitat: AviaryIds.rainforest,
    diet: 'granivore',
    grams: 1500,
    wingspan: 120,
    clutch: 2,
    endangered: true,
    color: '#1f4fa3',
    costInCents: 900000,
  ),
  (
    name: 'Budgerigar',
    latin: 'Melopsittacus undulatus',
    habitat: AviaryIds.outback,
    diet: 'granivore',
    grams: 35,
    wingspan: 30,
    clutch: 6,
    endangered: false,
    color: '#8fd14f',
    costInCents: 2500,
  ),
  (
    name: 'Galah',
    latin: 'Eolophus roseicapilla',
    habitat: AviaryIds.outback,
    diet: 'granivore',
    grams: 300,
    wingspan: 70,
    clutch: 4,
    endangered: false,
    color: '#e8a0b4',
    costInCents: 45000,
  ),
  (
    name: 'Rainbow lorikeet',
    latin: 'Trichoglossus moluccanus',
    habitat: AviaryIds.outback,
    diet: 'nectarivore',
    grams: 130,
    wingspan: 45,
    clutch: 2,
    endangered: false,
    color: '#2fa84f',
    costInCents: 30000,
  ),
  (
    name: 'Lilac-breasted roller',
    latin: 'Coracias caudatus',
    habitat: AviaryIds.savanna,
    diet: 'insectivore',
    grams: 100,
    wingspan: 55,
    clutch: 3,
    endangered: false,
    color: '#4c7fc9',
    costInCents: 60000,
  ),
  (
    name: 'Superb starling',
    latin: 'Lamprotornis superbus',
    habitat: AviaryIds.savanna,
    diet: 'insectivore',
    grams: 65,
    wingspan: 40,
    clutch: 4,
    endangered: false,
    color: '#2a6f8e',
    costInCents: 15000,
  ),
  (
    name: 'Kea',
    latin: 'Nestor notabilis',
    habitat: AviaryIds.cliffs,
    diet: 'frugivore',
    grams: 900,
    wingspan: 90,
    clutch: 3,
    endangered: true,
    color: '#6b8e23',
    costInCents: 320000,
  ),
  (
    name: 'Kakapo',
    latin: 'Strigops habroptilus',
    habitat: AviaryIds.cliffs,
    diet: 'frugivore',
    grams: 2000,
    wingspan: 90,
    clutch: 2,
    endangered: true,
    color: '#7ba05b',
    costInCents: 0,
  ),
  (
    name: 'Andean cock-of-the-rock',
    latin: 'Rupicola peruvianus',
    habitat: AviaryIds.cloudForest,
    diet: 'frugivore',
    grams: 250,
    wingspan: 60,
    clutch: 2,
    endangered: false,
    color: '#f26b1d',
    costInCents: 220000,
  ),
  (
    name: 'Sword-billed hummingbird',
    latin: 'Ensifera ensifera',
    habitat: AviaryIds.cloudForest,
    diet: 'nectarivore',
    grams: 12,
    wingspan: 15,
    clutch: 2,
    endangered: false,
    color: '#1c9c6b',
    costInCents: 80000,
  ),
  (
    name: 'Greater flamingo',
    latin: 'Phoenicopterus roseus',
    habitat: AviaryIds.wetlands,
    diet: 'piscivore',
    grams: 3000,
    wingspan: 150,
    clutch: 1,
    endangered: false,
    color: '#f6a8b8',
    costInCents: 140000,
  ),
  (
    name: 'Painted stork',
    latin: 'Mycteria leucocephala',
    habitat: AviaryIds.wetlands,
    diet: 'piscivore',
    grams: 2500,
    wingspan: 160,
    clutch: 3,
    endangered: true,
    color: '#e7b0b0',
    costInCents: 175000,
  ),
];

const List<_Move> _moves = [
  (0.30, 0.45, 0.10),
  (-0.20, 0.15, 0.35),
  (0.40, 0.60, 0.05),
  (0.10, 0.30, 0.20),
  (-0.50, 0.10, 0.60),
  (-0.10, 0.25, 0.30),
  (0.35, 0.50, 0.15),
  (0.25, 0.40, 0.10),
  (-0.30, 0.20, 0.45),
  (0.20, 0.35, 0.20),
  (0.45, 0.70, 0.10),
  (-0.15, 0.15, 0.30),
  (0.05, 0.25, 0.25),
  (0.30, 0.50, 0.10),
  (-0.40, 0.10, 0.55),
  (0.15, 0.30, 0.15),
  (0.35, 0.55, 0.10),
  (-0.05, 0.20, 0.25),
  (0.25, 0.40, 0.15),
  (0.10, 0.30, 0.20),
];

/// Idempotent demonstration data for the Aviary.
///
/// Every row has a fixed identity, and a row that exists is left alone, so
/// running it twice, or after an edit in the panel, changes nothing.
final class AviarySeeder extends Seeder {
  /// Creates the deterministic demo seeder.
  const AviarySeeder();

  @override
  String get name => 'AviarySeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    Future<void> insert(String table, Map<String, Object?> values) async {
      final id = values['id'];
      if (id == null) throw StateError('A seed row needs an identity.');
      if (await adapter.selectOne(
            QueryDescriptor(
              table: table,
              where: const Field<Object>('id').eq(id),
              limit: 1,
            ),
          ) !=
          null) {
        return;
      }
      await adapter.insert(InsertDescriptor(table: table, values: values));
    }

    Future<void> link(String habitat, String keeper) async {
      final existing = await adapter.selectOne(
        QueryDescriptor(
          table: 'habitat_keeper',
          where: const Field<String>(
            'habitat_id',
          ).eq(habitat).and(const Field<String>('keeper_id').eq(keeper)),
          limit: 1,
        ),
      );
      if (existing == null) {
        await adapter.insert(
          InsertDescriptor(
            table: 'habitat_keeper',
            values: {'habitat_id': habitat, 'keeper_id': keeper},
          ),
        );
      }
    }

    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    String id(int group, int number) =>
        '00000000-0000-4000-8000-'
        '${group.toString().padLeft(4, '0')}'
        '${number.toString().padLeft(8, '0')}';
    Map<String, Object?> stamped(Map<String, Object?> values) => {
      ...values,
      'created_at': now,
      'updated_at': now,
    };

    for (final (habitat, name, country, capacity, latitude, longitude) in [
      (AviaryIds.rainforest, 'Rainforest canopy', 'BR', 40, -3.4653, -62.2159),
      (AviaryIds.outback, 'Outback scrub', 'AU', 30, -25.2744, 133.7751),
      (AviaryIds.savanna, 'Savanna', 'ZA', 25, -23.9884, 31.5547),
      (AviaryIds.cliffs, 'Island cliffs', 'NZ', 15, -44.0, 170.0),
      (AviaryIds.cloudForest, 'Cloud forest', 'PE', 20, -13.1631, -72.545),
      (AviaryIds.wetlands, 'Wetlands', 'IN', 35, 21.9497, 88.9),
    ]) {
      await insert(
        'habitats',
        stamped({
          'id': habitat,
          'name': name,
          'country_code': country,
          'capacity': capacity,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );
    }

    for (final (keeper, name, email, role, bio) in [
      (
        AviaryIds.ada,
        'Ada Wing',
        'ada@aviary.example',
        'head',
        'Runs the aviary and knows every bird by its call.',
      ),
      (
        AviaryIds.linus,
        'Linus Talon',
        'linus@aviary.example',
        'senior',
        'Leads the rainforest and the cloud forest.',
      ),
      (
        AviaryIds.grace,
        'Grace Beak',
        'grace@aviary.example',
        'apprentice',
        'Second year, mostly on the feeding round.',
      ),
      (
        AviaryIds.tim,
        'Tim Plume',
        'tim@aviary.example',
        'volunteer',
        'Weekends, and every hatching day.',
      ),
    ]) {
      await insert('keepers', {
        'id': keeper,
        'name': name,
        'email': email,
        'role': role,
        'bio': bio,
        'deleted_at': null,
      });
    }
    await insert('keeper_profiles', {
      'id': id(1, 1),
      'certification': 'Head keeper licence',
      'emergency_phone': '+43 1 555 0142',
      'certified_since': DateTime.utc(2014, 3, 1),
      'keeper_id': AviaryIds.ada,
    });
    await insert('keeper_profiles', {
      'id': id(1, 2),
      'certification': 'Avian husbandry, level 3',
      'emergency_phone': '+43 1 555 0143',
      'certified_since': DateTime.utc(2019, 6, 15),
      'keeper_id': AviaryIds.linus,
    });
    for (final (habitat, keeper) in [
      (AviaryIds.rainforest, AviaryIds.ada),
      (AviaryIds.rainforest, AviaryIds.linus),
      (AviaryIds.cloudForest, AviaryIds.linus),
      (AviaryIds.outback, AviaryIds.grace),
      (AviaryIds.savanna, AviaryIds.grace),
      (AviaryIds.cliffs, AviaryIds.ada),
      (AviaryIds.wetlands, AviaryIds.tim),
    ]) {
      await link(habitat, keeper);
    }

    for (final (index, bird) in _birds.indexed) {
      await insert(
        'specimens',
        stamped({
          'id': id(100, index + 1),
          'common_name': bird.name,
          'scientific_name': bird.latin,
          'reference_url':
              'https://en.wikipedia.org/wiki/${bird.latin.replaceAll(' ', '_')}',
          'reporter_email': index.isEven ? 'reports@aviary.example' : null,
          'notes': 'Arrived healthy. Prefers the upper perches.',
          'care_guide':
              '<p><strong>${bird.name}</strong>: fresh water daily, '
              'and a rotation of enrichment toys.</p>',
          'clutch_size': bird.clutch,
          'wingspan_in_centimeters': bird.wingspan,
          'weight_in_grams': bird.grams,
          'acquisition_cost': bird.costInCents,
          'currency': 'EUR',
          'endangered': bird.endangered,
          'hatched_at': DateTime.utc(2020 + index % 5, 1 + index % 12, 5),
          'diet': bird.diet,
          'telemetry': '{"battery":${60 + index * 2},"fixes":${index * 11}}',
          'plumage_color': bird.color,
          'photo': null,
          'health_certificate': null,
          'band_code': 'AV-${1001 + index}',
          'habitat_id': bird.habitat,
          'deleted_at': null,
        }),
      );
    }

    final tasks = [
      ('Morning seed round', 'feeding', 'done', 0, 7, 1, AviaryIds.grace),
      (
        'Scrub the wetland perches',
        'cleaning',
        'doing',
        0,
        10,
        2,
        AviaryIds.tim,
      ),
      (
        'Fruit round for the canopy',
        'feeding',
        'todo',
        0,
        12,
        3,
        AviaryIds.linus,
      ),
      ('Vet check for the kakapo', 'medical', 'todo', 1, 9, 1, AviaryIds.ada),
      (
        'New perches in the cliffs',
        'enrichment',
        'todo',
        2,
        14,
        2,
        AviaryIds.ada,
      ),
      (
        'Refill the nectar feeders',
        'feeding',
        'todo',
        2,
        8,
        3,
        AviaryIds.grace,
      ),
      (
        'Deep clean the outback pond',
        'cleaning',
        'todo',
        3,
        10,
        4,
        AviaryIds.tim,
      ),
      ('Weigh the flamingos', 'medical', 'todo', 4, 11, 5, AviaryIds.linus),
      (
        'Build a puzzle feeder',
        'enrichment',
        'doing',
        5,
        13,
        4,
        AviaryIds.grace,
      ),
      ('Evening head count', 'feeding', 'done', -1, 18, 1, AviaryIds.ada),
      ('Trim the savanna acacia', 'cleaning', 'done', -2, 9, 2, AviaryIds.tim),
      (
        'Vaccinate the budgerigars',
        'medical',
        'done',
        -3,
        15,
        3,
        AviaryIds.linus,
      ),
    ];
    for (final (index, (title, category, status, day, hour, position, who))
        in tasks.indexed) {
      final start = today.add(Duration(days: day, hours: hour));
      await insert(
        'tasks',
        stamped({
          'id': id(200, index + 1),
          'title': title,
          'status': status,
          'category': category,
          'position': position,
          'starts_at': start,
          'ends_at': start.add(const Duration(hours: 2)),
          'all_day': index == 4,
          'assignee_id': who,
          'habitat_id': null,
        }),
      );
    }

    final habitats = [
      AviaryIds.rainforest,
      AviaryIds.outback,
      AviaryIds.savanna,
      AviaryIds.cliffs,
    ];
    for (var day = 0; day < AviaryDates.countDays; day++) {
      final weekend = day % 7 >= 5;
      await insert('sightings', {
        'id': id(300, day + 1),
        'spotted_on': AviaryDates.countStart.add(Duration(days: day)),
        'birds_seen': 18 + (day * 7) % 23 + (weekend ? 14 : 0),
        'habitat_id': habitats[day % habitats.length],
      });
    }

    var open = 4.20;
    for (final (index, (change, high, low)) in _moves.indexed) {
      final close = open + change;
      await insert('price_candles', {
        'id': id(400, index + 1),
        'traded_on': AviaryDates.pricesStart.add(Duration(days: index)),
        'open': double.parse(open.toStringAsFixed(2)),
        'high': double.parse(
          ((open > close ? open : close) + high).toStringAsFixed(2),
        ),
        'low': double.parse(
          ((open < close ? open : close) - low).toStringAsFixed(2),
        ),
        'close': double.parse(close.toStringAsFixed(2)),
      });
      open = close;
    }

    for (final (index, (sender, subject, body, mine, read)) in [
      (
        'Ada Wing',
        'Morning round',
        'The morning round is done. Two chicks in the cloud forest.',
        false,
        true,
      ),
      (
        'You',
        'Morning round',
        'Great. I will weigh them after lunch.',
        true,
        true,
      ),
      (
        'Linus Talon',
        'Seed order',
        'We are down to one sack of millet. Can you reorder?',
        false,
        true,
      ),
      ('You', 'Seed order', 'Ordered. It arrives on Thursday.', true, true),
      (
        'Grace Beak',
        'Perch repair',
        'The high perch in the outback is loose again.',
        false,
        false,
      ),
      (
        'Tim Plume',
        'Weekend cover',
        'I can take Saturday if someone covers the wetlands pump check.',
        false,
        false,
      ),
      (
        'Ada Wing',
        'Vet visit',
        'The vet comes on Tuesday. Please have the kakapo weighed.',
        false,
        false,
      ),
      ('You', 'Vet visit', 'Noted. I will do it first thing.', true, true),
    ].indexed) {
      await insert('messages', {
        'id': id(500, index + 1),
        'sender': sender,
        'subject': subject,
        'body': body,
        'sent_at': today.subtract(Duration(hours: 40 - index * 5)),
        'is_mine': mine,
        'is_read': read,
      });
    }

    var position = 0;
    Future<void> asset({
      required String name,
      required String collection,
      required String url,
      String? caption,
      bool folder = false,
      int size = 0,
    }) => insert('assets', {
      'id': id(600, ++position),
      'name': name,
      'caption': caption,
      'url': url,
      'collection': collection,
      'is_folder': folder,
      'size_in_bytes': size,
      'modified_at': today.subtract(Duration(days: position)),
      'position': position,
    });
    for (final (index, slide) in [
      'Dawn in the canopy',
      'A kea inspecting a boot',
      'Flamingos at feeding time',
    ].indexed) {
      await asset(
        name: 'slide-${index + 1}.jpg',
        collection: 'carousel',
        url: 'assets/photos/aviary-${index + 1}.jpg',
        caption: slide,
        size: 240000 + index * 12000,
      );
    }
    for (var index = 0; index < 8; index++) {
      await asset(
        name: 'Portrait ${index + 1}',
        collection: 'gallery',
        url: 'assets/photos/aviary-${index % 6 + 1}.jpg',
        size: 90000 + index * 4000,
      );
    }
    await asset(
      name: 'Morning chorus',
      collection: 'video',
      url:
          'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
      caption: 'The dawn chorus in the canopy',
      size: 1200000,
    );
    await asset(
      name: 'Health certificates',
      collection: 'file',
      url: 'https://example.com/files/certificates',
      folder: true,
    );
    await asset(
      name: 'Feeding plan.pdf',
      collection: 'file',
      url: 'https://example.com/files/feeding-plan.pdf',
      size: 182000,
    );
    await asset(
      name: 'Vet report.pdf',
      collection: 'file',
      url: 'https://example.com/files/vet-report.pdf',
      size: 96000,
    );

    for (final (number, status, issued, total, supplier) in [
      (
        'INV-2026-013',
        'paid',
        DateTime.utc(2026, 8, 12),
        210.0,
        'Hirse & Söhne',
      ),
      (
        'INV-2026-014',
        'sent',
        DateTime.utc(2026, 9, 10),
        345.0,
        'Hirse & Söhne',
      ),
      (
        'INV-2026-015',
        'draft',
        DateTime.utc(2026, 9, 24),
        128.0,
        'Nectar Direct',
      ),
    ]) {
      final isShown = number == 'INV-2026-014';
      await insert('invoices', {
        'id': isShown ? AviaryIds.invoice : id(700, total.toInt()),
        'number': number,
        'supplier': supplier,
        'status': status,
        'issued_on': issued,
        'due_on': issued.add(const Duration(days: 30)),
        'subtotal': isShown ? 320.0 : total,
        'discount': isShown ? 20.0 : 0.0,
        'shipping': isShown ? 15.0 : 0.0,
        'tax': isShown ? 30.0 : 0.0,
        'total': total,
        'ordered_by_id': AviaryIds.linus,
      });
    }
    for (final (index, (description, quantity, unit)) in [
      ('Millet, 25 kg', 4, 32.5),
      ('Sunflower seed, 25 kg', 2, 41.0),
      ('Mealworms, 5 kg', 6, 18.0),
    ].indexed) {
      await insert('invoice_items', {
        'id': id(800, index + 1),
        'description': description,
        'quantity': quantity,
        'unit_price': unit,
        'amount': quantity * unit,
        'invoice_id': AviaryIds.invoice,
      });
    }

    var perk = 0;
    for (final (index, (planName, tagline, monthly, yearly, featured, perks))
        in [
          (
            'Friend',
            'Follow one bird all year',
            5.0,
            50.0,
            false,
            ['A monthly photo', 'Your name on the sponsor wall', 'Newsletter'],
          ),
          (
            'Patron',
            'Meet the keepers',
            15.0,
            150.0,
            true,
            [
              'Everything in Friend',
              'A behind-the-scenes tour',
              'Feed a bird yourself',
              'Two guest tickets',
            ],
          ),
          (
            'Guardian',
            'Adopt a whole habitat',
            40.0,
            400.0,
            false,
            [
              'Everything in Patron',
              'A plaque at the habitat',
              'Quarterly keeper call',
              'Name a hatchling',
              'Unlimited visits',
            ],
          ),
        ].indexed) {
      final plan = id(900, index + 1);
      await insert('plans', {
        'id': plan,
        'name': planName,
        'tagline': tagline,
        'monthly_price': monthly,
        'yearly_price': yearly,
        'featured': featured,
      });
      for (final label in perks) {
        await insert('plan_perks', {
          'id': id(950, ++perk),
          'label': label,
          'plan_id': plan,
        });
      }
    }

    for (final (index, (question, answer, category)) in [
      ('When is the aviary open?', 'Every day from 9:00 to 17:00.', 'Visiting'),
      (
        'Can I feed the birds?',
        'Only with the seed sold at the gate.',
        'Visiting',
      ),
      ('Are dogs allowed?', 'Assistance dogs only.', 'Visiting'),
      (
        'How does sponsoring work?',
        'Pick a plan and a bird; we send updates.',
        'Sponsoring',
      ),
      (
        'Is sponsoring tax deductible?',
        'Yes, for registered charities in Austria.',
        'Sponsoring',
      ),
      ('Can I cancel?', 'At any time, from the sponsor page.', 'Sponsoring'),
    ].indexed) {
      await insert('faqs', {
        'id': id(970, index + 1),
        'question': question,
        'answer': answer,
        'category': category,
        'position': index + 1,
      });
    }
  }
}
