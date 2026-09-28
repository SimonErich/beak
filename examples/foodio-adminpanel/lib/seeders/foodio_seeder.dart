import 'package:beak/migrations.dart';

import '../beak/registry.g.dart';
import '../domain/foodio_clock.dart';
import '../domain/foodio_money.dart';

/// Stable identifiers used in reference links and integration tests.
abstract final class FoodioIds {
  /// Stable reference fixture for lena.
  static const lena = 'customer-lena';

  /// Stable reference fixture for nordlicht.
  static const nordlicht = 'organization-nordlicht';

  /// Stable reference fixture for kessler.
  static const kessler = 'organization-kessler';

  /// Stable reference fixture for lena company.
  static const lenaCompany = 'profile-lena-company';

  /// Stable reference fixture for lena private.
  static const lenaPrivate = 'profile-lena-private';

  /// Stable reference fixture for headquarters.
  static const headquarters = 'location-hq';

  /// Stable reference fixture for warehouse.
  static const warehouse = 'location-warehouse';

  /// Stable reference fixture for invoice.
  static const invoice = 'invoice-2026-0412';

  /// Stable reference fixture for risotto.
  static const risotto = 'dish-risotto';

  /// Stable reference fixture for dal.
  static const dal = 'dish-dal';

  /// Stable reference fixture for schnitzel.
  static const schnitzel = 'dish-schnitzel';

  /// Stable reference fixture for soup.
  static const soup = 'dish-soup';

  /// Stable reference fixture for strudel.
  static const strudel = 'dish-strudel';

  /// Stable reference fixture for lemonade.
  static const lemonade = 'dish-lemonade';

  /// Stable reference fixture for lunch15.
  static const lunch15 = 'voucher-lunch15';

  /// Stable reference fixture for budget.
  static const budget = 'budget-lena-2026-09';

  /// Public order identity, retaining the prototype’s deep link.
  static String order(int number) =>
      number == 24817 ? 'ord_3f9c24817b' : 'order-$number';

  /// A day-specific slot identity; start is minutes after midnight.
  static String slot(String date, int start) => 'slot-$date-$start';

  /// Stable selection identity for a dish and its named size.
  static String variant(String dish, String name) => '$dish-$name';
}

/// Reproducible, real records. Re-running never overwrites a user's demo changes.
final class FoodioSeeder extends Seeder {
  /// Seeds once without overwriting later operator changes.
  const FoodioSeeder();
  @override
  String get name => 'FoodioSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    final done = await adapter.selectOne(
      QueryDescriptor(
        table: 'app_settings',
        where: const Field<String>('key').eq('foodioSeedVersion'),
        limit: 1,
      ),
    );
    if (done != null) return;
    await adapter.transaction((transaction) async {
      final seed = _FoodioSeed(transaction);
      await seed.references();
      await seed.orders();
      await seed.activity();
      await seed.flush();
      await seed.insert('app_settings', {
        'id': 'seed-version',
        'key': 'foodioSeedVersion',
        'value': '1',
        'description': 'Gabel September 2026 reference dataset',
      });
    });
  }
}

final class _FoodioSeed {
  _FoodioSeed(this.adapter);
  final DatabaseAdapter adapter;
  final registry = buildBeakRegistry();
  final pending = <String, List<Map<String, Object?>>>{};
  final customers = <String, Map<String, Object?>>{};
  final profiles = <String, Map<String, Object?>>{};
  final organizations = <String, Map<String, Object?>>{};
  final dishAllergens = <String, String>{};
  final slotUse = <String, int>{};
  final budgetUse = <String, int>{};
  final stamp = FoodioClock.demoNow().toIso8601String();

  Map<String, Object?> row(String table, Map<String, Object?> data) {
    final model = registry.byTableOrThrow(table);
    final defaults = const BeakValidation().applyDefaults(
      model,
      BeakRecord.fromRow(data),
    );
    return {
      'created_at': stamp,
      'updated_at': stamp,
      ...defaults.values.map((key, value) => MapEntry(key, value.raw)),
    };
  }

  Future<void> insert(String table, Map<String, Object?> data) async =>
      adapter.insert(InsertDescriptor(table: table, values: row(table, data)));
  Future<void> add(String table, Map<String, Object?> data) async {
    final rows = pending.putIfAbsent(table, () => []);
    rows.add(row(table, data));
  }

  Future<void> flush() async {
    for (final entry in pending.entries) {
      if (entry.value.isNotEmpty) {
        await adapter.insertMany(
          InsertManyDescriptor(table: entry.key, rows: entry.value),
        );
      }
      entry.value.clear();
    }
  }

  Future<void> references() async {
    for (final (id, name, email, role) in [
      ('marie', 'Marie Novak', 'marie.novak@gabel.at', 'administrator'),
      ('anna', 'Anna Berger', 'anna.berger@gabel.at', 'kitchen'),
      ('stefan', 'Stefan Moser', 'stefan.moser@gabel.at', 'driver'),
      (
        'katharina',
        'Katharina Ebner',
        'k.ebner@nordlicht-energie.at',
        'approver',
      ),
    ]) {
      await insert('staff_members', {
        'id': 'staff-$id',
        'name': name,
        'email': email,
        'role': role,
      });
    }
    for (final (key, name) in [
      ('nordlicht', 'Nordlicht Energie GmbH'),
      ('kessler', 'Kessler Logistik GmbH'),
      ('donaupark', 'Donaupark Kliniken'),
      ('halden', 'Halden & Co.'),
      ('brandstaetter', 'Brandstätter Architekten ZT'),
      ('mauthner', 'Mauthner & Partner Rechtsanwälte'),
      ('atelier', 'Atelier Fuchs'),
    ]) {
      final data = {
        'id': 'organization-$key',
        'name': name,
        'legal_name': name,
        'billing_email': 'billing@$key.at',
        'billing_address': 'Wiedner Hauptstraße 32, 1040 Wien',
        'approver_id': 'staff-katharina',
      };
      organizations['organization-$key'] = data;
      await insert('organizations', data);
    }
    await insert('menu_plans', {
      'id': 'menu-balanced',
      'name': 'Business lunch — balanced',
      'description': 'Seasonal, freshly cooked lunches for the office.',
    });
    for (final data in [
      {
        'id': FoodioIds.headquarters,
        'name': 'HQ Wieden',
        'organization_id': FoodioIds.nordlicht,
        'street': 'Wiedner Hauptstraße 32',
        'postal_code': '1040',
        'city': 'Wien',
        'handover': 'Reception, 3rd floor',
        'route_code': 'W4',
        'method': 'office',
      },
      {
        'id': FoodioIds.warehouse,
        'name': 'Warehouse Simmering',
        'organization_id': FoodioIds.nordlicht,
        'street': 'Simmeringer Hauptstraße 101',
        'postal_code': '1110',
        'city': 'Wien',
        'handover': 'Canteen fridge, ground floor',
        'route_code': 'S1',
        'method': 'smartFridge',
      },
      {
        'id': 'location-home',
        'name': 'Lena’s home',
        'organization_id': null,
        'street': 'Kaiserstraße 12/5',
        'postal_code': '1070',
        'city': 'Wien',
        'handover': '2nd floor, left',
        'route_code': 'Bike',
        'method': 'home',
        'instructions': 'Ring twice',
      },
      {
        'id': 'location-kitchen',
        'name': 'Gabel kitchen',
        'organization_id': null,
        'street': 'Obere Donaustraße 14',
        'postal_code': '1020',
        'city': 'Wien',
        'handover': 'Front desk',
        'route_code': 'Pickup',
        'method': 'pickup',
      },
    ]) {
      await insert('delivery_locations', data);
    }
    for (final (key, name, company) in [
      ('lena', 'Lena Hofer', 'nordlicht'),
      ('tobias', 'Tobias Wagner', 'kessler'),
      ('sophie', 'Sophie Leitner', ''),
      ('clara', 'Clara Steiner', 'donaupark'),
      ('felix', 'Felix Bauer', ''),
      ('emir', 'Emir Kovačević', 'halden'),
      ('mia', 'Mia Schwarz', 'brandstaetter'),
      ('hannah', 'Hannah Mayr', 'nordlicht'),
      ('lukas', 'Lukas Pichler', ''),
      ('julia', 'Julia Winkler', 'mauthner'),
      ('niklas', 'Niklas Fischer', 'kessler'),
      ('katharina', 'Katharina Ebner', 'nordlicht'),
      ('paul', 'Paul Gruber', ''),
      ('lena-stadler', 'Lena Stadler', ''),
      ('demo', 'Alex Demo', 'kessler'),
    ]) {
      final parts = name.split(' ');
      final customer = {
        'id': 'customer-$key',
        'name': name,
        'first_name': parts.first,
        'last_name': parts.skip(1).join(' '),
        'email': key == 'lena'
            ? 'lena.hofer@nordlicht-energie.at'
            : key == 'lena-stadler'
            ? 'lena.stadler@gmail.com'
            : '$key@${company.isEmpty ? 'example.at' : '$company.at'}',
        'phone': key == 'lena' ? '+43 664 218 4471' : '+43 660 555 0123',
        'allergens': key == 'lena' ? 'H' : '',
        'preferences': key == 'lena'
            ? 'Prefers calls after 14:00 · note by Marie Novak'
            : '',
        'joined_at': DateTime.utc(2024, 3, 12).toIso8601String(),
      };
      customers['customer-$key'] = customer;
      await insert('customers', customer);
      final profileId = key == 'lena' ? FoodioIds.lenaCompany : 'profile-$key';
      final profile = {
        'id': profileId,
        'name': company.isEmpty
            ? 'Private'
            : organizations['organization-$company']!['name'],
        'customer_id': 'customer-$key',
        'organization_id': company.isEmpty ? null : 'organization-$company',
        'location_id': company == 'nordlicht' ? FoodioIds.headquarters : null,
        'menu_plan_id': 'menu-balanced',
        'kind': company.isEmpty ? 'private' : 'company',
        'preferred_delivery_start': company.isEmpty ? '18:00:00' : '11:30:00',
        'preferred_delivery_end': company.isEmpty ? '18:30:00' : '12:00:00',
        'payment_mode': switch (company) {
          '' => key == 'sophie' ? 'paypal' : 'card',
          'donaupark' => 'weeklyInvoice',
          'halden' || 'mauthner' => 'sepa',
          'kessler' || 'brandstaetter' => 'subsidyCard',
          _ => 'monthlyInvoice',
        },
        'is_default': true,
        'monthly_budget_cents': key == 'lena' ? 12000 : 10000000,
        'approval_threshold_cents': key == 'lena' || key == 'hannah'
            ? 4000
            : 10000000,
        'approver_id': 'staff-katharina',
      };
      profiles[profileId] = profile;
      await insert('delivery_profiles', profile);
      for (final period in ['2026-09', '2026-10']) {
        await insert('budget_accounts', {
          'id': key == 'lena' && period == '2026-09'
              ? FoodioIds.budget
              : 'budget-$key-$period',
          'name': '$name — $period',
          'profile_id': profileId,
          'period': period,
          'allowance_cents': key == 'lena' ? 12000 : 10000000,
          'spent_cents': key == 'lena' && period == '2026-09' ? 3200 : 0,
        });
      }
      await insert('payment_methods', {
        'id': 'payment-$key',
        'name': 'Visa •••• 4242',
        'customer_id': 'customer-$key',
        'demo_outcome': key == 'lukas' ? 'declined' : 'succeeded',
      });
    }
    final private = {
      'id': FoodioIds.lenaPrivate,
      'name': 'Private',
      'customer_id': FoodioIds.lena,
      'location_id': 'location-home',
      'menu_plan_id': 'menu-balanced',
      'kind': 'private',
      'preferred_delivery_start': '18:00:00',
      'preferred_delivery_end': '18:30:00',
      'payment_mode': 'card',
      'monthly_budget_cents': 0,
      'approval_threshold_cents': 0,
    };
    profiles[FoodioIds.lenaPrivate] = private;
    await insert('delivery_profiles', private);
    await insert('payment_methods', {
      'id': 'payment-lena-paypal',
      'name': 'PayPal',
      'customer_id': FoodioIds.lena,
      'kind': 'paypal',
      'is_default': false,
    });
    for (final (date, _, capacities) in [
      ('2026-09-28', [42, 86, 118, 104, 62], [60, 120, 120, 120, 100]),
      ('2026-09-29', [0, 42, 108, 66, 22], [0, 100, 120, 100, 83]),
      ('2026-09-30', [0, 49, 49, 49, 49], [60, 120, 120, 120, 100]),
      ('2026-10-01', [0, 36, 36, 35, 35], [60, 120, 120, 120, 100]),
      ('2026-10-02', [0, 22, 22, 22, 22], [60, 120, 120, 120, 100]),
    ]) {
      for (var index = 0; index < 5; index++) {
        final start = [480, 660, 690, 720, 750][index];
        await insert('delivery_slots', {
          'id': FoodioIds.slot(date, start),
          'name':
              '${(start ~/ 60).toString().padLeft(2, '0')}:${(start % 60).toString().padLeft(2, '0')}–${((start + 30) ~/ 60).toString().padLeft(2, '0')}:${((start + 30) % 60).toString().padLeft(2, '0')}',
          'date': date,
          'start_minute': start,
          'end_minute': start + 30,
          'capacity': capacities[index],
          'reserved_orders': 0,
          'active': capacities[index] > 0,
        });
      }
    }
    await insert('delivery_slots', {
      'id': FoodioIds.slot('2026-09-29', 1080),
      'name': '18:00–18:30',
      'date': '2026-09-29',
      'start_minute': 1080,
      'end_minute': 1110,
      'capacity': 50,
      'reserved_orders': 0,
      'method': 'home',
      'route_code': 'Bike',
      'active': true,
    });
    for (final (id, name, category, allergens, diet, rate, variants) in [
      (
        FoodioIds.risotto,
        'Beetroot risotto with goat’s cheese',
        'Mains',
        'G,L,O',
        'vegetarian',
        1000,
        [('Regular', 1190, 380), ('Kids', 840, 250), ('Large', 1440, 520)],
      ),
      (
        FoodioIds.dal,
        'Red lentil dal with basmati rice',
        'Mains',
        'L,M',
        'vegan,mildly spicy',
        1000,
        [('Regular', 1090, 380), ('Large', 1240, 520)],
      ),
      (
        FoodioIds.schnitzel,
        'Pork schnitzel with parsley potatoes',
        'Mains',
        'A,C,G',
        '',
        1000,
        [('Regular', 1390, 380), ('Large', 1640, 520)],
      ),
      (
        FoodioIds.soup,
        'Pumpkin soup with seed oil',
        'Soups',
        'G,L',
        'vegetarian',
        1000,
        [('Cup', 450, 250), ('Bowl', 690, 450)],
      ),
      (
        FoodioIds.strudel,
        'Apple strudel with vanilla sauce',
        'Desserts',
        'A,C,G,H',
        'vegetarian',
        1000,
        [('Standard', 420, 150)],
      ),
      (
        FoodioIds.lemonade,
        'Sparkling elderflower lemonade',
        'Drinks',
        '',
        'vegan',
        2000,
        [('0.33 l', 290, 330)],
      ),
    ]) {
      dishAllergens[id] = allergens;
      await insert('dishes', {
        'id': id,
        'name': name,
        'category': category,
        'allergens': allergens,
        'diet': diet,
        'tax_basis_points': rate,
        'food': category != 'Drinks',
        'image_key': id.replaceFirst('dish-', ''),
      });
      for (var index = 0; index < variants.length; index++) {
        final (variant, price, weight) = variants[index];
        await insert('dish_variants', {
          'id': FoodioIds.variant(id, variant),
          'name': variant,
          'dish_id': id,
          'price_cents': price,
          'weight_grams': weight,
          'is_default': index == 0,
        });
      }
      for (var day = 28; day <= 30 && category != 'Drinks'; day++) {
        await insert('menu_plan_items', {
          'id': 'menu-$id-$day',
          'name': name,
          'menu_plan_id': 'menu-balanced',
          'dish_id': id,
          'date': '2026-09-$day',
          'position': [
            FoodioIds.soup,
            FoodioIds.schnitzel,
            FoodioIds.risotto,
            FoodioIds.dal,
            FoodioIds.strudel,
          ].indexOf(id),
        });
      }
    }
    for (final (id, name, dish, price, allergens) in [
      ('option-cheese', 'Extra goat’s cheese', FoodioIds.risotto, 150, 'G'),
      ('option-walnut', 'Walnut topping', FoodioIds.risotto, 80, 'H'),
      ('option-coriander', 'Extra coriander', FoodioIds.dal, 0, ''),
    ]) {
      await insert('dish_options', {
        'id': id,
        'name': name,
        'dish_id': dish,
        'price_cents': price,
        'allergens': allergens,
      });
    }
    await insert('vouchers', {
      'id': FoodioIds.lunch15,
      'code': 'LUNCH15',
      'description': '15% off food, up to €10',
      'percent_basis_points': 1500,
      'maximum_discount_cents': 1000,
      'food_only': true,
      'valid_from': '2026-09-01',
      'valid_until': '2026-10-31',
    });
    await insert('vouchers', {
      'id': 'voucher-welcome10',
      'code': 'WELCOME10',
      'description': '10% off food, up to €10',
      'percent_basis_points': 1000,
      'maximum_discount_cents': 1000,
      'food_only': true,
    });
    await insert('invoices', {
      'id': FoodioIds.invoice,
      'reference': 'INV-2026-0412',
      'organization_id': FoodioIds.nordlicht,
      'period': '2026-09',
      'status': 'draft',
      'issue_date': '2026-09-30',
      'due_date': '2026-10-14',
      'billing_email': 'billing@nordlicht-energie.at',
      'billing_address': 'Wiedner Hauptstraße 32, 1040 Wien',
    });
    await insert('app_settings', {
      'id': 'next-order-number',
      'key': 'nextOrderNumber',
      'value': '24819',
      'description': 'Next number in the 2026 order series',
    });
    await insert('app_settings', {
      'id': 'brand',
      'key': 'brand',
      'value': 'Gabel',
      'description': 'Food ordering and delivery',
    });
  }

  Future<void> orders() async {
    for (final (
          number,
          customer,
          minute,
          quantity,
          total,
          payment,
          status,
          source,
          time,
          route,
        )
        in [
          (
            24818,
            'tobias',
            720,
            12,
            16480,
            'paid',
            'confirmed',
            'Admin',
            '08:31',
            'S1',
          ),
          (
            24817,
            'lena',
            690,
            4,
            3140,
            'invoiced',
            'inKitchen',
            'Webshop',
            '08:04',
            'W4',
          ),
          (
            24816,
            'sophie',
            660,
            2,
            2380,
            'paid',
            'outForDelivery',
            'App',
            '07:52',
            'Bike',
          ),
          (
            24815,
            'clara',
            660,
            38,
            41260,
            'invoiced',
            'inKitchen',
            'Webshop',
            '07:46',
            'N2',
          ),
          (
            24814,
            'felix',
            720,
            1,
            1340,
            'pending',
            'confirmed',
            'App',
            '07:38',
            'Bike',
          ),
          (
            24813,
            'emir',
            480,
            9,
            11830,
            'invoiced',
            'delivered',
            'Webshop',
            '07:30',
            'C1',
          ),
          (
            24812,
            'mia',
            720,
            4,
            4620,
            'paid',
            'confirmed',
            'Webshop',
            '07:29',
            'W2',
          ),
          (
            24811,
            'hannah',
            690,
            2,
            1980,
            'invoiced',
            'inKitchen',
            'App',
            '07:28',
            'W4',
          ),
          (
            24810,
            'lukas',
            750,
            3,
            3170,
            'failed',
            'confirmed',
            'App',
            '07:27',
            'Bike',
          ),
          (
            24809,
            'julia',
            750,
            6,
            7440,
            'invoiced',
            'confirmed',
            'Webshop',
            '07:26',
            'C1',
          ),
          (
            24808,
            'niklas',
            720,
            1,
            1190,
            'refunded',
            'cancelled',
            'App',
            '07:25',
            'S1',
          ),
          (
            24807,
            'katharina',
            690,
            3,
            2760,
            'invoiced',
            'inKitchen',
            'Webshop',
            '07:24',
            'W4',
          ),
          (
            24806,
            'paul',
            690,
            2,
            2160,
            'paid',
            'onHold',
            'Webshop',
            '07:23',
            'Bike',
          ),
          (
            24805,
            'clara',
            720,
            22,
            24890,
            'invoiced',
            'confirmed',
            'Standing order',
            '07:22',
            'N2',
          ),
          (
            24790,
            'tobias',
            720,
            24,
            29640,
            'paid',
            'confirmed',
            'Webshop',
            '07:21',
            'S1',
          ),
        ]) {
      final issue = switch (number) {
        24814 => ('Waiting for card payment · 42 min', 'sendPaymentLink'),
        24810 => ('Card declined twice', 'retryPayment'),
        24806 => ('Door number missing', 'editAddress'),
        24790 => (
          'Asks for 12:30–13:00 instead of 12:00–12:30',
          'reviewChange',
        ),
        _ => ('', ''),
      };
      await order(
        number: number,
        customer: customer,
        date: '2026-09-28',
        minute: minute,
        total: total,
        quantity: quantity,
        status: status,
        payment: payment,
        source: source,
        time: time,
        route: route,
        issue: issue.$1,
        next: issue.$2,
      );
    }
    await order(
      number: 24795,
      customer: 'hannah',
      date: '2026-09-28',
      minute: 690,
      total: 4680,
      quantity: 4,
      status: 'confirmed',
      payment: 'invoiced',
      approval: 'pending',
      issue: '€46.80 is over the €40 approval rule',
      next: 'requestApproval',
    );
    var offset = 0;
    final slots = [
      for (final (minute, count) in [
        (480, 41),
        (660, 84),
        (690, 113),
        (720, 98),
        (750, 60),
      ])
        for (var i = 0; i < count; i++) minute,
    ];
    for (var i = 0; i < 396; i++) {
      final status = i < 79
          ? 'confirmed'
          : i < 206
          ? 'inKitchen'
          : i < 269
          ? 'outForDelivery'
          : 'delivered';
      final basket = i < 357
          ? 0
          : i == 357
          ? 1
          : i < 390
          ? 2
          : 3;
      final total = [2060, 2210, 2280, 2380][basket];
      await order(
        number: 24000 - i,
        customer: 'demo',
        date: '2026-09-28',
        minute: slots[i],
        total: total,
        quantity: basket < 2 ? 3 : 2,
        status: status,
        payment: 'invoiced',
        basket: basket,
      );
    }
    for (final (date, counts) in [
      ('2026-09-29', [42, 108, 66, 22]),
      ('2026-09-30', [49, 49, 49, 49]),
      ('2026-10-01', [36, 36, 35, 35]),
      ('2026-10-02', [22, 22, 22, 22]),
    ]) {
      for (var slot = 0; slot < 4; slot++) {
        for (var i = 0; i < counts[slot]; i++) {
          final allergy = offset == 0;
          await order(
            number: allergy ? 24799 : 20000 - offset,
            customer: allergy || date == '2026-09-29' && slot == 1 && i < 47
                ? 'clara'
                : 'demo',
            date: date,
            minute: [660, 690, 720, 750][slot],
            total: 1190,
            quantity: 1,
            status: 'confirmed',
            payment: 'invoiced',
            issue: allergy
                ? 'Allergy note: one portion strictly without nuts'
                : '',
            next: allergy ? 'acknowledgeAllergy' : '',
            awaitingRelease: offset < 96,
            strictAllergy: allergy,
          );
          offset++;
        }
      }
    }
    await order(
      number: 24802,
      customer: 'felix',
      date: '2026-09-28',
      minute: null,
      total: 1340,
      quantity: 1,
      status: 'onHold',
      payment: 'paid',
      issue: 'Nobody at reception on Fri 25 Sep',
      next: 'reschedule',
    );
    for (final (date, count) in [
      ('2026-09-21', 391),
      ('2026-09-22', 414),
      ('2026-09-23', 408),
      ('2026-09-24', 436),
      ('2026-09-25', 362),
    ]) {
      for (var i = 0; i < count; i++) {
        await order(
          number: 18000 - offset++,
          customer: 'demo',
          date: date,
          minute: null,
          total: 1190,
          quantity: 1,
          status: 'delivered',
          payment: 'paid',
        );
      }
    }
    // 147 historic Lena records plus the visible current order = exactly 148.
    // Her previous September spend is a €32 settled ledger entry, independent of older orders.
    for (var i = 0; i < 45122; i++) {
      await order(
        number: i + 1,
        customer: i < 147 ? 'lena' : 'demo',
        date: '2025-06-16',
        minute: null,
        total: 1190,
        quantity: 1,
        status: 'delivered',
        payment: 'paid',
        series: '2025',
      );
    }
    for (var i = 0; i < 3; i++) {
      await order(
        number: -(i + 1),
        customer: 'demo',
        date: null,
        minute: null,
        total: 0,
        quantity: 0,
        status: 'draft',
        payment: 'unpaid',
      );
    }
    await flush();
    for (final entry in slotUse.entries) {
      await adapter.update(
        UpdateDescriptor(
          table: 'delivery_slots',
          values: {'reserved_orders': entry.value},
          where: const Field<String>('id').eq(entry.key),
        ),
      );
    }
    for (final entry in budgetUse.entries) {
      await adapter.update(
        UpdateDescriptor(
          table: 'budget_accounts',
          values: {'reserved_cents': entry.value},
          where: const Field<String>('id').eq(entry.key),
        ),
      );
    }
    final rows = await adapter.select(
      QueryDescriptor(
        table: 'orders',
        where: const Field<String>('invoice_id').eq(FoodioIds.invoice),
      ),
    );
    await adapter.update(
      UpdateDescriptor(
        table: 'invoices',
        values: {
          'gross_cents': rows.fold<int>(
            0,
            (sum, row) => sum + (row['gross_cents']! as int),
          ),
          'net_cents': rows.fold<int>(
            0,
            (sum, row) => sum + (row['net_cents']! as int),
          ),
          'tax_cents': rows.fold<int>(
            0,
            (sum, row) => sum + (row['tax_cents']! as int),
          ),
        },
        where: const Field<String>('id').eq(FoodioIds.invoice),
      ),
    );
  }

  Future<void> order({
    required int number,
    required String customer,
    required String? date,
    required int? minute,
    required int total,
    required int quantity,
    required String status,
    required String payment,
    String source = 'Webshop',
    String time = '07:00',
    String route = 'W4',
    String issue = '',
    String next = '',
    String approval = 'notRequired',
    String series = '2026',
    int? basket,
    bool awaitingRelease = false,
    bool strictAllergy = false,
  }) async {
    final id = series == '2025' ? 'historic-$number' : FoodioIds.order(number);
    final profileId = customer == 'lena'
        ? FoodioIds.lenaCompany
        : 'profile-$customer';
    final profile = profiles[profileId]!;
    final person = customers['customer-$customer']!;
    final company = organizations[profile['organization_id']];
    final slot = date == null || minute == null
        ? null
        : FoodioIds.slot(date, minute);
    final reserved = status != 'draft' && slot != null;
    if (reserved) slotUse.update(slot, (v) => v + 1, ifAbsent: () => 1);
    final budgetId =
        company == null ||
            date == null ||
            date.startsWith('2025') ||
            status == 'cancelled' ||
            status == 'draft' ||
            minute == null
        ? null
        : customer == 'lena' && date.startsWith('2026-09')
        ? FoodioIds.budget
        : 'budget-$customer-${date.substring(0, 7)}';
    if (budgetId != null) {
      budgetUse.update(budgetId, (v) => v + total, ifAbsent: () => total);
    }
    final lineData = <Map<String, Object?>>[];
    void line(
      String label,
      int amount, {
      int qty = 1,
      String? dish,
      String? variant,
      int rate = 1000,
      bool food = true,
      int extra = 0,
    }) {
      lineData.add({
        'id': '$id-line-${lineData.length}',
        'order_id': id,
        'label': label,
        'quantity': qty,
        'position': lineData.length,
        'dish_id': dish,
        'allergens': dishAllergens[dish] ?? '',
        'variant_id': variant,
        'unit_price_cents': amount,
        'options_price_cents': extra,
        'tax_basis_points': rate,
        'food': food,
        'variant_name': variant?.split('-').last ?? 'Standard',
      });
    }

    if (number == 24817 && series == '2026') {
      line(
        'Beetroot risotto with goat’s cheese',
        1190,
        dish: FoodioIds.risotto,
        variant: FoodioIds.variant(FoodioIds.risotto, 'Regular'),
      );
      line(
        'Red lentil dal with basmati rice',
        1240,
        dish: FoodioIds.dal,
        variant: FoodioIds.variant(FoodioIds.dal, 'Large'),
      );
      line(
        'Apple strudel with vanilla sauce',
        420,
        dish: FoodioIds.strudel,
        variant: FoodioIds.variant(FoodioIds.strudel, 'Standard'),
      );
      line(
        'Sparkling elderflower lemonade',
        290,
        dish: FoodioIds.lemonade,
        variant: FoodioIds.variant(FoodioIds.lemonade, '0.33 l'),
        rate: 2000,
        food: false,
      );
    } else if (basket != null) {
      line(
        'Beetroot risotto with goat’s cheese',
        1190,
        qty: basket == 3 ? 2 : 1,
        dish: FoodioIds.risotto,
        variant: FoodioIds.variant(FoodioIds.risotto, 'Regular'),
        extra: basket == 1 ? 150 : 0,
      );
      if (basket < 2) {
        line(
          'Pumpkin soup with seed oil',
          450,
          dish: FoodioIds.soup,
          variant: FoodioIds.variant(FoodioIds.soup, 'Cup'),
        );
        line(
          'Apple strudel with vanilla sauce',
          420,
          dish: FoodioIds.strudel,
          variant: FoodioIds.variant(FoodioIds.strudel, 'Standard'),
        );
      }
      if (basket == 2) {
        line(
          'Red lentil dal with basmati rice',
          1090,
          dish: FoodioIds.dal,
          variant: FoodioIds.variant(FoodioIds.dal, 'Regular'),
        );
      }
    } else if (quantity > 0) {
      // Historic negotiated catering prices are real custom lines, not fake catalog quantities.
      final unit = total ~/ quantity;
      final remainder = total % quantity;
      if (quantity - remainder > 0) {
        line(
          total == 1190 ? 'Business lunch' : 'Catering lunch',
          unit,
          qty: quantity - remainder,
        );
      }
      if (remainder > 0) {
        line('Catering lunch · negotiated portion', unit + 1, qty: remainder);
      }
    }
    final totals = FoodioTotals.calculate([
      for (final line in lineData)
        FoodioMoneyLine(
          key: line['id']! as String,
          grossCents:
              ((line['unit_price_cents']! as int) +
                  (line['options_price_cents']! as int)) *
              (line['quantity']! as int),
          taxBasisPoints: line['tax_basis_points']! as int,
          food: line['food']! as bool,
        ),
    ]);
    if (totals.grossCents != total) throw StateError('Unbalanced seed $id');
    final placedDate = series == '2025'
        ? '2025-06-15'
        : switch (number) {
            24813 || 24812 || 24811 => '2026-09-27',
            24810 => '2026-09-26',
            24809 || 24808 || 24807 || 24806 || 24805 => '2026-09-25',
            24802 || 24799 || 24795 || 24790 => '2026-09-24',
            _ => '2026-09-28',
          };
    final placed = date == null
        ? null
        : DateTime.parse(
            '${placedDate}T$time:00+02:00',
          ).toUtc().toIso8601String();
    await add('orders', {
      'id': id,
      'reference': number < 0
          ? 'Draft ${-number}'
          : series == '2025'
          ? 'ORD-2025-$number'
          : 'ORD-$number',
      'number': number < 0 ? 0 : number,
      'series': series,
      'status': status,
      'payment_status': payment,
      'approval_status': approval,
      'attention_reason': issue,
      'next_action': next,
      'needs_attention': next.isNotEmpty,
      'awaiting_release': awaitingRelease,
      'source': source,
      'created_by': source == 'Admin' ? 'Marie Novak' : 'Customer',
      'placed_at': placed,
      'kitchen_started_at':
          {
            'inKitchen',
            'outForDelivery',
            'delivered',
            'cancelled',
          }.contains(status)
          ? '${date ?? '2026-09-28'}T06:12:00.000Z'
          : null,
      'dispatched_at': {'outForDelivery', 'delivered'}.contains(status)
          ? '${date ?? '2026-09-28'}T07:10:00.000Z'
          : null,
      'delivered_at': status == 'delivered'
          ? '${date ?? '2026-09-28'}T07:30:00.000Z'
          : null,
      'customer_id': 'customer-$customer',
      'profile_id': profileId,
      'organization_id': profile['organization_id'],
      'location_id': customer == 'lena' ? FoodioIds.headquarters : null,
      'slot_id': slot,
      'delivery_date': date,
      'route_code': route,
      'driver_name': 'Stefan Moser',
      'delivery_method': company == null ? 'home' : 'office',
      'street': number == 24806
          ? ''
          : customer == 'lena'
          ? 'Wiedner Hauptstraße 32'
          : 'Opernring 1',
      'postal_code': '1040',
      'city': 'Wien',
      'handover': customer == 'lena' ? 'Reception, 3rd floor' : 'Reception',
      'contact_phone': person['phone'],
      'customer_name': person['name'],
      'customer_email': person['email'],
      'organization_name': company?['name'] ?? '',
      'profile_name': profile['name'],
      'cost_center': company == null ? '' : '4100 Marketing',
      'payment_mode': profile['payment_mode'],
      'payment_method_id': 'payment-$customer',
      'invoice_id':
          profile['organization_id'] == FoodioIds.nordlicht &&
              date != null &&
              date.startsWith('2026-09')
          ? FoodioIds.invoice
          : null,
      'budget_account_id': budgetId,
      'budget_reserved': budgetId != null,
      'budget_amount_cents': budgetId == null ? 0 : total,
      'capacity_reserved': reserved,
      'subtotal_cents': total,
      'gross_cents': total,
      'net_cents': totals.netCents,
      'tax_cents': totals.taxCents,
      'food_tax_cents': totals.taxByRate[1000] ?? 0,
      'drink_tax_cents': totals.taxByRate[2000] ?? 0,
      'item_count': quantity,
      'strict_allergy': strictAllergy,
      'allergen_note': strictAllergy
          ? 'One portion strictly nut-free'
          : number == 24817
          ? 'H — tree nuts'
          : '',
      'customer_note': number == 24817
          ? "Please label the strudel – it's for a colleague."
          : '',
      'client_info': number == 24817
          ? 'Chrome on Windows · office network · webshop-checkout 4.2'
          : '',
    });
    // Flush parents before child batches to respect FK enforcement on SQLite.
    if (pending['orders']!.length >= 190) await flush();
    for (var i = 0; i < lineData.length; i++) {
      final value = totals.lines[i];
      await add('order_items', {
        ...lineData[i],
        'gross_cents': value.grossCents,
        'net_cents': value.netCents,
        'tax_cents': value.taxCents,
      });
    }
    if (number == 24817 && series == '2026') {
      await add('order_item_options', {
        'id': '$id-coriander',
        'label': 'Extra coriander',
        'order_item_id': '$id-line-1',
        'option_id': 'option-coriander',
      });
    }
    if (basket == 1) {
      await add('order_item_options', {
        'id': '$id-cheese',
        'label': 'Extra goat’s cheese',
        'order_item_id': '$id-line-0',
        'option_id': 'option-cheese',
        'unit_price_cents': 150,
        'allergens': 'G',
      });
    }
  }

  Future<void> activity() async {
    final order = FoodioIds.order(24817);
    for (final (minute, title, actor, kind) in [
      ('08:04', 'Order placed', 'Lena Hofer', 'place'),
      ('08:05', 'Order automatically confirmed', 'Automatic', 'confirmed'),
      ('08:05', 'Confirmation email sent', 'Automatic', 'email'),
      ('08:12', 'Moved to in kitchen', 'Anna Berger', 'startKitchen'),
      ('08:14', 'Allergen M added to dal', 'Anna Berger', 'allergen'),
      ('08:15', 'Internal note added', 'Anna Berger', 'note'),
    ]) {
      await insert('order_activities', {
        'id': 'activity-$minute-$kind',
        'order_id': order,
        'title': title,
        'actor': actor,
        'kind': kind,
        'save_key': 'seed-$kind',
        'occurred_at': DateTime.parse(
          '2026-09-28T$minute:00+02:00',
        ).toUtc().toIso8601String(),
      });
    }
    await insert('order_notes', {
      'id': 'note-anna',
      'order_id': order,
      'body':
          '@Marie Novak dal is made with mustard seeds this week, allergen M added.',
      'author': 'Anna Berger',
      'author_role': 'Head chef',
      'visibility': 'internal',
      'occurred_at': '2026-09-28T06:15:00.000Z',
    });
    for (var i = 0; i < 5; i++) {
      await insert('notifications', {
        'id': 'notification-$i',
        'title': [
          '7 orders need attention',
          'Kitchen started preparation',
          'Invoice draft is ready',
          'Approval requested',
          'New customer joined',
        ][i],
        'body': 'Review the relevant record in Gabel.',
        'order_id': i == 1 ? order : null,
        'occurred_at': stamp,
      });
    }
    for (var i = 0; i < 2; i++) {
      await insert('complaints', {
        'id': 'complaint-$i',
        'reference': 'CMP-2026-${i + 1}',
        'order_id': FoodioIds.order(i == 0 ? 24802 : 24806),
        'subject': i == 0 ? 'Missed delivery' : 'Delivery address follow-up',
      });
    }
  }
}
