import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';

import '../form/beak_form_layout.dart';
import '../form/beak_form_drafts.dart';
import '../query/beak_list_definition.dart';
import '../presentation/beak_record_template.dart';

/// A conventional resource route supplied by a screen definition.
enum BeakScreenRole {
  /// Browse and search resource records.
  list,

  /// Inspect an existing record.
  read,

  /// Create a new record and its relationships.
  create,

  /// Update an existing record.
  edit,
}

/// Presentation owned by a resource; its model and transport are inherited.
abstract class BeakResourceScreen {
  /// Creates a screen for the supplied route roles.
  const BeakResourceScreen({required this.roles});

  /// Resource routes rendered by this screen.
  final Set<BeakScreenRole> roles;
}

/// One reusable layout for reading, creating, and editing a resource.
class BeakFormScreen extends BeakResourceScreen {
  /// Omitting [layout] derives the form from the resource's model.
  const BeakFormScreen({
    this.layout,
    this.steps = const [],
    this.drafts,
    this.reviewBeforeSave = false,
    this.showInspector = false,
    this.header,
    this.recordHeader,
    this.aside,
    this.asideFooter,
    this.asideWidth = 360,
    this.asideFraction,
    this.footer,
    this.fullScreen = false,
    this.navigation = BeakWizardNavigation.inline,
    this.navigationDescription,
    this.submitAction,
    this.submitLabel,
    this.submitIcon,
    this.outlinedCancel = false,
    this.showActionsWhileEditing = true,
    this.editLabel,
    this.editingLabel,
    this.prominentEdit = false,
    this.compactActions = false,
    this.showChangeBar = false,
    this.showBack = true,
    this.pagePadding,
    this.pageGap,
    super.roles = const {BeakScreenRole.create, BeakScreenRole.edit},
  });

  /// Optional model command used by the final primary submission.
  final BeakModelAction? submitAction;

  /// Optional primary action label, otherwise the model command or Save/Finish.
  final String? submitLabel;

  /// Optional icon for the heading's primary submission control.
  final IconData? submitIcon;

  /// Gives the existing-record Cancel control an outlined surface.
  final bool outlinedCancel;

  /// Keeps standalone model actions available while an existing record edits.
  final bool showActionsWhileEditing;

  /// Optional label for switching a shared read view into editing.
  final String? editLabel;

  /// Optional title annotation displayed while an existing record is edited.
  final String? editingLabel;

  /// Promotes Edit to the primary visual action in read mode.
  final bool prominentEdit;

  /// Shows secondary commands in a named icon menu after the primary action.
  final bool compactActions;

  /// Pins a draft change count, validation feedback and save/discard controls.
  final bool showChangeBar;

  /// Whether generated page chrome includes its separate Back button.
  final bool showBack;

  /// Optional outer page insets and spacing; defaults preserve standard chrome.
  final EdgeInsetsGeometry? pagePadding;

  /// Space between generated page heading and content.
  final double? pageGap;

  /// Declarative regions observing the same form draft.
  final BeakFormNode? header, aside, footer;

  /// Supporting content pinned below the aside, using the same draft.
  final BeakFormNode? asideFooter;

  /// Width of the supporting column before it collapses into a sheet.
  final double asideWidth;

  /// Optional share of desktop content width after the gap; compact sheets use
  /// [asideWidth]. For example, one third yields a two-to-one page layout.
  final double? asideFraction;

  /// Live record identity, metadata and badges in the standard page heading.
  final BeakRecordTemplate? recordHeader;

  /// Gives a workflow the full protected route surface, retaining authentication.
  final bool fullScreen;

  /// Controlled presentation of wizard step navigation.
  final BeakWizardNavigation navigation;

  /// Supporting guidance below desktop wizard steps.
  final String? navigationDescription;

  /// Optional scoped local draft persistence.
  final BeakFormDrafts? drafts;

  /// Shows the proposed changes before final submission.
  final bool reviewBeforeSave;

  /// Enables development diagnostics on this screen.
  final bool showInspector;

  /// Field and layout declarations. Null selects the model defaults.
  final BeakFormLayout? layout;

  /// Optional wizard presentation over the same form session.
  final List<BeakWizardStep> steps;
}

/// A resource form presented as automatically validated wizard steps.
class BeakWizardScreen extends BeakFormScreen {
  /// Creates a wizard whose values remain drafts until the final submission.
  const BeakWizardScreen({
    required super.steps,
    super.drafts,
    super.reviewBeforeSave,
    super.showInspector,
    super.header,
    super.recordHeader,
    super.aside,
    super.asideFooter,
    super.asideWidth,
    super.footer,
    super.fullScreen,
    super.navigation,
    super.navigationDescription,
    super.submitAction,
    super.submitLabel,
    super.editLabel,
    super.prominentEdit,
    super.compactActions,
    super.showBack,
    super.pagePadding,
    super.pageGap,
    super.roles = const {BeakScreenRole.create, BeakScreenRole.edit},
  });
}

/// A resource list with explicitly positioned typed fields and a base query.
class BeakTableScreen extends BeakResourceScreen {
  /// Null [fields] retains the model's generated table presentation.
  const BeakTableScreen({this.fields, this.query, this.definition})
    : super(roles: const {BeakScreenRole.list});

  /// Scalar field references, including related paths, in display order.
  final List<BeakScalarField<Object>>? fields;

  /// Initial sort, pagination, and permanent filtering for this screen.
  final BeakQuerySpec? query;

  /// Optional composed list with presets, a shared query and typed cells.
  final BeakListDefinition? definition;
}

/// An application-specific widget replacing one or more standard routes.
class BeakCustomResourceScreen extends BeakResourceScreen {
  /// Creates a custom screen while retaining resource routing and permissions.
  const BeakCustomResourceScreen({required this.builder, required super.roles});

  /// Builds the custom surface. Record routes receive their identifier.
  final Widget Function(BuildContext context, Object? recordId) builder;
}
