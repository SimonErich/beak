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

  /// The narrowest card width at which every action fits at its label's width.
  ///
  /// A button never shrinks below its label, so on a narrower card the
  /// actions stack at the card's width instead of wrapping past its edge.
  static const _actionsRowMinWidthInPixels = 320.0;

  @override
  Widget build(BuildContext context) {
    // --8<-- [start:receivablesData]
    final source = beakDependencies(context)<BeakDataSource>();
    final revision = useBeakDataRevision(
      source,
      table: const InvoiceModel().table,
    );
    final attempt = useState(0);
    final request = useMemoized(
      () => BeakResourceRepository(source).run(
        () => InvoiceModel.total.sum(
          source,
          filter: InvoiceModel.status.eq(InvoiceStatus.issued),
        ),
      ),
      [source, revision, attempt.value],
    );
    final snapshot = useFuture(request, preserveState: false);
    final strings = BeakLocalizations.of(context);
    final format = BeakFormatting.of(context);
    // --8<-- [end:receivablesData]
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
          // --8<-- [start:receivablesStates]
          if (snapshot.connectionState != ConnectionState.done)
            OiProgress.linear(indeterminate: true, label: strings.loading)
          else if (snapshot.data case BeakErr<BeakDecimal>(:final error)) ...[
            OiLabel.small(strings.errorMessage(error)),
            OiButton.ghost(label: strings.retry, onTap: () => attempt.value++),
          ] else if (snapshot.data case BeakOk<BeakDecimal>(:final value)) ...[
            OiLabel.h1(format.exactCurrency(value)),
            OiLabel.small(
              value.units == 0
                  ? 'All clear. No issued invoices are awaiting payment.'
                  : 'Issued invoices awaiting payment. Drafts and cancelled documents are excluded.',
            ),
          ],
          // --8<-- [end:receivablesStates]
          // The card's own width decides, not the viewport's: beside a panel
          // sidebar a card can be narrower than it is on a phone.
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < _actionsRowMinWidthInPixels;
              final actions = [
                OiButton.secondary(
                  label: 'Review invoices',
                  fullWidth: stacked,
                  onTap: () =>
                      context.go(BeakRoutes.list(const InvoiceModel().table)),
                ),
                OiButton.ghost(
                  label: 'Refresh receivables',
                  fullWidth: stacked,
                  onTap: snapshot.connectionState == ConnectionState.done
                      ? () => attempt.value++
                      : null,
                ),
              ];
              return stacked
                  ? OiColumn(
                      breakpoint: context.breakpoint,
                      gap: const OiResponsive(8),
                      children: actions,
                    )
                  : Wrap(spacing: 12, runSpacing: 8, children: actions);
            },
          ),
        ],
      ),
    );
  }
}

// --8<-- [end:ShopReceivablesCard]
