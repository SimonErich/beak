import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../actions/beak_action.dart';
import '../form/beak_form_layout.dart';
import '../presentation/beak_record_template.dart';
import '../query/beak_list_defaults.dart';
import '../filters/beak_default_filters.dart';
import '../filters/beak_filter_widget.dart';
import '../form/upload_field.dart';
import 'beak_destination.dart';
import 'beak_panel_access.dart';
import 'beak_resource_screen.dart';
import 'beak_routes.dart';
import 'beak_standard_resource.dart';

/// A typed icon reference for panel navigation.
///
/// A zero-cost wrapper over [IconData] so resource declarations stay
/// expressive (`BeakIconToken(OiIcons.package)`) without leaking raw icon
/// plumbing into Beak's config surface. Wrap any obers_ui `OiIcons` value.
// --8<-- [start:BeakIconToken]
extension type const BeakIconToken(IconData icon) {}
// --8<-- [end:BeakIconToken]

/// One resource surfaced in the panel: a registered [BeakModel] plus its
/// navigation presentation and the typed actions and filters its generated
/// pages expose.
///
/// Declaring a resource is all it takes to get a full list/create/show/edit
/// CRUD surface — no per-page code. The built-in view, edit, delete and
/// create actions appear where [canCreate], [canEdit], [canDelete], the
/// model's permissions and the server's capabilities allow them, and
/// [recordActions], [bulkActions], [globalActions] and [filters] add to them.
/// What the current account may see or change follows
/// [BeakModel.permissions], and [screens] replace any of the generated pages.
///
/// ```dart
/// BeakResource(
///   model: const ProductModel(),
///   icon: const BeakIconToken(OiIcons.package),
///   filters: [
///     ProductModel.status.selectFilter(label: 'Status'),
///     ProductModel.name.textFilter(label: 'Name'),
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
class BeakResource implements BeakDestination {
  /// Creates a panel resource for [model], shown with [icon] and [title]
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
    this.recordActions = const [],
    this.bulkActions = const [],
    this.globalActions = const [],
    this.filters = const [],
    this.canCreate = true,
    this.canEdit = true,
    this.canDelete = true,
    this.deleteAction = const BeakDeleteAction(),
    this.onActionError,
    this.filePicker,
    this.uploader,
    this.duplication,
  });
  // --8<-- [end:BeakResource]

  /// The conventional resource: a list, a detail page and the create/edit
  /// forms, with the panel's list defaults and a metadata aside.
  ///
  /// [columns] and [form] default to the model's own table and form fields, so
  /// the shortest declaration is:
  ///
  /// ```dart
  /// BeakResource.standard(const ProductModel(), 'Products')
  /// ```
  ///
  /// [tabs] replace the single form card with a General tab plus one tab per
  /// [BeakTab]. A [readOnly] resource offers reads only, whatever its model's
  /// permissions would allow: the server still enforces its own policy.
  factory BeakResource.standard(
    BeakModel model,
    String title, {
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
    List<BeakRecordAction> recordActions = const [],
    List<BeakBulkAction> bulkActions = const [],
    List<BeakGlobalAction> globalActions = const [],
  }) => buildStandardResource(
    model,
    title,
    icon: icon,
    navigationTitle: navigationTitle,
    navigationGroup: navigationGroup,
    navigationRank: navigationRank,
    columns: columns,
    form: form,
    tabs: tabs,
    filters: filters,
    header: header,
    readOnly: readOnly,
    defaults: defaults,
    recordActions: recordActions,
    bulkActions: bulkActions,
    globalActions: globalActions,
  );

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

  /// Sidebar group heading this resource is filed under.
  final String? navigationGroup;

  /// Navigation order within the resource list. Ties retain declaration order.
  final int navigationRank;

  /// Label used in navigation independently of page titles.
  String get effectiveNavigationTitle => navigationTitle ?? effectiveLabel;

  /// The sidebar icon.
  final BeakIconToken icon;

  /// Extra per-row actions on the list page (view/edit/delete are built
  /// in).
  final List<BeakRecordAction> recordActions;

  /// Actions over the list page's selection.
  final List<BeakBulkAction> bulkActions;

  /// Extra page-level list actions (create is built in).
  final List<BeakGlobalAction> globalActions;

  /// The list page's filter controls.
  final List<BeakFilterDef> filters;

  /// Whether this resource exposes the corresponding write operation.
  /// These presentation capabilities do not replace server authorization;
  /// account-dependent checks belong on [BeakModel.permissions].
  final bool canCreate;

  /// Whether the edit action and route are available.
  final bool canEdit;

  /// Whether the delete action is available.
  final bool canDelete;

  /// Whether a [BeakCustomResourceScreen] serves [role], supplying a workflow
  /// the model's transport does not expose as a standard operation.
  bool _hasCustomScreen(BeakScreenRole role) => screens.any(
    (screen) =>
        screen is BeakCustomResourceScreen && screen.roles.contains(role),
  );

  /// Whether [access] may list and open this resource: the model supports
  /// reading and its [BeakModel.permissions] admit the account.
  ///
  /// Navigation, the command bar and the resource routes ask this, so a
  /// schema class declaring `permissions` controls what each role sees.
  bool isVisibleTo(BeakPanelAccess access) => access.canRead(model);

  /// Whether [access] may create records here: the model supports it or a
  /// custom create screen supplies the workflow, [canCreate] is set and the
  /// permissions admit the account.
  bool allowsCreateTo(BeakPanelAccess access) =>
      isVisibleTo(access) &&
      canCreate &&
      (model.capabilities.contains(BeakOperation.create) ||
          _hasCustomScreen(BeakScreenRole.create)) &&
      access.permits(model, BeakOperation.create);

  /// Whether [access] may edit records here: the model supports it or a custom
  /// edit screen supplies the workflow, [canEdit] is set and the permissions
  /// admit the account.
  bool allowsEditTo(BeakPanelAccess access) =>
      isVisibleTo(access) &&
      canEdit &&
      (model.capabilities.contains(BeakOperation.update) ||
          _hasCustomScreen(BeakScreenRole.edit)) &&
      access.permits(model, BeakOperation.update);

  /// Whether [access] may delete records here.
  bool allowsDeleteTo(BeakPanelAccess access) =>
      isVisibleTo(access) &&
      canDelete &&
      access.can(model, BeakOperation.delete);

  /// Whether [access] may use [action] on this resource.
  ///
  /// The built-in create, edit and delete actions follow their operations.
  /// A global action that declares `visibleWhen` follows it. Any other action
  /// needs read access and keeps its own domain checks.
  bool allowsActionTo(BeakPanelAccess access, BeakAction action) {
    if (identical(action, deleteAction)) return allowsDeleteTo(access);
    return switch (action) {
      BeakCreateAction() => allowsCreateTo(access),
      BeakEditAction() => allowsEditTo(access),
      BeakDeleteAction() || BeakArchiveAction() => allowsDeleteTo(access),
      BeakGlobalAction(:final visibleWhen?) =>
        isVisibleTo(access) && visibleWhen(access),
      _ => isVisibleTo(access),
    };
  }

  /// Domain-specific deletion semantics, such as confirmed archival.
  final BeakRecordAction deleteAction;

  /// Host notification boundary for custom-action failures.
  final void Function(BeakException error)? onActionError;

  /// The label shown in navigation and page titles.
  String get effectiveLabel => title ?? _titleCase(model.table);

  /// The filter bar the list page renders: [filters] when declared, and
  /// otherwise the controls [model]'s `filterable` columns imply.
  List<BeakFilterDef> get effectiveFilters =>
      filters.isNotEmpty ? filters : beakDefaultFiltersOf(model);

  /// Returns a copy with the given parts replaced.
  ///
  /// The way to adjust one resource without redeclaring it, for example the
  /// `BeakResource` subclass `beak eject resource <table>` writes for a model:
  ///
  /// ```dart
  /// final staffOrders = orders.copyWith(
  ///   filters: [OrderModel.status.selectFilter(label: 'Status')],
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
    List<BeakRecordAction>? recordActions,
    List<BeakBulkAction>? bulkActions,
    List<BeakGlobalAction>? globalActions,
    List<BeakFilterDef>? filters,
    bool? canCreate,
    bool? canEdit,
    bool? canDelete,
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
    recordActions: recordActions ?? this.recordActions,
    bulkActions: bulkActions ?? this.bulkActions,
    globalActions: globalActions ?? this.globalActions,
    filters: filters ?? this.filters,
    canCreate: canCreate ?? this.canCreate,
    canEdit: canEdit ?? this.canEdit,
    canDelete: canDelete ?? this.canDelete,
    deleteAction: deleteAction ?? this.deleteAction,
    onActionError: onActionError ?? this.onActionError,
  );

  /// The list route of this resource.
  String get route => BeakRoutes.list(model.table);

  @override
  String get location => route;

  static String _titleCase(String table) => table
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
