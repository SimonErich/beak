part of '../beak_block_host.dart';

/// Fetches a [BeakInvoiceBlock]'s record and composes an invoice document —
/// a logo/from/to header, a reused [BeakTableBlock] of line items, and a
/// totals column — from existing obers_ui and Beak pieces.
class _BeakInvoiceBlockView extends HookWidget {
  const _BeakInvoiceBlockView({required this.block});

  final BeakInvoiceBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final record = useState<BeakRecord?>(null);

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final repository = BeakResourceRepository(dataSource);
        // With a billed-party relation bound, fetch through a primary-key
        // query so the relation arrives eager-loaded; getOne cannot load
        // relations.
        if (block.toRelation case final BeakBelongsTo relation) {
          final result = await repository.query(
            BeakQuerySpec(
              table: block.model.table,
              filter: BeakFieldFilter(
                column: block.model.primaryKey,
                operator: BeakOperator.eq,
                value: BeakValue.of(block.recordId),
              ),
              relationLoads: [BeakRelationLoad(relation.key)],
              pagination: const BeakPagination(perPage: 1),
            ),
          );
          if (cancelled) {
            return;
          }
          if (result case BeakOk(:final value) when value.items.isNotEmpty) {
            record.value = value.items.first;
          }
          return;
        }
        final result = await repository.getOne(
          block.model.table,
          block.recordId,
        );
        if (cancelled) {
          return;
        }
        if (result case BeakOk(:final value)) {
          record.value = value;
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource, block]);

    final BeakRecord? invoice = record.value;
    return SingleChildScrollView(
      child: OiColumn(
        breakpoint: context.breakpoint,
        gap: const OiResponsive<double>(16),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OiLabel.h2(block.title),
          if (invoice == null)
            const OiLabel.body('Loading…')
          else ...[
            _header(context, invoice),
            const OiDivider(spacing: 8),
            _lineItems(),
            _totals(context, invoice),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context, BeakRecord invoice) => OiRow(
    breakpoint: context.breakpoint,
    gap: const OiResponsive<double>(24),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (block.logoField case final BeakColumn column)
        if (_readString(invoice, column) case final String url)
          OiImage(src: url, alt: '${block.title} logo', height: 48),
      if (block.metaFields.isNotEmpty)
        _party(context, 'Details', invoice, block.metaFields),
      if (block.fromFields.isNotEmpty)
        _party(context, 'From', invoice, block.fromFields),
      if (block.toFields.isNotEmpty)
        _party(context, 'To', invoice, block.toFields),
      if (_billedParty(invoice) case final BeakRecord party)
        if (block.toPartyFields.isNotEmpty)
          _party(context, 'To', party, block.toPartyFields),
    ],
  );

  /// The eager-loaded billed-party record, when [BeakInvoiceBlock.toRelation]
  /// is bound and arrived with the invoice.
  BeakRecord? _billedParty(BeakRecord invoice) {
    final BeakBelongsTo? relation = block.toRelation;
    if (relation == null) {
      return null;
    }
    final related = invoice.relations[relation.key] ?? const <BeakRecord>[];
    return related.isEmpty ? null : related.first;
  }

  Widget _party(
    BuildContext context,
    String title,
    BeakRecord invoice,
    List<BeakColumn> fields,
  ) => SizedBox(
    width: 280,
    child: OiKeyValue.group(
      title: title,
      children: [
        for (final column in fields)
          OiKeyValue(
            label: column.label,
            value: beakCellText(
              column,
              invoice[column.key]?.raw,
              formatting: BeakFormatting.maybeOf(context),
            ),
          ),
      ],
    ),
  );

  Widget _lineItems() {
    final BeakColumn? foreignKey = block.lineItemsForeignKey;
    return BeakBlockHost(
      block: BeakTableBlock(
        title: 'Line items',
        model: block.lineItemsModel,
        // An invoice's lines are part of the document: this block reads them,
        // it does not edit the invoice by deleting one.
        enableDelete: false,
        baseFilter: foreignKey == null
            ? null
            : BeakFieldFilter(
                column: foreignKey,
                operator: BeakOperator.eq,
                value: BeakValue.of(block.recordId),
              ),
      ),
    );
  }

  Widget _totals(BuildContext context, BeakRecord invoice) {
    // Through the shared cell formatter so decimal columns keep their
    // configured currency prefix and precision — Postgres numerics arrive
    // over the wire as strings.
    OiKeyValue row(BeakColumn column) => OiKeyValue(
      label: column.label,
      value: beakCellText(
        column,
        invoice[column.key]?.raw,
        formatting: BeakFormatting.maybeOf(context),
      ),
    );
    final rows = <OiKeyValue>[
      if (block.subtotalField case final BeakColumn column) row(column),
      if (block.discountField case final BeakColumn column) row(column),
      if (block.shippingField case final BeakColumn column) row(column),
      if (block.taxField case final BeakColumn column) row(column),
      row(block.totalField),
    ];
    return OiKeyValue.group(title: 'Totals', children: rows);
  }
}
