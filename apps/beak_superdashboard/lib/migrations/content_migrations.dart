import 'package:beak_superdashboard/models/models.dart';
import 'package:worm/worm.dart';

import 'model_schema.dart';

/// Creates the Pricing, FAQ, and showcase-content domains — small,
/// leaf-only tables.
final class CreateContentTables extends Migration {
  /// Creates the migration.
  const CreateContentTables();

  @override
  String get name => '20260707_001000_create_content_tables';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create(
      'pricing_plans',
      (table) => defineModelColumns(table, const PricingPlanModel()),
    );
    await schema.create('plan_features', (table) {
      defineModelColumns(table, const PlanFeatureModel());
      table.foreign(
        column: 'plan_id',
        references: 'id',
        onTable: 'pricing_plans',
        onDelete: OnDelete.cascade,
      );
    });
    await schema.create(
      'faq_categories',
      (table) => defineModelColumns(table, const FaqCategoryModel()),
    );
    await schema.create('faqs', (table) {
      defineModelColumns(table, const FaqModel());
      table.foreign(
        column: 'category_id',
        references: 'id',
        onTable: 'faq_categories',
        onDelete: OnDelete.cascade,
      );
    });
    await schema.create(
      'media_assets',
      (table) => defineModelColumns(table, const MediaAssetModel()),
    );
    await schema.create(
      'notifications',
      (table) => defineModelColumns(table, const NotificationModel()),
    );
  }

  @override
  Future<void> downSchema(Schema schema) async {
    for (final table in const [
      'notifications',
      'media_assets',
      'faqs',
      'faq_categories',
      'plan_features',
      'pricing_plans',
    ]) {
      await schema.drop(table, ifExists: true);
    }
  }
}
