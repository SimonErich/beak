import 'package:beak/migrations.dart';
import 'package:foodio_adminpanel/migrations/add_profile_delivery_preference.dart';
import 'package:foodio_adminpanel/migrations/create_delivery_slots_table.dart';
import 'package:foodio_adminpanel/seeders/foodio_seeder.dart';
import 'package:test/test.dart';

void main() {
  for (final fresh in [false, true]) {
    test(
      'recurring preferences preserve ${fresh ? 'current' : 'legacy'} profiles and repeated upgrades',
      () async {
        final adapter = adapterFromUrl(Uri.parse('sqlite::memory:'));
        await adapter.connect();
        addTearDown(adapter.disconnect);
        await adapter.executeSchema(
          SchemaDescriptor.createTable(
            table: 'delivery_profiles',
            columns: [
              const SchemaColumn(name: 'id', type: ColumnType.string),
              const SchemaColumn(name: 'name', type: ColumnType.string),
              if (fresh) ...[
                const SchemaColumn(
                  name: 'preferred_delivery_start',
                  type: ColumnType.string,
                  nullable: true,
                ),
                const SchemaColumn(
                  name: 'preferred_delivery_end',
                  type: ColumnType.string,
                  nullable: true,
                ),
              ],
            ],
          ),
        );
        await MigrationRunner(
          adapter: adapter,
          migrations: const [CreateDeliverySlotsTable()],
        ).migrate();
        for (final id in [
          FoodioIds.lenaCompany,
          FoodioIds.lenaPrivate,
          'operator-profile',
        ]) {
          await adapter.insert(
            InsertDescriptor(
              table: 'delivery_profiles',
              values: {
                'id': id,
                'name': id,
                if (fresh && id == FoodioIds.lenaCompany) ...{
                  'preferred_delivery_start': '12:00:00',
                  'preferred_delivery_end': '12:30:00',
                },
              },
            ),
          );
        }
        const migration = AddProfileDeliveryPreference();
        await migration.up(adapter);
        await migration.up(adapter);
        Future<Map<String, Object?>?> row(String id) => adapter.selectOne(
          QueryDescriptor(
            table: 'delivery_profiles',
            where: const Field<String>('id').eq(id),
          ),
        );
        expect(
          (await row(FoodioIds.lenaCompany))!['preferred_delivery_start'],
          fresh ? '12:00:00' : '11:30:00',
        );
        expect(
          (await row(FoodioIds.lenaCompany))!['preferred_delivery_end'],
          fresh ? '12:30:00' : '12:00:00',
        );
        expect(
          (await row(FoodioIds.lenaPrivate))!['preferred_delivery_start'],
          '18:00:00',
        );
        expect(
          (await row('operator-profile'))!['preferred_delivery_start'],
          isNull,
        );
        final slots = await adapter.select(
          const QueryDescriptor(table: 'delivery_slots'),
        );
        expect(slots, hasLength(1));
        expect(slots.single['date'], '2026-09-29');
        expect(slots.single['method'], 'home');
        expect(slots.single['start_minute'], 1080);
        await migration.down(adapter);
        await migration.down(adapter);
        expect(
          (await row(FoodioIds.lenaCompany))!['name'],
          FoodioIds.lenaCompany,
        );
        expect(
          (await adapter.select(
            const QueryDescriptor(table: 'delivery_slots'),
          )),
          hasLength(1),
          reason: 'A dated slot may already be referenced by an order',
        );
      },
    );
  }
}
