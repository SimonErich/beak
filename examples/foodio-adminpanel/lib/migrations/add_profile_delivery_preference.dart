import 'package:beak/migrations.dart';

import '../models/delivery_slot.dart';
import '../seeders/foodio_seeder.dart';

/// Adds recurring delivery preferences without pointing to a dated slot.
final class AddProfileDeliveryPreference extends Migration {
  /// Preserves existing profiles and operator data.
  const AddProfileDeliveryPreference();

  @override
  String get name => '20260928_140000_add_profile_delivery_preference';

  @override
  Future<void> up(DatabaseAdapter adapter) async {
    final columns = (await adapter.introspectSchema())['delivery_profiles']!;
    final missing = [
      'preferred_delivery_start',
      'preferred_delivery_end',
    ].where((key) => !columns.contains(key));
    for (final key in missing) {
      await adapter.executeSchema(
        SchemaDescriptor.alterTable(
          table: 'delivery_profiles',
          alterations: [
            SchemaAddColumn(
              SchemaColumn(name: key, type: ColumnType.string, nullable: true),
            ),
          ],
        ),
      );
    }
    // Upgrade only the known demo identities. Other profiles keep nullable
    // preferences, and an operator's existing preference is never replaced.
    for (final (id, start, end) in [
      (FoodioIds.lenaCompany, '11:30:00', '12:00:00'),
      (FoodioIds.lenaPrivate, '18:00:00', '18:30:00'),
    ]) {
      for (final (key, value) in [
        ('preferred_delivery_start', start),
        ('preferred_delivery_end', end),
      ]) {
        await adapter.update(
          UpdateDescriptor(
            table: 'delivery_profiles',
            values: {key: value},
            where: const Field<String>(
              'id',
            ).eq(id).and(Field<String>(key).isNull()),
          ),
        );
      }
    }
    final private = await adapter.selectOne(
      QueryDescriptor(
        table: 'delivery_profiles',
        where: const Field<String>('id').eq(FoodioIds.lenaPrivate),
      ),
    );
    final homeId = FoodioIds.slot('2026-09-29', 1080);
    if (private != null &&
        await adapter.selectOne(
              QueryDescriptor(
                table: 'delivery_slots',
                where: const Field<String>('id').eq(homeId),
              ),
            ) ==
            null) {
      final defaults = const BeakValidation().applyDefaults(
        const DeliverySlotModel(),
        BeakRecord.fromRow({
          'id': homeId,
          'name': '18:00–18:30',
          'date': '2026-09-29',
          'start_minute': 1080,
          'end_minute': 1110,
          'capacity': 50,
          'reserved_orders': 0,
          'method': 'home',
          'route_code': 'Bike',
          'active': true,
        }),
      );
      await adapter.insert(
        InsertDescriptor(
          table: 'delivery_slots',
          values: {
            'created_at': '2026-09-28T07:42:00.000Z',
            'updated_at': '2026-09-28T07:42:00.000Z',
            ...defaults.values.map((key, value) => MapEntry(key, value.raw)),
          },
        ),
      );
    }
  }

  @override
  Future<void> down(DatabaseAdapter adapter) async {
    final columns = (await adapter.introspectSchema())['delivery_profiles']!;
    for (final key in ['preferred_delivery_start', 'preferred_delivery_end']) {
      if (columns.contains(key)) {
        await adapter.executeSchema(
          SchemaDescriptor.alterTable(
            table: 'delivery_profiles',
            alterations: [SchemaDropColumn(key)],
          ),
        );
      }
    }
  }
}
