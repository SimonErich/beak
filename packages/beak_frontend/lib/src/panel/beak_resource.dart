import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../actions/beak_action.dart';
import '../blocks/beak_block.dart';
import '../detail/beak_default_detail_layout.dart';
import '../filters/beak_default_filters.dart';
import '../filters/beak_filter_widget.dart';
import '../form/beak_form_controller_builder.dart';
import '../form/beak_form_field.dart';
import '../form/upload_field.dart';
import 'beak_resource_view.dart';
import 'beak_routes.dart';
import 'beak_resource_screen.dart';

/// A typed icon reference for panel navigation.
///
/// A zero-cost wrapper over [IconData] so resource declarations stay
/// expressive (`BeakIconToken(OiIcons.package)`) without leaking raw icon
/// plumbing into Beak's config surface. Wrap any obers_ui `OiIcons` value.
extension type const BeakIconToken(IconData icon) {}

/// One resource surfaced in the panel: a registered [BeakModel] plus its
/// navigation presentation and the typed actions and filters its generated
/// pages expose.
///
/// Declaring a resource is all it takes to get a full list/create/show/edit
/// CRUD surface — no per-page code. The built-in view, edit, delete and
/// create actions are always present; [recordActions], [bulkActions],
/// [globalActions] and [filters] add to them.
///
/// ```dart
/// BeakResource(
///   model: const ProductModel(),
///   icon: const BeakIconToken(OiIcons.package),
///   filters: const [
///     BeakSelectFilter(column: ProductColumns.status, label: 'Status'),
///     BeakTextFilter(column: ProductColumns.name, label: 'Name'),
///   ],
///   recordActions: const [
///     BeakRecordAction(
///       key: 'duplicate',
///       label: 'Duplicate',
///       icon: OiIcons.copy,
///       onExecute: duplicateProduct,
///     ),
///   ],
/// );
/// ```
class BeakResource {
  /// Creates a panel resource for [model], shown with [icon] and [label]
  /// (defaults to the title-cased table name).
  // --8<-- [start:BeakResource]
  const BeakResource({
    required this.model,
    this.icon = const BeakIconToken(OiIcons.database),
    this.title,
    this.navigationTitle,
    this.navigationGroup,
    this.navigationRank = 0,
    this.screens = const [],
    this.globalSearchSources = const [],
    this.label,
    this.section,
    this.recordActions = const [],
    this.bulkActions = const [],
    this.globalActions = const [],
    this.filters = const [],
    this.viewModes = const [BeakTableView()],
    this.detail,
    this.canCreate = true,
    this.canEdit = true,
    this.canDelete = true,
    this.canCreateWhen,
    this.canEditWhen,
    this.canDeleteWhen,
    this.visibleWhen,
    this.createModel,
    this.editModel,
    this.editValues,
    this.createBuilder,
    this.editBuilder,
    BeakFormValueMode? formValueMode,
    this.createFields = const [],
    this.editFields = const [],
    this.deleteAction = const BeakDeleteAction(),
    this.onActionError,
    this.filePicker,
    this.uploader,
    this.duplication,
  }) : _formValueMode = formValueMode;
  // --8<-- [end:BeakResource]

  /// Enables the standard Duplicate action with explicit owned-child copying.
  final BeakDuplicationSpec? duplication;

  /// Optional platform file chooser shared by the resource forms.
  final BeakFilePicker? filePicker;

  /// Optional upload transport; defaults to the resource data source.
  final BeakUploadClient? uploader;

  /// The model this resource exposes.
  final BeakModel model;

  /// Screen definitions inheriting this resource's model and data source.
  final List<BeakResourceScreen> screens;

  /// Typed fields searched by the panel command bar; empty uses model defaults.
  final List<BeakFieldRef<Object>> globalSearchSources;

  /// The configured screen for [role], or null for generated defaults.
  BeakResourceScreen? screenFor(BeakScreenRole role) {
    BeakResourceScreen? found;
    for (final screen in screens) {
      if (!screen.roles.contains(role)) continue;
      if (found != null) {
        throw BeakConfigurationException(
          'Resource "${model.table}" defines more than one ${role.name} screen.',
        );
      }
      found = screen;
    }
    return found;
  }

  /// Page title; defaults to the model's human-readable table name.
  final String? title;

  /// Sidebar title; defaults to [title] and then the inferred model name.
  final String? navigationTitle;

  /// Sidebar group. Takes precedence over the legacy [section] setting.
  final String? navigationGroup;

  /// Navigation order within the resource list. Ties retain declaration order.
  final int navigationRank;

  /// Label used in navigation independently of page titles.
  String get effectiveNavigationTitle => navigationTitle ?? effectiveLabel;

  /// Group used in navigation.
  String? get effectiveNavigationGroup => navigationGroup ?? section;

  /// The sidebar icon.
  final BeakIconToken icon;

  /// The navigation label override.
  final String? label;

  /// Optional sidebar group heading this resource is filed under.
  final String? section;

  /// Extra per-row actions on the list page (view/edit/delete are built
  /// in).
  final List<BeakRecordAction> recordActions;

  /// Actions over the list page's selection.
  final List<BeakBulkAction> bulkActions;

  /// Extra page-level list actions (create is built in).
  final List<BeakGlobalAction> globalActions;

  /// The list page's filter controls.
  final List<BeakFilterDef> filters;

  /// The list page's selectable presentations; defaults to a single table
  /// view. Declaring more than one adds a view-mode switcher to the list
  /// page.
  final List<BeakResourceView> viewModes;

  /// A custom show-page layout: a record-bound [BeakBlock] tree (cards,
  /// sections, tabs, grids composed of `BeakFieldBlock`/`BeakFieldGroupBlock`/
  /// `BeakRelationBlock`) rendered inside the loaded record's scope.
  ///
  /// When `null`, [effectiveDetail] derives one from the model: a headline
  /// card, the remaining fields, and a tab per to-many relationship.
  final BeakBlock? detail;

  /// Whether this resource exposes the corresponding write operation.
  /// These presentation capabilities do not replace server authorization.
  final bool canCreate;

  /// Whether the edit action and route are available.
  final bool canEdit;

  /// Whether the delete action is available.
  final bool canDelete;

  /// Live permission checks, reevaluated by actions and route guards.
  final bool Function()? canCreateWhen;

  /// Live permission check for edit.
  final bool Function()? canEditWhen;

  /// Live permission check for delete.
  final bool Function()? canDeleteWhen;

  /// Live read permission controlling navigation and all resource routes.
  final bool Function()? visibleWhen;

  /// Whether read access is currently available in the panel.
  bool get isVisible =>
      model.capabilities.contains(BeakOperation.read) &&
      model.permissions.allows(BeakOperation.read) &&
      (visibleWhen?.call() ?? true);

  /// Whether creation is currently available.
  bool get allowsCreate =>
      isVisible &&
      canCreate &&
      (model.capabilities.contains(BeakOperation.create) ||
          createBuilder != null) &&
      model.permissions.allows(BeakOperation.create) &&
      (canCreateWhen?.call() ?? true);

  /// Whether editing is currently available.
  bool get allowsEdit =>
      isVisible &&
      canEdit &&
      (model.capabilities.contains(BeakOperation.update) ||
          editBuilder != null) &&
      model.permissions.allows(BeakOperation.update) &&
      (canEditWhen?.call() ?? true);

  /// Whether deletion is currently available.
  bool get allowsDelete =>
      isVisible &&
      canDelete &&
      model.capabilities.contains(BeakOperation.delete) &&
      model.permissions.allows(BeakOperation.delete) &&
      (canDeleteWhen?.call() ?? true);

  /// Live availability of a built-in or configured resource action.
  /// Custom actions require read access and retain their own domain checks.
  bool allowsAction(BeakAction action) {
    if (identical(action, deleteAction)) return allowsDelete;
    return switch (action) {
      BeakCreateAction() => allowsCreate,
      BeakEditAction() => allowsEdit,
      BeakDeleteAction() || BeakArchiveAction() => allowsDelete,
      _ => isVisible,
    };
  }

  /// Command metadata for creation; defaults to [model].
  final BeakModel? createModel;

  /// Command metadata for editing; defaults to [model].
  final BeakModel? editModel;

  /// Loads an edit command when its shape differs from the read record.
  final Future<BeakRecord> Function(Object id)? editValues;

  /// Replaces the create form for a domain workflow such as checkout.
  final WidgetBuilder? createBuilder;

  /// Replaces the edit form while retaining the resource URL and shell.
  final Widget Function(BuildContext context, Object id)? editBuilder;

  /// Submission semantics shared by the resource's generated forms.
  BeakFormValueMode get formValueMode =>
      _formValueMode ??
      (model.createModel != null || model.editModel != null
          ? BeakFormValueMode.complete
          : BeakFormValueMode.populated);

  final BeakFormValueMode? _formValueMode;

  /// Create form presentation overrides over generated command fields.
  final List<BeakFormField> createFields;

  /// Edit form presentation overrides over generated command fields.
  final List<BeakFormField> editFields;

  /// Domain-specific deletion semantics, such as confirmed archival.
  final BeakRecordAction deleteAction;

  /// Host notification boundary for custom-action failures.
  final void Function(BeakException error)? onActionError;

  /// The label shown in navigation and page titles.
  String get effectiveLabel => title ?? label ?? _titleCase(model.table);

  /// The show-page layout: [detail] when declared, and otherwise the one
  /// [model] implies — a headline card, the remaining fields, and a tab per
  /// to-many relationship.
  BeakBlock get effectiveDetail => detail ?? beakDefaultDetailLayout(model);

  /// The filter bar the list page renders: [filters] when declared, and
  /// otherwise the controls [model]'s `filterable` columns imply.
  ///
  /// Deriving them here rather than in the generator keeps `panel.g.dart`
  /// unchanged and gives hand-written panels the same defaults.
  List<BeakFilterDef> get effectiveFilters =>
      filters.isNotEmpty ? filters : beakDefaultFiltersOf(model);

  /// Returns a copy with the given parts replaced.
  ///
  /// The way to adjust one generated resource without ejecting the panel:
  /// a `lib/resources/<table>.dart` returning `generated.copyWith(...)` keeps
  /// every other resource generated and up to date.
  ///
  /// ```dart
  /// BeakResource beakResource(BeakResource generated) => generated.copyWith(
  ///   filters: const [
  ///     BeakSelectFilter(column: OrderColumns.status, label: 'Status'),
  ///   ],
  /// );
  /// ```
  BeakResource copyWith({
    BeakFilePicker? filePicker,
    BeakUploadClient? uploader,
    BeakDuplicationSpec? duplication,
    BeakModel? model,
    String? title,
    String? navigationTitle,
    String? navigationGroup,
    int? navigationRank,
    List<BeakResourceScreen>? screens,
    List<BeakFieldRef<Object>>? globalSearchSources,
    BeakIconToken? icon,
    String? label,
    String? section,
    List<BeakRecordAction>? recordActions,
    List<BeakBulkAction>? bulkActions,
    List<BeakGlobalAction>? globalActions,
    List<BeakFilterDef>? filters,
    List<BeakResourceView>? viewModes,
    BeakBlock? detail,
    bool? canCreate,
    bool? canEdit,
    bool? canDelete,
    bool Function()? canCreateWhen,
    bool Function()? canEditWhen,
    bool Function()? canDeleteWhen,
    bool Function()? visibleWhen,
    BeakModel? createModel,
    BeakModel? editModel,
    Future<BeakRecord> Function(Object id)? editValues,
    WidgetBuilder? createBuilder,
    Widget Function(BuildContext context, Object id)? editBuilder,
    BeakFormValueMode? formValueMode,
    List<BeakFormField>? createFields,
    List<BeakFormField>? editFields,
    BeakRecordAction? deleteAction,
    void Function(BeakException error)? onActionError,
  }) => BeakResource(
    filePicker: filePicker ?? this.filePicker,
    uploader: uploader ?? this.uploader,
    duplication: duplication ?? this.duplication,
    model: model ?? this.model,
    title: title ?? this.title,
    navigationTitle: navigationTitle ?? this.navigationTitle,
    navigationGroup: navigationGroup ?? this.navigationGroup,
    navigationRank: navigationRank ?? this.navigationRank,
    screens: screens ?? this.screens,
    globalSearchSources: globalSearchSources ?? this.globalSearchSources,
    icon: icon ?? this.icon,
    label: label ?? this.label,
    section: section ?? this.section,
    recordActions: recordActions ?? this.recordActions,
    bulkActions: bulkActions ?? this.bulkActions,
    globalActions: globalActions ?? this.globalActions,
    filters: filters ?? this.filters,
    viewModes: viewModes ?? this.viewModes,
    detail: detail ?? this.detail,
    canCreate: canCreate ?? this.canCreate,
    canEdit: canEdit ?? this.canEdit,
    canDelete: canDelete ?? this.canDelete,
    canCreateWhen: canCreateWhen ?? this.canCreateWhen,
    canEditWhen: canEditWhen ?? this.canEditWhen,
    canDeleteWhen: canDeleteWhen ?? this.canDeleteWhen,
    visibleWhen: visibleWhen ?? this.visibleWhen,
    createModel: createModel ?? this.createModel,
    editModel: editModel ?? this.editModel,
    editValues: editValues ?? this.editValues,
    createBuilder: createBuilder ?? this.createBuilder,
    editBuilder: editBuilder ?? this.editBuilder,
    formValueMode: formValueMode ?? _formValueMode,
    createFields: createFields ?? this.createFields,
    editFields: editFields ?? this.editFields,
    deleteAction: deleteAction ?? this.deleteAction,
    onActionError: onActionError ?? this.onActionError,
  );

  /// The list route of this resource.
  String get route => BeakRoutes.list(model.table);

  static String _titleCase(String table) => table
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
