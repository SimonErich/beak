import 'package:beak/server.dart';

import '../models/models.dart';

/// Billing documents sum immutable order snapshots; issued documents stay fixed.
abstract final class FoodioInvoiceRules {
  /// Reconciles draft documents and freezes them when their issue action runs.
  static Future<void> prepare(
    BeakCandidateGraph graph,
    WormDataSource source,
  ) async {
    final invoiceRefs = <BeakRecordRef>{};
    for (final node in graph.nodes) {
      if (node.ref.table == 'invoices' && node.changed) {
        invoiceRefs.add(node.ref);
      }
      if (node.ref.table == 'orders' && node.changed) {
        final current = node.reference(OrderModel.invoice);
        final previous = node.originalReference(OrderModel.invoice);
        if (current != null) invoiceRefs.add(current);
        if (previous != null) invoiceRefs.add(previous);
      }
    }
    for (final ref in invoiceRefs) {
      final invoice = await graph.load(ref);
      if (invoice.deleted) continue;
      if (invoice.initial != null &&
          invoice.original(InvoiceModel.status) != InvoiceStatus.draft) {
        continue;
      }
      final records = <BeakRecordRef, BeakCandidateNode>{};
      if (ref.id != null) {
        var page = 1;
        while (true) {
          final result = await source.query(
            const OrderModel().query(
              filter: OrderModel.invoiceId.eq('${ref.id}'),
              pagination: BeakPagination(page: page, perPage: 100),
            ),
          );
          for (final record in result.items) {
            final node = await graph.load(
              BeakRecordRef.existing('orders', record['id']!.raw!),
            );
            records[node.ref] = node;
          }
          if (result.items.length < 100) break;
          page++;
        }
      }
      for (final node in graph.nodes) {
        if (node.ref.table == 'orders' &&
            node.reference(OrderModel.invoice) == ref) {
          records[node.ref] = node;
        }
      }
      final included = records.values.where(
        (node) =>
            !node.deleted &&
            node.reference(OrderModel.invoice) == ref &&
            node.read(OrderModel.status) != OrderStatus.cancelled &&
            node.read(OrderModel.status) != OrderStatus.draft,
      );
      if (invoice.read(InvoiceModel.status) == InvoiceStatus.issued &&
          included.isEmpty) {
        throw const BeakValidationException(
          'Add at least one placed order before issuing the invoice.',
        );
      }
      for (final order in included) {
        if (invoice.reference(InvoiceModel.organization) !=
            order.reference(OrderModel.organization)) {
          throw const BeakValidationException(
            'Invoice orders must belong to the billed organization.',
          );
        }
      }
      graph.write(
        invoice,
        InvoiceModel.grossCents,
        included.fold<int>(
          0,
          (sum, node) => sum + (node.read(OrderModel.grossCents) ?? 0),
        ),
      );
      graph.write(
        invoice,
        InvoiceModel.netCents,
        included.fold<int>(
          0,
          (sum, node) => sum + (node.read(OrderModel.netCents) ?? 0),
        ),
      );
      graph.write(
        invoice,
        InvoiceModel.taxCents,
        included.fold<int>(
          0,
          (sum, node) => sum + (node.read(OrderModel.taxCents) ?? 0),
        ),
      );
      final organization = await graph.linked(
        invoice,
        InvoiceModel.organization,
      );
      if (organization != null) {
        graph.write(
          invoice,
          InvoiceModel.billingEmail,
          organization.read(OrganizationModel.billingEmail),
        );
        graph.write(
          invoice,
          InvoiceModel.billingAddress,
          organization.read(OrganizationModel.billingAddress),
        );
      }
    }
  }
}
