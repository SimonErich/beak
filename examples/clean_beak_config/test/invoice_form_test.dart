import 'package:beak/panel.dart';
import 'package:beak/testing.dart';
import 'package:clean_beak_config/beak/registry.g.dart';
import 'package:clean_beak_config/resources/invoices/models/invoice.dart';
import 'package:clean_beak_config/resources/invoices/models/invoice_item.dart';
import 'package:clean_beak_config/resources/invoices/models/invoice_voucher.dart';
import 'package:clean_beak_config/resources/invoices/screens/invoice_form.dart';
import 'package:clean_beak_config/resources/invoices/screens/invoice_preview.dart';
import 'package:clean_beak_config/resources/products/models/product.dart';
import 'package:clean_beak_config/resources/taxes/models/tax_rate.dart';
import 'package:clean_beak_config/resources/users/models/user.dart';
import 'package:clean_beak_config/resources/vouchers/models/voucher.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/money.dart';

BeakRecord _taxRate(String id, String name, String percent) =>
    const TaxRateModel().record([
      TaxRateModel.id.to(id),
      TaxRateModel.name.to(name),
      TaxRateModel.ratePercent.to(eur(percent)),
      TaxRateModel.active.to(true),
    ]);

void main() {
  test(
    'invoice wizard previews mixed lines, tax and ordered vouchers without saving',
    () async {
      final registry = buildBeakRegistry();
      final source = InMemoryBeakDataSource(registry: registry);
      final customer = BeakRecord.fromRow({
        'id': 'ada',
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'email': 'ada@example.com',
      });
      final standardTax = _taxRate('standard', 'Standard', '20');
      final reducedTax = _taxRate('reduced', 'Reduced', '10');
      final product = BeakRecord(
        values: const ProductModel().record([
          ProductModel.id.to('beans'),
          ProductModel.name.to('Beans'),
          ProductModel.price.to(eur('12.50')),
          ProductModel.taxRateId.to('standard'),
        ]).values,
        relations: {
          ProductModel.taxRate.key: [standardTax],
        },
      );
      final fixed = const VoucherModel().record([
        VoucherModel.id.to('five'),
        VoucherModel.code.to('FIVE'),
        VoucherModel.name.to('Five euros'),
        VoucherModel.kind.to(VoucherKind.fixed),
        VoucherModel.value.to(eur('5')),
        VoucherModel.active.to(true),
      ]);
      final percentage = const VoucherModel().record([
        VoucherModel.id.to('ten'),
        VoucherModel.code.to('TEN'),
        VoucherModel.name.to('Ten percent'),
        VoucherModel.kind.to(VoucherKind.percentage),
        VoucherModel.value.to(eur('10')),
        VoucherModel.active.to(true),
      ]);
      source.seed(const UserModel(), [customer]);
      source.seed(const ProductModel(), [product]);
      source.seed(const TaxRateModel(), [standardTax, reducedTax]);
      source.seed(const VoucherModel(), [fixed, percentage]);
      final session = BeakFormSession(
        model: const InvoiceModel(),
        dataSource: source,
        registry: registry,
        steps: invoiceSteps(),
      );
      addTearDown(session.dispose);
      session.root.set(InvoiceModel.number, 'INV-TEST');
      session.root.set(InvoiceModel.issuedAt, DateTime.utc(2026, 9, 26));
      session.root.select(InvoiceModel.customer, customer);
      expect(await session.validateStep(0), isTrue);
      expect(
        await session.validateStep(1),
        isFalse,
        reason: 'An invoice needs a line before moving on.',
      );
      final goods = session.root.addRow(InvoiceModel.items);
      goods.select(InvoiceItemModel.product, product);
      goods.set(InvoiceItemModel.quantity, 2);
      final shipping = session.root.addRow(InvoiceModel.items);
      shipping.set(InvoiceItemModel.quantity, 1);
      shipping.set(InvoiceItemModel.label, 'Delivery');
      shipping.set(InvoiceItemModel.unitPrice, eur('5'));
      shipping.select(InvoiceItemModel.taxRate, reducedTax);
      final first = session.root.addRow(InvoiceModel.vouchers);
      first.set(InvoiceVoucherModel.position, 0);
      first.select(InvoiceVoucherModel.voucher, fixed);
      final second = session.root.addRow(InvoiceModel.vouchers);
      second.set(InvoiceVoucherModel.position, 1);
      second.select(InvoiceVoucherModel.voucher, percentage);
      final preview = invoicePreview(BeakFormReader(session.root));
      expect(preview.problem, isNull);
      expect(preview.totals?.subtotal, eur('30.00'));
      expect(preview.totals?.discount, eur('7.50'));
      expect(preview.totals?.tax, eur('4.13'));
      expect(preview.totals?.total, eur('26.63'));
      expect(await session.validate(), isTrue);
      expect((await source.query(const InvoiceModel().query())).total, 0);
      second.set(InvoiceVoucherModel.position, 0);
      expect(await session.validateStep(2), isFalse);
      expect(session.root.errors[InvoiceModel.vouchers.key], isNotEmpty);
      expect(
        invoicePreview(BeakFormReader(session.root)).problem,
        'Give each voucher a different position.',
      );
      second.set(InvoiceVoucherModel.position, 1);
      expect(await session.validateStep(2), isTrue);
      shipping.set(InvoiceItemModel.unitPrice, null);
      expect(await session.validateStep(1), isFalse);
      expect(shipping.errors[InvoiceItemModel.unitPrice.key], isNotEmpty);
    },
  );

  test(
    'saved draft previews selection changes while issued customer details stay frozen',
    () async {
      final registry = buildBeakRegistry();
      final source = InMemoryBeakDataSource(registry: registry);
      final customer = BeakRecord.fromRow({
        'id': 'customer',
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'email': 'ada@example.com',
      });
      final other = BeakRecord.fromRow({
        'id': 'other',
        'first_name': 'Grace',
        'last_name': 'Hopper',
        'email': 'grace@example.com',
      });
      final originalTax = _taxRate('tax', 'Changed catalog rate', '15');
      final differentTax = _taxRate('other-tax', 'Other rate', '20');
      source.seed(const UserModel(), [customer, other]);
      source.seed(const TaxRateModel(), [originalTax, differentTax]);
      source.seed(const InvoiceModel(), [
        BeakRecord.fromRow({
          'id': 'invoice',
          'number': 'DRAFT',
          'status': 'draft',
          'issued_at': DateTime.utc(2026, 9, 26),
          'customer_id': 'customer',
          'customer_name': 'Old customer snapshot',
          'customer_email': 'old@example.com',
        }),
        BeakRecord.fromRow({
          'id': 'issued',
          'number': 'ISSUED',
          'status': 'issued',
          'issued_at': DateTime.utc(2026, 9, 26),
          'customer_id': 'customer',
          'customer_name': 'Billed customer',
          'customer_email': 'billed@example.com',
        }),
      ]);
      source.seed(const InvoiceItemModel(), [
        const InvoiceItemModel().record([
          InvoiceItemModel.id.to('line'),
          InvoiceItemModel.invoiceId.to('invoice'),
          InvoiceItemModel.label.to('Service'),
          InvoiceItemModel.quantity.to(1),
          InvoiceItemModel.unitPrice.to(eur('10')),
          InvoiceItemModel.taxRateId.to('tax'),
          InvoiceItemModel.taxPercent.to(eur('10')),
        ]),
      ]);
      final session = BeakFormSession(
        model: const InvoiceModel(),
        dataSource: source,
        registry: registry,
        steps: invoiceSteps(),
        recordId: 'invoice',
      );
      addTearDown(session.dispose);
      await session.load();
      final row = session.root.rows(InvoiceModel.items).single;
      final reader = BeakFormReader(row);
      expect(
        invoiceTaxPercent(reader),
        eur('10'),
        reason: 'Catalog edits do not change saved rates.',
      );
      row.select(InvoiceItemModel.taxRate, differentTax);
      expect(invoiceTaxPercent(reader), eur('20'));
      expect(
        invoicePreview(BeakFormReader(session.root)).totals?.total,
        eur('12.00'),
      );
      row.select(InvoiceItemModel.taxRate, originalTax);
      expect(
        invoiceTaxPercent(reader),
        eur('10'),
        reason: 'Restoring the original selection restores its snapshot.',
      );
      final root = BeakFormReader(session.root);
      expect(invoiceCustomerName(root), 'Ada Lovelace');
      session.root.select(InvoiceModel.customer, other);
      expect(invoiceCustomerName(root), 'Grace Hopper');
      expect(invoiceCustomerEmail(root), 'grace@example.com');
      final issued = BeakFormSession(
        model: const InvoiceModel(),
        dataSource: source,
        registry: registry,
        steps: invoiceSteps(),
        recordId: 'issued',
      );
      addTearDown(issued.dispose);
      await issued.load();
      expect(
        invoiceCustomerName(BeakFormReader(issued.root)),
        'Billed customer',
      );
      expect(
        invoiceCustomerEmail(BeakFormReader(issued.root)),
        'billed@example.com',
      );
    },
  );

  test('incomplete drafts show guidance instead of throwing during render', () {
    final registry = buildBeakRegistry();
    final session = BeakFormSession(
      model: const InvoiceModel(),
      dataSource: InMemoryBeakDataSource(registry: registry),
      registry: registry,
      steps: invoiceSteps(),
    );
    addTearDown(session.dispose);
    expect(
      invoicePreview(BeakFormReader(session.root)).problem,
      'Add at least one invoice line.',
    );
    final row = session.root.addRow(InvoiceModel.items);
    row.set(InvoiceItemModel.quantity, 1);
    row.set(InvoiceItemModel.label, 'Consulting');
    row.set(InvoiceItemModel.unitPrice, eur('10'));
    row.set(InvoiceItemModel.discount, eur('20'));
    expect(
      invoicePreview(BeakFormReader(session.root)).problem,
      'A line discount cannot exceed its subtotal.',
    );
  });
}
