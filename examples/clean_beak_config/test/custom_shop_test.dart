import 'package:beak/panel.dart';
import 'package:beak/testing.dart';
import 'package:beak/ui.dart';
import 'package:clean_beak_config/beak/registry.g.dart';
import 'package:clean_beak_config/operations.dart';
import 'package:clean_beak_config/resources/invoices/invoice_resource.dart';
import 'package:clean_beak_config/resources/invoices/models/invoice.dart';
import 'package:clean_beak_config/resources/orders/order_resource.dart';
import 'package:clean_beak_config/resources/products/models/product.dart';
import 'package:clean_beak_config/resources/products/models/product_variant.dart';
import 'package:clean_beak_config/resources/products/models/variant_attribute.dart';
import 'package:clean_beak_config/resources/products/screens/product_form.dart';
import 'package:clean_beak_config/resources/products/screens/variant_builder.dart';
import 'package:clean_beak_config/resources/products/variant_resource.dart';
import 'package:clean_beak_config/widgets/receivables_card.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/money.dart';

void main() {
  test(
    'variant preview stages only selected missing combinations with nested attributes',
    () async {
      // --8<-- [start:draftWithoutUi]
      final registry = buildBeakRegistry();
      final source = BeakRecordingDataSource(
        InMemoryBeakDataSource(registry: registry),
      );
      final session = BeakFormSession(
        model: const ProductModel(),
        registry: registry,
        dataSource: source,
        layout: productForm(),
      );
      addTearDown(session.dispose);
      session.root.set(ProductModel.name, 'Coffee');
      session.root.set(ProductModel.sku, 'COFFEE');
      session.root.set(ProductModel.price, eur('12.50'));
      // --8<-- [end:draftWithoutUi]
      final combinations = BeakVariantMatrix([
        BeakVariantAxis(key: 'Size', label: 'Size', values: ['250 g', '1 kg']),
        BeakVariantAxis(
          key: 'Grind',
          label: 'Grind',
          values: ['Whole', 'Ground'],
        ),
      ]).preview();
      expect(combinations, hasLength(4));
      expect(stageShopVariants(session.root, combinations.take(2)), 2);
      final rows = session.root.rows(ProductModel.variants);
      expect(rows.map((row) => row.read(ProductVariantModel.sku)), [
        'COFFEE-001',
        'COFFEE-002',
      ]);
      expect(rows.first.read(ProductVariantModel.price), eur('12.50'));
      expect(rows.first.read(ProductVariantModel.stock), 0);
      expect(
        rows.first
            .rows(ProductVariantModel.attributes)
            .map((row) => row.read(VariantAttributeModel.value)),
        ['250 g', 'Whole'],
      );
      expect(stageShopVariants(session.root, combinations), 2);
      expect(session.root.rows(ProductModel.variants), hasLength(4));
      expect(source.createCalls, isEmpty);
      expect(source.updateCalls, isEmpty);
      expect(session.isDirty, isTrue);
    },
  );

  for (final width in [375.0, 600.0, 1440.0]) {
    testWidgets(
      'custom operations fits $width pixels and refreshes committed receivables',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final registry = buildBeakRegistry();
        final memory = InMemoryBeakDataSource(registry: registry)
          ..seed(const InvoiceModel(), [
            const InvoiceModel().record([
              InvoiceModel.id.to('issued'),
              InvoiceModel.number.to('I-1'),
              InvoiceModel.status.to(InvoiceStatus.issued),
              InvoiceModel.total.to(eur('123.45')),
            ]),
            const InvoiceModel().record([
              InvoiceModel.id.to('draft'),
              InvoiceModel.number.to('I-2'),
              InvoiceModel.status.to(InvoiceStatus.draft),
              InvoiceModel.total.to(eur('999.99')),
            ]),
          ]);
        final screen = shopOperations();
        await tester.pumpWidget(
          BeakPanel(
            formatting: const BeakFormatting(locale: 'de_AT', currency: 'EUR'),
            pages: [
              BeakScreen(
                path: '/',
                title: screen.title,
                icon: screen.icon,
                body: screen.body,
              ),
            ],
            resources: [InvoiceResource(), OrderResource(), VariantResource()],
            dataSource: memory,
          ),
        );
        await tester.pumpAndSettle();
        final amount = const BeakFormatting(
          locale: 'de_AT',
          currency: 'EUR',
        ).exactCurrency(eur('123.45'));
        expect(find.text(amount), findsOneWidget);
        expect(find.text('Fulfillment queue'), findsOneWidget);
        expect(find.text('Replenishment queue'), findsOneWidget);
        final source = beakDependencies(
          tester.element(find.byType(ShopReceivablesCard)),
        )<BeakDataSource>();
        await source.update(
          'invoices',
          'issued',
          BeakRecord.fromRow({'status': 'paid'}),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('All clear. No issued invoices are awaiting payment.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  // --8<-- [start:retryableBillingTest]
  testWidgets(
    'custom billing widget shows a retryable error without a false zero',
    (tester) async {
      final registry = buildBeakRegistry();
      final source = _FailingAggregate(
        InMemoryBeakDataSource(registry: registry),
      );
      await tester.pumpWidget(
        BeakPanel(
          pages: [
            BeakScreen(
              path: '/',
              title: 'Billing',
              icon: const BeakIconToken(OiIcons.receiptText),
              body: BeakWidgetBlock((_) => const ShopReceivablesCard()),
            ),
          ],
          resources: [InvoiceResource()],
          dataSource: source,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(
        find.text('All clear. No issued invoices are awaiting payment.'),
        findsNothing,
      );
      source.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        find.text('All clear. No issued invoices are awaiting payment.'),
        findsOneWidget,
      );
    },
  );
  // --8<-- [end:retryableBillingTest]
}

// --8<-- [start:FailingAggregate]
final class _FailingAggregate extends BeakRecordingDataSource {
  _FailingAggregate(super.inner);
  bool fail = true;
  @override
  Future<num> aggregate(BeakAggregateSpec spec) => fail
      ? Future.error(const BeakStorageException('Unavailable'))
      : super.aggregate(spec);
}
// --8<-- [end:FailingAggregate]
