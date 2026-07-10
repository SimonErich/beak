import 'package:beak_core/beak_core.dart';
import 'package:beak_superdashboard/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('demo model catalog', () {
    test('registers 49 models across every domain', () {
      expect(demoModels, hasLength(49));
      expect(buildDemoRegistry().all, hasLength(49));
    });

    test('every table name is unique', () {
      final tables = demoModels.map((model) => model.table).toList();
      expect(tables.toSet(), hasLength(tables.length));
    });

    test('the identity spine and app domains are present', () {
      final tables = {for (final model in demoModels) model.table};
      expect(
        tables,
        containsAll(<String>[
          'users',
          'products',
          'orders',
          'transactions',
          'time_series_points',
          'purchase_sources',
          'country_stats',
          'emails',
          'conversations',
          'calendar_events',
          'files',
          'invoices',
          'cards',
          'pricing_plans',
          'faqs',
        ]),
      );
    });
  });

  group('per-model integrity', () {
    test('every model exposes its display column', () {
      for (final model in demoModels) {
        final keys = {for (final column in model.columns) column.key};
        expect(
          keys,
          contains(model.displayColumnKey),
          reason:
              '${model.table} is missing its display column '
              '"${model.displayColumnKey}"',
        );
      }
    });

    test('every model carries a shared id column', () {
      for (final model in demoModels) {
        final keys = {for (final column in model.columns) column.key};
        expect(keys, contains('id'), reason: '${model.table} has no id');
      }
    });

    test('every relation targets a registered table', () {
      final tables = {for (final model in demoModels) model.table};
      for (final model in demoModels) {
        for (final relation in model.relationships) {
          expect(
            tables,
            contains(relation.relatedTable),
            reason:
                '${model.table}.${relation.key} targets unknown table '
                '"${relation.relatedTable}"',
          );
        }
      }
    });

    test('every belongs-to foreign key is a column on its owning model', () {
      for (final model in demoModels) {
        final keys = {for (final column in model.columns) column.key};
        for (final relation in model.relationships) {
          if (relation is BeakBelongsTo) {
            expect(
              keys,
              contains(relation.foreignKey),
              reason:
                  '${model.table}.${relation.key} needs FK column '
                  '"${relation.foreignKey}"',
            );
          }
        }
      }
    });

    test('self-referential relations point back at their own table', () {
      // Each entry: the model table -> its self-referential relation keys.
      const selfRefs = <String, List<String>>{
        'activities': ['parent', 'replies'],
        'file_folders': ['parent', 'children'],
      };
      for (final entry in selfRefs.entries) {
        final model = demoModels.firstWhere((m) => m.table == entry.key);
        final byKey = {for (final r in model.relationships) r.key: r};
        for (final key in entry.value) {
          expect(byKey, contains(key), reason: '${entry.key} lacks "$key"');
          expect(byKey[key]!.relatedTable, model.table);
        }
      }
    });
  });
}
