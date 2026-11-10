part of '../beak_block_host.dart';

/// Renders a [BeakTableBlock] as a full `BeakDataTable` — server-side sort,
/// filter, pagination, and row actions — bound to the panel's data source.
class _BeakTableBlockView extends StatelessWidget {
  const _BeakTableBlockView({required this.block});

  final BeakTableBlock block;

  void _openRecord(BuildContext context, BeakRecord record) {
    final id = block.model.primaryKeyOf(record);
    if (id == null) return;
    context.go(BeakRoutes.show(block.model.table, id));
  }

  @override
  Widget build(BuildContext context) {
    final void Function(BuildContext, BeakRecord) open =
        block.onRowTap ?? _openRecord;
    final table = SizedBox(
      height: block.heightInPixels,
      child: BeakDataTable(
        model: block.model,
        dataSource: beakDependencies(context)<BeakDataSource>(),
        actions: block.actions,
        onRowTap: (record) => open(context, record),
        columns: block.columns,
        fields: block.fields,
        presentations: block.tableColumns,
        enableDelete: block.enableDelete,
        initialSpec: block.initialSpec,
        baseFilter: block.baseFilter,
        label: block.title,
      ),
    );
    final title = block.title;
    if (title == null) {
      return table;
    }
    return OiCard(title: OiLabel.smallStrong(title), child: table);
  }
}
