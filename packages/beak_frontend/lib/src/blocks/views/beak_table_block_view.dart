part of '../beak_block_host.dart';

/// Renders a [BeakTableBlock] as a full `BeakDataTable` — server-side sort,
/// filter, pagination, and row actions — bound to the panel's data source.
class _BeakTableBlockView extends StatelessWidget {
  const _BeakTableBlockView({required this.block});

  final BeakTableBlock block;

  @override
  Widget build(BuildContext context) {
    final table = SizedBox(
      height: block.heightInPixels,
      child: BeakDataTable(
        model: block.model,
        dataSource: beakDependencies(context)<BeakDataSource>(),
        actions: block.actions,
        onRowTap: block.onRowTap,
        columns: block.columns,
        fields: block.fields,
        enableDelete: block.enableDelete,
        initialSpec: block.initialSpec,
        baseFilter: block.baseFilter,
      ),
    );
    final title = block.title;
    if (title == null) {
      return table;
    }
    return OiCard(title: OiLabel.smallStrong(title), child: table);
  }
}
