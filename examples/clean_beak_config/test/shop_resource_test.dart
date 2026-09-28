import 'package:beak/panel.dart';
import 'package:beak/testing.dart';
import 'package:clean_beak_config/beak/registry.g.dart';
import 'package:clean_beak_config/resources/products/models/product.dart';
import 'package:clean_beak_config/resources/products/models/product_attribute.dart';
import 'package:clean_beak_config/resources/products/models/product_variant.dart';
import 'package:clean_beak_config/resources/products/models/variant_attribute.dart';
import 'package:clean_beak_config/resources/products/product_resource.dart';
import 'package:clean_beak_config/resources/users/user_resource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'product duplication preserves catalog values and resets selling identities',
    () async {
      final registry = buildBeakRegistry();
      final original = BeakRecord.fromRow({
        'id': 'coffee',
        'name': 'Coffee',
        'sku': 'COFFEE',
        'price': 12.5,
        'active': true,
        'category_id': 'beans',
        'tax_rate_id': 'standard',
      });
      final memory = InMemoryBeakDataSource(registry: registry)
        ..seed(const ProductModel(), [original])
        ..seed(const ProductAttributeModel(), [
          BeakRecord.fromRow({
            'id': 'origin',
            'product_id': 'coffee',
            'name': 'Origin',
            'value': 'Colombia',
            'definition_id': 'country',
          }),
        ])
        ..seed(const ProductVariantModel(), [
          BeakRecord.fromRow({
            'id': 'large',
            'product_id': 'coffee',
            'name': '1 kg',
            'sku': 'COFFEE-1KG',
            'price': 35.0,
            'stock': 27,
            'active': true,
          }),
        ])
        ..seed(const VariantAttributeModel(), [
          BeakRecord.fromRow({
            'id': 'size',
            'variant_id': 'large',
            'name': 'Size',
            'value': '1 kg',
          }),
        ]);
      final source = BeakRecordingDataSource(memory);
      final resource = ProductResource();
      final copy =
          await BeakRecordDuplicator(
            source: source,
            registry: registry,
          ).duplicate(
            resource.model,
            original,
            saveId: 'copy-coffee',
            spec: resource.duplication!,
          );
      expect(ProductModel.id.readFrom(copy.record), isNull);
      expect(ProductModel.sku.readFrom(copy.record), isNull);
      expect(ProductModel.price.readFrom(copy.record), 12.5);
      expect(ProductModel.categoryId.readFrom(copy.record), 'beans');
      expect(ProductModel.taxRateId.readFrom(copy.record), 'standard');
      final attribute = copy.record.relations['attributes']!.single;
      expect(ProductAttributeModel.value.readFrom(attribute), 'Colombia');
      expect(ProductAttributeModel.definitionId.readFrom(attribute), 'country');
      final variant = copy.record.relations['variants']!.single;
      expect(ProductVariantModel.sku.readFrom(variant), isNull);
      expect(ProductVariantModel.stock.readFrom(variant), isNull);
      expect(ProductVariantModel.price.readFrom(variant), 35);
      expect(
        VariantAttributeModel.value.readFrom(
          variant.relations['attributes']!.single,
        ),
        '1 kg',
      );
      expect(copy.plan.operations, hasLength(4));
      expect(
        copy.plan.operations.every(
          (operation) => operation.kind == BeakSaveOperationKind.create,
        ),
        isTrue,
      );
      expect(source.createCalls, isEmpty);
      expect(source.updateCalls, isEmpty);
      expect(
        (await memory.getOne('product_variants', 'large'))?['stock']?.raw,
        27,
      );
    },
  );

  test(
    'catalog and customer forms share a structured read/create/edit layout',
    () {
      for (final resource in [ProductResource(), UserResource()]) {
        final read = resource.screenFor(BeakScreenRole.read);
        expect(read, isA<BeakFormScreen>());
        expect(resource.screenFor(BeakScreenRole.edit), same(read));
        expect(resource.screenFor(BeakScreenRole.create), same(read));
        expect(resource.effectiveFilters, isNotEmpty);
        expect(resource.globalSearchSources, isNotEmpty);
      }
    },
  );
}
