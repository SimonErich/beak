# Custom blocks and widgets

> Embed custom widgets while sharing Beak's data, formatting, refresh and draft infrastructure.

Use `BeakWidgetBlock` when a page needs a bespoke widget. It composes with ordinary
Beak cards, metrics, tables and grids. Import `package:beak/panel.dart` for Beak and
`package:beak/ui.dart` for the `Oi*` widgets.

```dart
BeakWidgetBlock((context) => const ShopReceivablesCard())
```

A custom widget keeps the panel's theme, current data source and display policy.
`beakDependencies(context)<BeakDataSource>()` resolves the nearest panel's source;
`BeakResourceRepository` supplies the normal typed error boundary;
`useBeakDataRevision(source, table: ...)` refreshes on confirmed writes and owns
its subscription. Use `BeakFormatting.of(context)` for numbers and dates.

The shop's reusable receivables card computes the sum of issued invoices, displays
minor-unit money accurately, handles loading and errors, supports retry, and
refreshes after a payment action. The same widget is embedded in its dashboard and
Operations page.

```dart title="examples/clean_beak_config/lib/widgets/receivables_card.dart"
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

```

This is also the embedding pattern for an existing Flutter application: install
Beak's dependency and formatting scopes around a custom composition, or pass a
data source explicitly to standalone widgets such as `BeakStatCard` and
`BeakConfiguredForm`. See [standalone widgets](using-beak-widgets-standalone.md).

## Custom content inside a form

`BeakFormWidget` receives the existing `BeakDraftRecord`. Read typed fields with
`draft.read(Model.field)`, write them with `draft.set(...)`, and add related drafts
with `draft.addRow(Model.children)`. The normal form still owns validation,
cancellation, persistence and recovery.

Use `BeakDraftScope.of(context).enabled` before offering custom editing actions.
It includes inherited section guards and saving state. Set `showOnRead: false`
when the widget is an editing tool with no useful read presentation.

```dart
BeakFormWidget(
  showOnRead: false,
  builder: (context, draft) => ShopVariantBuilder(draft: draft),
)
```

The shop's [variant builder](../models/dynamic-attributes-and-variants.md) previews
combinations and stages nested attribute rows through this interface. It does not
need a second form controller or a separate save handler.

Prefer the standard data blocks when their presentation fits. Custom widgets own
their accessibility, loading/error presentation and responsive layout. Use the
same `Oi*` controls as Beak, without Material or Cupertino dependencies.

## Continue reading

- [Custom screens](../panel/custom-screens.md).
- [Dynamic attributes and variants](../models/dynamic-attributes-and-variants.md).
