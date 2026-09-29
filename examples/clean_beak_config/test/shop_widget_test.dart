import 'package:beak/panel.dart';
import 'package:beak/testing.dart';
import 'package:beak/ui.dart';
import 'package:clean_beak_config/beak/registry.g.dart';
import 'package:clean_beak_config/overview.dart';
import 'package:clean_beak_config/resources/fulfillment/models/fulfillment_policy.dart';
import 'package:clean_beak_config/resources/fulfillment/screens/fulfillment_policy_form.dart';
import 'package:clean_beak_config/resources/invoices/invoice_resource.dart';
import 'package:clean_beak_config/resources/orders/order_resource.dart';
import 'package:clean_beak_config/resources/products/product_resource.dart';
import 'package:clean_beak_config/resources/products/variant_resource.dart';
import 'package:clean_beak_config/resources/products/models/product.dart';
import 'package:clean_beak_config/resources/products/screens/product_form.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/money.dart';

void main() {
  testWidgets('shop overview loads its operational metrics and tables', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final registry = buildBeakRegistry();
    await tester.pumpWidget(
      BeakPanel(
        pages: [shopOverview()],
        resources: [
          OrderResource(),
          InvoiceResource(),
          ProductResource(),
          VariantResource(),
        ],
        dataSource: InMemoryBeakDataSource(registry: registry),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Orders to fulfill'), findsOneWidget);
    expect(find.text('Awaiting payment'), findsOneWidget);
    expect(find.text('Upcoming deliveries'), findsOneWidget);
    expect(find.text('Invoices awaiting payment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // --8<-- [start:productPriceTest]
  testWidgets('the product list shows exact euro prices', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const formatting = BeakFormatting(locale: 'de_AT', currency: 'EUR');
    final registry = buildBeakRegistry();
    final source = InMemoryBeakDataSource(registry: registry)
      ..seed(const ProductModel(), [
        const ProductModel().record([
          ProductModel.id.to('beans'),
          ProductModel.name.to('Espresso Beans'),
          ProductModel.price.to(eur('12.50')),
        ]),
        const ProductModel().record([
          ProductModel.id.to('grinder'),
          ProductModel.name.to('Hand Grinder'),
          ProductModel.price.to(eur('1234.05')),
        ]),
      ]);
    await tester.pumpWidget(
      BeakPanel(
        formatting: formatting,
        resources: [ProductResource()],
        dataSource: source,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Espresso Beans'), findsOneWidget);
    expect(find.text(formatting.exactCurrency(eur('12.50'))), findsOneWidget);
    expect(find.text(formatting.exactCurrency(eur('1234.05'))), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  // --8<-- [end:productPriceTest]

  for (final width in [375.0, 1280.0]) {
    testWidgets(
      'semantic fulfillment layout preserves typed draft across tabs at $width pixels',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final registry = buildBeakRegistry();
        BeakFormSession? session;
        // --8<-- [start:standaloneForm]
        await tester.pumpWidget(
          BeakFormattingScope(
            formatting: const BeakFormatting(locale: 'de_AT', currency: 'EUR'),
            child: OiApp(
              theme: OiThemeData.light(),
              home: BeakConfiguredForm(
                model: const FulfillmentPolicyModel(),
                registry: registry,
                dataSource: InMemoryBeakDataSource(registry: registry),
                mode: BeakFormMode.create,
                layout: fulfillmentPolicyForm(),
                onSession: (value) => session = value,
              ),
            ),
          ),
        );
        // --8<-- [end:standaloneForm]
        await tester.pumpAndSettle();
        expect(find.text('Policy identity'), findsOneWidget);
        session!.root.set(FulfillmentPolicyModel.name, 'Standard Europe');
        session!.root.set(FulfillmentPolicyModel.code, 'standard-europe');
        await tester.tap(find.text('Pricing and timing').first);
        await tester.pumpAndSettle();
        expect(find.text('Delivery charges'), findsOneWidget);
        expect(
          session!.root.read(FulfillmentPolicyModel.deliveryFee),
          const BeakDecimal(490, scale: 2),
        );
        expect(
          session!.root.read(FulfillmentPolicyModel.handlingTime),
          const Duration(hours: 24),
        );
        await tester.ensureVisible(find.text('Origin and integration').first);
        await tester.tap(find.text('Origin and integration').first);
        await tester.pumpAndSettle();
        expect(find.text('Dispatch address'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Service').first);
        await tester.tap(find.text('Service').first);
        await tester.pumpAndSettle();
        expect(
          session!.root.read(FulfillmentPolicyModel.name),
          'Standard Europe',
        );
        expect(
          session!.root.read(FulfillmentPolicyModel.signatureRequired),
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'product tabs retain the draft and fit a $width pixel viewport',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final registry = buildBeakRegistry();
        BeakFormSession? session;
        await tester.pumpWidget(
          BeakFormattingScope(
            formatting: const BeakFormatting(locale: 'de_AT', currency: 'EUR'),
            child: OiApp(
              theme: OiThemeData.light(),
              home: BeakConfiguredForm(
                model: const ProductModel(),
                registry: registry,
                dataSource: InMemoryBeakDataSource(registry: registry),
                mode: BeakFormMode.create,
                layout: productForm(),
                onSession: (value) => session = value,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Product details'), findsOneWidget);
        await tester.enterText(find.byType(EditableText).first, 'Test coffee');
        await tester.tap(find.text('Specifications').first);
        await tester.pumpAndSettle();
        expect(find.text('Product attributes'), findsOneWidget);
        await tester.ensureVisible(find.text('Images').first);
        await tester.tap(find.text('Images').first);
        await tester.pumpAndSettle();
        expect(find.text('Product gallery'), findsOneWidget);
        await tester.ensureVisible(find.text('Add image'));
        await tester.tap(find.text('Add image'));
        await tester.pumpAndSettle();
        expect(find.text('Cover image'), findsOneWidget);
        for (final label in ['Move earlier', 'Move later']) {
          final button = tester.widget<OiButton>(
            find.widgetWithText(OiButton, label),
          );
          expect(button.enabled, isFalse);
        }
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text('Variants').first);
        await tester.tap(find.text('Variants').first);
        await tester.pumpAndSettle();
        expect(find.text('Sellable choices'), findsOneWidget);
        await tester.ensureVisible(find.text('Overview').first);
        await tester.tap(find.text('Overview').first);
        await tester.pumpAndSettle();
        expect(session?.root.read(ProductModel.name), 'Test coffee');
        expect(find.text('Test coffee'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
