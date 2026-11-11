import 'package:beak_core/beak_core.dart';
import 'package:obers_ui/obers_ui.dart';

import '../actions/beak_action.dart';
import '../filters/beak_filter_widget.dart';
import '../form/beak_form_layout.dart';
import '../presentation/beak_action_presentation.dart';
import '../presentation/beak_record_template.dart';
import '../query/beak_list_defaults.dart';
import '../query/beak_list_definition.dart';
import '../query/beak_list_export.dart';
import 'beak_resource.dart';
import 'beak_resource_screen.dart';

/// Builds the resource [BeakResource.standard] describes.
///
/// Kept beside the factory so the resource class stays a declaration and the
/// conventions live in one readable place.
BeakResource buildStandardResource(
  BeakModel model, {
  String? title,
  BeakIconToken icon = const BeakIconToken(OiIcons.database),
  String? navigationTitle,
  String? navigationGroup,
  int navigationRank = 0,
  List<BeakScalarField<Object>>? columns,
  List<BeakFormNode>? form,
  List<BeakTab> tabs = const [],
  List<BeakFilterDef> filters = const [],
  BeakRecordTemplate? header,
  bool readOnly = false,
  BeakListDefaults defaults = const BeakListDefaults(),
  List<BeakFormNode> identity = const [],
  List<BeakRecordAction> recordActions = const [],
  List<BeakBulkAction> bulkActions = const [],
  List<BeakGlobalAction> globalActions = const [],
}) {
  final capabilities = model.capabilities;
  final canCreate = !readOnly && capabilities.contains(BeakOperation.create);
  final canEdit = !readOnly && capabilities.contains(BeakOperation.update);
  final canDelete = !readOnly && capabilities.contains(BeakOperation.delete);
  return BeakResource(
    model: model,
    title: title,
    icon: icon,
    navigationTitle: navigationTitle,
    navigationGroup: navigationGroup,
    navigationRank: navigationRank,
    canCreate: canCreate,
    canEdit: canEdit,
    canDelete: canDelete,
    filters: filters,
    recordActions: recordActions,
    bulkActions: bulkActions,
    globalActions: globalActions,
    screens: [
      buildStandardTableScreen(
        model,
        columns: columns,
        filters: filters,
        defaults: defaults,
        title: title,
      ),
      BeakFormScreen(
        roles: {
          BeakScreenRole.read,
          if (canCreate) BeakScreenRole.create,
          if (canEdit) BeakScreenRole.edit,
        },
        recordHeader: header,
        asideFraction: 1 / 3,
        layout: form == null
            ? null
            : BeakFormLayout(
                children: [
                  if (tabs.isEmpty)
                    BeakCard.general(children: form)
                  else
                    BeakTabs(
                      tabs: [
                        BeakTab.general(children: form),
                        ...tabs,
                      ],
                    ),
                ],
              ),
      ),
    ],
  );
}

/// The scalar fields a generated table shows, minus the primary key and any
/// column the model keeps for the detail page.
List<BeakScalarField<Object>> _defaultColumns(BeakModel model) => [
  for (final column in model.columnsFor(BeakContext.table))
    if (column.key != model.primaryKey.key && column is! BeakCustomColumn)
      BeakScalarField<Object>(model: model, column: column),
];

/// The list [BeakResource.standard] shows, for a resource with its own
/// screens: [columns] (the model's table fields by default) after
/// [leadingColumns], the panel's list conventions from [defaults], and a CSV
/// export of the primary key and the shown fields of the model itself.
BeakTableScreen buildStandardTableScreen(
  BeakModel model, {
  List<BeakScalarField<Object>>? columns,
  List<BeakTableColumn> leadingColumns = const [],
  List<BeakFilterDef> filters = const [],
  List<BeakActionPresentation>? rowActions,
  BeakQuerySpec? query,
  String? title,
  BeakListDefaults defaults = const BeakListDefaults(),
}) {
  final shown = columns ?? _defaultColumns(model);
  final exportFields = <BeakScalarField<Object>>[];
  final exportKeys = <String>{model.primaryKey.key};
  for (final field in shown) {
    if (field.path.isNotEmpty || !exportKeys.add(field.key)) continue;
    exportFields.add(field);
  }
  return BeakTableScreen(
    fields: shown,
    query: query ?? model.query(),
    definition: BeakListDefinition(
      title: title,
      columns: [
        ...leadingColumns,
        for (final field in shown) BeakTableColumn.field(field),
      ],
      filters: filters,
      quickFilters: filters.take(defaults.quickFilters).toList(),
      rowActions: rowActions,
      pageSize: defaults.pageSize,
      fitTableToRows: defaults.fitRows,
      scrollMode: defaults.scroll,
      export: defaults.export
          ? BeakListExport(
              fileName: '${model.table}.csv',
              fields: [
                BeakScalarField<Object>(model: model, column: model.primaryKey),
                ...exportFields,
              ],
            )
          : null,
    ),
  );
}
