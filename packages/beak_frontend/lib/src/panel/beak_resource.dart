import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

import '../actions/beak_action.dart';
import '../filters/beak_default_filters.dart';
import '../filters/beak_filter_widget.dart';
import '../form/upload_field.dart';
import 'beak_destination.dart';
import 'beak_resource_screen.dart';
import 'beak_routes.dart';

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
/// create actions are always present; [recordActions], [bulkActions],
/// [globalActions] and [filters] add to them. What the current account may
/// see or change follows [BeakModel.permissions], and [screens] replace any of
/// the generated pages.
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

  /// Whether read access is currently available in the panel.
  ///
  /// Reads [BeakModel.permissions], so a schema class declaring
  /// `static BeakPermissions get permissions` controls navigation and every
  /// resource route.
  bool get isVisible =>
      model.capabilities.contains(BeakOperation.read) &&
      model.permissions.allows(BeakOperation.read);

  /// Whether creation is currently available: the model supports it or a
  /// custom create screen supplies the workflow, [canCreate] is set and
  /// [BeakModel.permissions] allow it.
  bool get allowsCreate =>
      isVisible &&
      canCreate &&
      (model.capabilities.contains(BeakOperation.create) ||
          _hasCustomScreen(BeakScreenRole.create)) &&
      model.permissions.allows(BeakOperation.create);

  /// Whether editing is currently available: the model supports it or a
  /// custom edit screen supplies the workflow, [canEdit] is set and
  /// [BeakModel.permissions] allow it.
  bool get allowsEdit =>
      isVisible &&
      canEdit &&
      (model.capabilities.contains(BeakOperation.update) ||
          _hasCustomScreen(BeakScreenRole.edit)) &&
      model.permissions.allows(BeakOperation.update);

  /// Whether deletion is currently available.
  bool get allowsDelete =>
      isVisible &&
      canDelete &&
      model.capabilities.contains(BeakOperation.delete) &&
      model.permissions.allows(BeakOperation.delete);

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
