import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import '../resources/invoices/models/invoice.dart';

/// A custom widget using the panel's transport, formatting and refresh scope.
// --8<-- [start:ShopReceivablesCard]
class ShopReceivablesCard extends HookWidget {
  /// Embeds the billing summary in any panel page or custom composition.
  const ShopReceivablesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final source = beakDependencies(context)<BeakDataSource>();
    final revision = useBeakDataRevision(
      source,
      table: const InvoiceModel().table,
    );
    final attempt = useState(0);
    final request = useMemoized(
      () => BeakResourceRepository(source).aggregate(
        BeakAggregateSpec.sum(
          table: const InvoiceModel().table,
          column: InvoiceModel.totalCents.column,
          filter: InvoiceModel.status.eq(InvoiceStatus.issued),
        ),
      ),
      [source, revision, attempt.value],
    );
    final snapshot = useFuture(request, preserveState: false);
    final strings = BeakLocalizations.of(context);
    final format = BeakFormatting.of(context);
    return OiCard(
      child: OiColumn(
        breakpoint: context.breakpoint,
        crossAxisAlignment: CrossAxisAlignment.start,
        gap: const OiResponsive(16),
        children: [
          OiRow(
            breakpoint: context.breakpoint,
            children: [
              const OiIcon(icon: OiIcons.receiptText, label: 'Receivables'),
              const Expanded(child: OiLabel.h3('Outstanding receivables')),
            ],
          ),
          if (snapshot.connectionState != ConnectionState.done)
            OiProgress.linear(indeterminate: true, label: strings.loading)
          else if (snapshot.data case BeakErr<num>(:final error)) ...[
            OiLabel.small(strings.errorMessage(error)),
            OiButton.ghost(label: strings.retry, onTap: () => attempt.value++),
          ] else if (snapshot.data case BeakOk<num>(:final value)) ...[
            OiLabel.h1(
              format.exactCurrency(BeakDecimal(value.toInt(), scale: 2)),
            ),
            OiLabel.small(
              value == 0
                  ? 'All clear. No issued invoices are awaiting payment.'
                  : 'Issued invoices awaiting payment. Drafts and cancelled documents are excluded.',
            ),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OiButton.secondary(
                label: 'Review invoices',
                onTap: () =>
                    context.go(BeakRoutes.list(const InvoiceModel().table)),
              ),
              OiButton.ghost(
                label: 'Refresh receivables',
                onTap: snapshot.connectionState == ConnectionState.done
                    ? () => attempt.value++
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --8<-- [end:ShopReceivablesCard]
