import 'package:beak_core/beak_core.dart';
import 'package:reference_admin_models/reference_admin_models.dart';
import 'package:test/test.dart';

void main() {
  group('registry', () {
    test('registers every reference model under its table', () {
      final registry = buildReferenceRegistry();

      expect(registry.all, hasLength(referenceModels.length));
      for (final model in referenceModels) {
        expect(registry.byTableOrThrow(model.table), same(model));
      }
    });

    test('every model resolves its primary key and display column', () {
      for (final model in referenceModels) {
        expect(model.primaryKey.key, 'id', reason: model.table);
        expect(
          model.columnByKey(model.displayColumnKey),
          isNotNull,
          reason: model.table,
        );
      }
    });

    test('every relationship points at a registered table', () {
      final registry = buildReferenceRegistry();
      for (final model in referenceModels) {
        for (final relationship in model.relationships) {
          expect(
            registry.byTable(relationship.relatedTable),
            isNotNull,
            reason: '${model.table}.${relationship.key}',
          );
        }
      }
    });

    test('every belongs-to foreign key is a declared column', () {
      for (final model in referenceModels) {
        for (final relationship in model.relationships) {
          if (relationship case BeakBelongsTo(:final foreignKey)) {
            expect(
              model.columnByKey(foreignKey),
              isNotNull,
              reason: '${model.table}.${relationship.key}',
            );
          }
        }
      }
    });
  });

  group('products', () {
    test('carry the showcase upload rules and transform pipeline', () {
      expect(ProductColumns.image.storagePath, 'products');
      expect(ProductColumns.image.maxSizeInBytes, 5 * 1024 * 1024);
      expect(ProductColumns.image.allowedTypes, [
        BeakFileType.jpeg,
        BeakFileType.png,
        BeakFileType.webp,
      ]);
      expect(ProductColumns.image.transforms, const [
        BeakThumbnailTransform(
          size: BeakDimensions(widthInPixels: 160, heightInPixels: 160),
        ),
        BeakFormatTransform.webp(),
      ]);
    });

    test('soft-delete and badge colors are wired', () {
      expect(const ProductModel().softDeletes, isTrue);
      expect(
        ProductColumns.status.badgeColorFor(ProductStatus.published),
        BeakColor.success,
      );
      expect(ProductColumns.status.defaultValue, ProductStatus.draft);
    });

    test('timestamps stay off the form so the backend stamps them', () {
      expect(
        ProductColumns.createdAt.visibleOn.contains(BeakContext.form),
        isFalse,
      );
      expect(
        ProductColumns.updatedAt.visibleOn.contains(BeakContext.form),
        isFalse,
      );
    });
  });

  group('orders', () {
    test('link customers and line items', () {
      expect(OrderRelations.user.searchColumnKeys, ['name', 'email']);
      expect(OrderRelations.items.foreignKey, 'order_id');
      expect(OrderItemRelations.product.relatedTable, 'products');
    });
  });
}
