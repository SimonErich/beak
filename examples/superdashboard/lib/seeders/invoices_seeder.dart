import 'package:superdashboard/models/models.dart';

import 'seed_context.dart';
import 'seed_ids.dart';

/// Seeds the Invoices domain: invoices billed to hero users, with line items
/// whose totals reconcile with the invoice header.
final class InvoicesSeeder {
  /// Creates the seeder.
  const InvoicesSeeder();

  static const List<String> _lineItems = [
    'Black Strap Watch',
    'Stainless Steel Watch',
    'Design retainer',
    'Hosting — annual',
    'Consulting hours',
    'Priority support',
  ];

  /// Seeds all Invoices-domain rows through [ctx].
  Future<void> seed(SeedContext ctx) async {
    final invoiceRows = <Map<String, Object?>>[];
    final itemRows = <Map<String, Object?>>[];

    for (var index = 0; index < 14; index++) {
      // The first invoice has a fixed id so the invoice-detail page opens a
      // stable record.
      final id = index == 0 ? SeedIds.invoice : ctx.uuid();
      final issueDate = ctx.daysAgo(120);

      var subtotal = 0.0;
      final lineCount = ctx.between(1, 4);
      for (var line = 0; line < lineCount; line++) {
        final price = ctx.money(45, 480);
        final quantity = ctx.between(1, 3);
        final lineTotal = double.parse((price * quantity).toStringAsFixed(2));
        subtotal += lineTotal;
        itemRows.add({
          'id': ctx.uuid(),
          'invoice_id': id,
          'item': ctx.pick(_lineItems),
          'description': ctx.faker.sentence(wordCount: 6),
          'price': price,
          'quantity': quantity,
          'total': lineTotal,
        });
      }
      subtotal = double.parse(subtotal.toStringAsFixed(2));
      final discount = ctx.chance(0.4) ? ctx.money(0, 40) : 0.0;
      final shipping = ctx.money(0, 25);
      final tax = double.parse((subtotal * 0.08).toStringAsFixed(2));
      final total = double.parse(
        (subtotal - discount + shipping + tax).toStringAsFixed(2),
      );
      final status = ctx.weighted({
        InvoiceStatus.paid.name: 6,
        InvoiceStatus.sent.name: 3,
        InvoiceStatus.overdue.name: 2,
        InvoiceStatus.draft.name: 1,
        InvoiceStatus.partial.name: 1,
      });
      final balance = status == InvoiceStatus.paid.name
          ? 0.0
          : status == InvoiceStatus.partial.name
          ? double.parse((total / 2).toStringAsFixed(2))
          : total;

      invoiceRows.add({
        'id': id,
        'number': 'INV-${3000 + index}',
        'user_id': SeedIds.heroUsers[index % SeedIds.heroUsers.length],
        'status': status,
        'issue_date': issueDate,
        'due_date': issueDate.add(const Duration(days: 30)),
        'subtotal': subtotal,
        'discount': discount,
        'shipping': shipping,
        'tax': tax,
        'total': total,
        'balance_due': balance,
        'note': ctx.faker.sentence(wordCount: 8),
      });
    }

    await ctx.insertMany('invoices', invoiceRows);
    await ctx.insertMany('invoice_items', itemRows);
  }
}
