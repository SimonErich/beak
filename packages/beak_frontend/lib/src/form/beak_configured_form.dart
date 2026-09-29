import 'beak_gallery.dart';
import 'dart:math' as math;
import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_autoforms/obers_ui_autoforms.dart';
import 'package:signals/signals_flutter.dart';

import '../localization/beak_localizations.dart';
import '../actions/beak_uri_action.dart';
import '../overlays/beak_overlays.dart';
import '../data/beak_data_changes.dart';
import '../presentation/beak_record_template.dart';
import '../presentation/beak_record_timeline.dart';
import '../di/beak_locator.dart';
import '../panel/beak_panel_config.dart';
import '../panel/beak_resource_screen.dart';
import '../table/column_cell_renderer.dart';
import 'beak_form_controller_builder.dart';
import 'beak_form_layout.dart';
import 'beak_form_session.dart';
import 'beak_form_drafts.dart';
import 'beak_currency_field.dart';
import '../formatting/beak_formatting.dart';
import 'field_widget_mapper.dart';
import 'beak_value_input.dart';
import 'beak_attribute_input.dart';
import 'beak_input_presentation.dart';
import 'beak_object_view.dart';
import 'beak_stored_image.dart';
import 'upload_field.dart';

/// A form/detail/wizard host with automatic loading, state, validation and saves.
class BeakConfiguredForm extends HookWidget {
  /// Renders one configured form, detail view or wizard.
  const BeakConfiguredForm({
    required this.model,
    required this.dataSource,
    this.layout,
    this.steps = const [],
    this.recordId,
    this.initialValues,
    this.mode = BeakFormMode.edit,
    this.registry,
    this.onSaved,
    this.onClose,
    this.frameBuilder,
    this.recordHeader,
    this.editValues,
    this.valueMode = BeakFormValueMode.populated,
    this.onSession,
    this.uploader,
    this.filePicker,
    this.canEdit = true,
    this.drafts,
    this.reviewBeforeSave = false,
    this.showInspector = false,
    this.header,
    this.aside,
    this.asideFooter,
    this.asideWidth = 360,
    this.asideFraction,
    this.footer,
    this.navigation = BeakWizardNavigation.inline,
    this.navigationDescription,
    this.submitAction,
    this.submitLabel,
    this.submitIcon,
    this.outlinedCancel = false,
    this.showActionsWhileEditing = true,
    this.editLabel,
    this.prominentEdit = false,
    this.compactActions = false,
    this.showChangeBar = false,
    super.key,
  });

  /// Typed page identity whose dependencies load through this same session.
  /// The enclosing page frame owns its placement.
  final BeakRecordTemplate? recordHeader;

  /// Optional nonwizard frame, using this session's existing controls and body.
  /// The current mode follows in-place Edit/Cancel transitions. The child
  /// retains configured regions; actions must be placed exactly once.
  final Widget Function(
    BuildContext context,
    BeakFormSession session,
    BeakFormMode mode,
    Widget actions,
    Widget child,
  )?
  frameBuilder;

  /// Model command executed by the final primary action, or ordinary save.
  final String? submitAction;

  /// Optional primary button label.
  final String? submitLabel;

  /// Optional icon for the nonwizard primary submission control.
  final IconData? submitIcon;

  /// Draws an outline around the existing-record Cancel control.
  final bool outlinedCancel;

  /// Whether model commands remain available in an existing-record edit.
  final bool showActionsWhileEditing;

  /// Supporting guidance below the rail wizard's desktop navigation.
  final String? navigationDescription;

  /// Label and visual emphasis of the read view's Edit control.
  final String? editLabel;

  /// Promotes the read view Edit control to the primary visual action.
  final bool prominentEdit;

  /// Moves secondary commands into a named icon menu after the primary action.
  final bool compactActions;

  /// Pins a draft change count, validation feedback and save/discard controls.
  final bool showChangeBar;

  /// Declarative regions rendered against the same automatic draft.
  final BeakFormNode? header, aside, footer;

  /// Supporting content pinned below the aside's independent scroll region.
  final BeakFormNode? asideFooter;

  /// Width of the supporting column before it collapses into a sheet.
  final double asideWidth;

  /// Optional share of desktop content width after the gap; compact sheets use
  /// [asideWidth]. For example, one third yields a two-to-one page layout.
  final double? asideFraction;

  /// Controlled step navigation presentation.
  final BeakWizardNavigation navigation;

  /// Optional scoped storage for resuming unfinished forms.
  final BeakFormDrafts? drafts;

  /// Requires reviewing the proposed graph changes before submission.
  final bool reviewBeforeSave;

  /// Shows configuration diagnostics intended for development environments.
  final bool showInspector;

  /// Upload transport; defaults to the data source when supported.
  final BeakUploadClient? uploader;

  /// Optional platform file picker for upload inputs.
  final BeakFilePicker? filePicker;

  /// Whether the read view offers an Edit action.
  final bool canEdit;

  /// Model metadata defining fields, rules and relationships.
  final BeakModel model;

  /// Transport used automatically for loading, searching and saving.
  final BeakDataSource dataSource;

  /// Reusable layout declaring the visible inputs and sections.
  final BeakFormLayout? layout;

  /// Ordered wizard steps; empty for a single-page form.
  final List<BeakWizardStep> steps;

  /// Existing record identity to load, or null when creating.
  final Object? recordId;

  /// Initial graph for creation, including a configured record duplication.
  final BeakRecord? initialValues;

  /// Initial presentation mode of this form.
  final BeakFormMode mode;

  /// Model registry used to resolve related drafts and save operations.
  final BeakModelRegistry? registry;

  /// Called only after every operation in the graph has been confirmed applied.
  final void Function(BeakRecord record)? onSaved;

  /// Resource navigation invoked after the ordinary unsaved-change guard.
  final VoidCallback? onClose;

  /// Optional source-specific edit command loader.
  final Future<BeakRecord> Function(Object id)? editValues;

  /// Whether submitted scalar commands contain populated, changed or all fields.
  final BeakFormValueMode valueMode;

  /// Optional escape hatch exposing the mounted automatic form session.
  final void Function(BeakFormSession session)? onSession;

  @override
  Widget build(BuildContext context) {
    final dependencies = beakDependencies(context);
    final panel = dependencies.isRegistered<BeakPanelConfig>()
        ? dependencies<BeakPanelConfig>()
        : null;
    final relatedLayouts = useMemoized(
      () => <String, BeakFormLayout>{
        for (final resource in panel?.resources ?? const <BeakResource>[])
          if (resource.screenFor(BeakScreenRole.create)
              case final BeakFormScreen screen)
            if (screen.layout != null || screen.steps.isNotEmpty)
              resource.model.table:
                  screen.layout ?? BeakFormLayout(children: screen.steps),
      },
      [panel],
    );
    final session = useMemoized(
      () => BeakFormSession(
        model: model,
        dataSource: dataSource,
        layout: layout,
        steps: steps,
        regions: [
          ?header,
          ?aside,
          ?asideFooter,
          ?footer,
          if (recordHeader != null) BeakFormTemplate(template: recordHeader!),
        ],
        recordId: recordId,
        initialValues: initialValues,
        relatedLayouts: relatedLayouts,
        registry: registry,
        valueMode: valueMode,
        editValues: editValues,
        uploader: uploader,
        filePicker: filePicker,
        drafts: drafts,
      ),
      [
        model,
        dataSource,
        layout,
        steps,
        header,
        aside,
        asideFooter,
        footer,
        recordId,
        recordHeader,
        initialValues,
        relatedLayouts,
        registry,
        valueMode,
        editValues,
        uploader,
        filePicker,
        drafts,
      ],
    );
    final errorAnchors = useMemoized(_FormErrorRegistry.new, [session]);
    final router = GoRouter.maybeOf(context);
    final completedSteps = useState(<int>{});
    final rootTabs =
        layout?.children.length == 1 && layout!.children.single is BeakTabs
        ? layout!.children.single as BeakTabs
        : null;
    final sharedTabs = rootTabs?.acrossRegions == true ? rootTabs : null;
    final sharedTabIndex = useState(sharedTabs?.initialIndex ?? 0);
    final displayMode = useState(mode);
    useEffect(() {
      session.load();
      onSession?.call(session);
      if (router != null) {
        _mountedForms.putIfAbsent(router, () => {}).add(session);
      }
      return () {
        _mountedForms[router]?.remove(session);
        if (_mountedForms[router]?.isEmpty ?? false) {
          _mountedForms.remove(router);
        }
        session.dispose();
      };
    }, [session, router]);
    final strings = BeakLocalizations.of(context);
    return Watch.builder(
      key: ObjectKey(session),
      builder: (context) {
        session.revision.value;
        final busy = session.submitting.value;
        final readOnly = displayMode.value == BeakFormMode.read;
        if (session.loading.value) return OiLabel.body(strings.loading);
        if (!session.initialized) {
          return OiColumn(
            breakpoint: context.breakpoint,
            children: [
              OiEmptyState.error(
                description: session.error.value?.message ?? strings.loading,
              ),
              OiButton.secondary(label: strings.retry, onTap: session.load),
            ],
          );
        }
        final receipt = session.saveResult.value;
        final primaryAction = submitAction == null
            ? null
            : model.behavior.actions.firstWhere(
                (action) => action.name == submitAction,
                orElse: () => throw BeakConfigurationException(
                  'Unknown submit action: $submitAction.',
                ),
              );
        Future<void> finish() async {
          if (reviewBeforeSave) {
            if (!await session.validate() || !context.mounted) return;
            if (await showBeakFormReview(context, session) != true ||
                !context.mounted) {
              return;
            }
          }
          final BeakSaveResult? result;
          if (primaryAction == null) {
            result = await session.save();
          } else {
            if (!session.canExecuteAction(primaryAction)) return;
            final arguments = primaryAction.inputModel == null
                ? const BeakRecord(values: {})
                : session.hasActionInput(primaryAction.name)
                ? await session.actionArguments(primaryAction.name)
                : await showBeakActionInput(context, session, primaryAction);
            if (arguments == null || !context.mounted) return;
            result = await session.executeAction(
              primaryAction.name,
              arguments: arguments,
            );
          }
          if (!context.mounted) return;
          if (result?.complete == true && !session.isDirty) {
            session.allowExit();
            if (onSaved != null) {
              onSaved!(result?.rootRecord ?? session.root.snapshot);
            } else {
              displayMode.value = BeakFormMode.read;
            }
          } else if (steps.isNotEmpty) {
            for (var i = 0; i < steps.length; i++) {
              if (!await session.validateStep(i)) {
                await session.goToStep(i);
                break;
              }
            }
          }
        }

        final content = steps.isEmpty
            ? (session.regions.isEmpty
                  ? session.root.layout
                  : session.root.layout.children.first)
            : steps[session.currentStep.clamp(0, steps.length - 1)];
        Widget region(
          BeakFormNode node, {
          bool compact = false,
        }) => Watch.builder(
          builder: (context) {
            // A compact region may live in an overlay after the page builds.
            // It keeps observing the same draft while that sheet is open.
            session.revision.value;
            return _FormRegionScope(
              compactHeadings: compact,
              child: _FormNodeView(
                node: node,
                draft: session.root,
                readOnly: readOnly,
              ),
            );
          },
        );
        final currentStep = steps.isEmpty ? null : steps[session.currentStep];
        final stepHeader =
            currentStep == null || navigation != BeakWizardNavigation.rail
            ? null
            : OiColumn(
                breakpoint: context.breakpoint,
                crossAxisAlignment: CrossAxisAlignment.start,
                gap: const OiResponsive<double>(4),
                children: [
                  OiLabel.caption(
                    'Step ${session.currentStep + 1} of ${steps.length}',
                  ),
                  OiLabel.h2(currentStep.heading ?? currentStep.title),
                  if (currentStep.introductionBuilder?.call(
                            BeakFormReader(session.root),
                            BeakFormatting.of(context),
                          ) ??
                          currentStep.introduction ??
                          currentStep.description
                      case final String introduction)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: OiLabel.body(
                        introduction,
                        color: context.colors.textMuted,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ),
                ],
              );
        final body = OiColumn(
          breakpoint: context.breakpoint,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          gap: OiResponsive<double>(
            navigation == BeakWizardNavigation.rail ? 4 : 16,
          ),
          children: [
            if (session.root.validating)
              const OiLabel.caption('Checking values…'),
            if (session.error.value case final BeakException error) ...[
              OiBanner.error(message: error.message, dismissible: false),
              if (session.root.id != null && !session.hasUnknown)
                OiButton.secondary(
                  label: 'Compare with latest version',
                  onTap: busy ? null : session.refreshForConflicts,
                ),
            ],
            if (session.draftNotice case final String notice)
              OiBanner.info(message: notice, dismissible: false),
            if (session.hasStoredDraft)
              OiCard(
                title: const OiLabel.h4('An unfinished draft is available'),
                child: Wrap(
                  spacing: context.spacing.sm,
                  runSpacing: context.spacing.sm,
                  children: [
                    OiButton.secondary(
                      label: 'Resume draft',
                      onTap: session.resumeDraft,
                    ),
                    OiButton.ghost(
                      label: 'Discard saved draft',
                      onTap: session.discardStoredDraft,
                    ),
                  ],
                ),
              ),
            for (final conflict in session.conflicts)
              OiCard(
                title: OiLabel.h4(conflict.label),
                child: OiColumn(
                  breakpoint: context.breakpoint,
                  children: [
                    OiLabel.body(
                      'Your draft: ${_reviewValue(context, conflict.column, conflict.local)}',
                    ),
                    OiLabel.body(
                      'Latest version: ${_reviewValue(context, conflict.column, conflict.remote)}',
                    ),
                    OiRow(
                      breakpoint: context.breakpoint,
                      children: [
                        OiButton.secondary(
                          label: 'Keep draft',
                          onTap: () => session.resolveConflict(
                            conflict.path,
                            useRemote: false,
                          ),
                        ),
                        OiButton.secondary(
                          label: 'Use latest',
                          onTap: () => session.resolveConflict(
                            conflict.path,
                            useRemote: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (receipt != null && !receipt.complete) ...[
              OiBanner.warning(
                message: session.hasUnknown
                    ? 'Some save results are unknown. Check the save status before continuing.'
                    : '${receipt.outcomes.where((outcome) => outcome.status == BeakWriteOutcome.applied).length} changes saved. The remaining changes still need attention.',
                dismissible: false,
              ),
              for (final outcome in receipt.outcomes)
                if (outcome.status != BeakWriteOutcome.applied &&
                    outcome.error != null)
                  OiLabel.body(outcome.error!.message),
              if (session.hasUnknown)
                OiButton.secondary(
                  label: 'Check save status',
                  onTap: busy ? null : session.recover,
                ),
            ],
            if (steps.isNotEmpty &&
                navigation != BeakWizardNavigation.rail) ...[
              OiLabel.h4(
                '${session.currentStep + 1} / ${steps.length} — ${steps[session.currentStep].title}',
              ),
              if (steps[session.currentStep].description
                  case final String description)
                OiLabel.body(description),
            ],
            // Keep transient validation/status siblings outside the editable
            // semantics group. On web, reordering focused input DOM nodes can
            // interrupt typing even while their Flutter FocusNode survives.
            Semantics(
              container: true,
              explicitChildNodes: true,
              child: _FormNodeView(
                node: content,
                draft: session.root,
                readOnly: readOnly,
                sharedTabs: sharedTabs,
                sharedTabIndex: sharedTabIndex,
              ),
            ),
          ],
        );
        final externalFrame = steps.isEmpty && frameBuilder != null;
        final commandNames = [
          for (final action in model.behavior.actions)
            if (action.name != submitAction &&
                !_actionPlaced(
                  session.root.layout,
                  action.name,
                  session.root,
                ) &&
                session.canExecuteAction(action))
              action.name,
        ];
        final commands = _ModelActions(
          draft: session.root,
          compact: externalFrame || compactActions,
          iconOnly: compactActions,
          names: commandNames,
        );
        final actionWidgets = <Widget>[
          if (footer != null && !externalFrame) region(footer!),
          if (commandNames.isNotEmpty &&
              (readOnly ||
                  session.root.id == null ||
                  showActionsWhileEditing) &&
              !compactActions &&
              (steps.isEmpty || session.currentStep == steps.length - 1))
            commands,
          if (!showChangeBar &&
              !readOnly &&
              session.isDirty &&
              navigation != BeakWizardNavigation.rail)
            OiButton.ghost(
              label: 'Review changes',
              onTap: () => showBeakFormReview(context, session),
            ),
          if (showInspector)
            OiButton.ghost(
              label: 'Inspect form',
              onTap: () => showBeakFormInspector(context, session),
            ),
          if (readOnly &&
              canEdit &&
              (model.behavior.editableWhen?.call(session.root.initialRecord) ??
                  true))
            prominentEdit
                ? OiButton.primary(
                    label: editLabel ?? strings.edit,
                    icon: OiIcons.pencil,
                    onTap: () => displayMode.value = BeakFormMode.edit,
                  )
                : OiButton.secondary(
                    label: editLabel ?? strings.edit,
                    onTap: () => displayMode.value = BeakFormMode.edit,
                  )
          else if (!readOnly)
            OiRow(
              breakpoint: context.breakpoint,
              mainAxisSize: navigation == BeakWizardNavigation.rail
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                if (steps.isEmpty && session.root.id != null) ...[
                  (outlinedCancel ? OiButton.outline : OiButton.ghost)(
                    label: 'Cancel',
                    onTap: busy || session.hasStoredDraft
                        ? null
                        : () async {
                            if (!await beakConfirmFormExit(
                                  context,
                                  session: session,
                                ) ||
                                !context.mounted) {
                              return;
                            }
                            await session.discardChanges();
                            if (context.mounted) {
                              displayMode.value = BeakFormMode.read;
                            }
                          },
                  ),
                  const SizedBox(width: 8),
                ],
                if (steps.isNotEmpty &&
                    session.currentStep == 0 &&
                    onClose != null)
                  OiButton.ghost(
                    label: 'Cancel',
                    onTap: busy
                        ? null
                        : () async {
                            if (await beakConfirmFormExit(
                                  context,
                                  session: session,
                                ) &&
                                context.mounted) {
                              onClose!();
                            }
                          },
                  ),
                if (steps.isNotEmpty && session.currentStep > 0)
                  OiButton.secondary(
                    icon: navigation == BeakWizardNavigation.rail
                        ? OiIcons.arrowLeft
                        : null,
                    label: navigation == BeakWizardNavigation.rail
                        ? 'Back'
                        : 'Previous',
                    onTap: busy
                        ? null
                        : () => session.goToStep(session.currentStep - 1),
                  ),
                if (navigation == BeakWizardNavigation.rail)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            constraints.maxWidth < 85
                            ? const SizedBox.shrink()
                            : Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: OiLabel.caption(
                                  steps[session.currentStep].footerHintBuilder
                                          ?.call(
                                            BeakFormReader(session.root),
                                            BeakFormatting.of(context),
                                          ) ??
                                      steps[session.currentStep].footerHint ??
                                      'Step ${session.currentStep + 1} of ${steps.length}',
                                ),
                              ),
                      ),
                    ),
                  ),
                if (steps.isNotEmpty && session.currentStep < steps.length - 1)
                  OiButton.primary(
                    icon: navigation == BeakWizardNavigation.rail
                        ? OiIcons.arrowRight
                        : null,
                    iconPosition: OiIconPosition.trailing,
                    label:
                        steps[session.currentStep].continueLabel ??
                        (navigation == BeakWizardNavigation.rail
                            ? 'Continue'
                            : 'Next'),
                    onTap: busy || session.hasStoredDraft
                        ? null
                        : () async {
                            final previous = session.currentStep;
                            if (await session.goToStep(previous + 1) &&
                                context.mounted) {
                              completedSteps.value = {
                                ...completedSteps.value,
                                previous,
                              };
                            }
                          },
                  )
                else
                  OiButton.primary(
                    label: busy
                        ? strings.saving
                        : receipt != null && !receipt.complete
                        ? 'Save remaining changes'
                        : submitLabel ??
                              primaryAction?.label ??
                              (steps.isEmpty ? strings.save : 'Finish'),
                    icon:
                        submitIcon ??
                        (navigation == BeakWizardNavigation.rail
                            ? OiIcons.check
                            : null),
                    onTap:
                        busy ||
                            session.hasUnknown ||
                            session.conflicts.isNotEmpty ||
                            (primaryAction != null &&
                                !session.canExecuteAction(primaryAction))
                        ? null
                        : finish,
                  ),
              ],
            ),
          if (commandNames.isNotEmpty &&
              (readOnly ||
                  session.root.id == null ||
                  showActionsWhileEditing) &&
              compactActions &&
              (steps.isEmpty || session.currentStep == steps.length - 1))
            commands,
        ];
        final actions = externalFrame
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actionWidgets,
              )
            : OiColumn(
                breakpoint: context.breakpoint,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                gap: const OiResponsive<double>(12),
                children: actionWidgets,
              );
        final changeBar = showChangeBar && !readOnly && session.isDirty
            ? OiSurface(
                color: context.colors.surface,
                shadow: context.shadows.lg,
                borderRadius: context.radius.lg,
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    final details = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: SizedBox.square(
                            dimension: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: context.colors.primary.base,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: OiLabel.body(
                            '${session.reviewChangeCount} unsaved ${session.reviewChangeCount == 1 ? 'change' : 'changes'}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 12),
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 300),
                              child: OiLabel.caption(
                                session.reviewChangeSummary,
                                color: context.colors.textMuted,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ] else
                          const Spacer(),
                      ],
                    );
                    final issue = session.validationIssueCount == 0
                        ? null
                        : OiTappable(
                            semanticLabel:
                                '${session.validationIssueCount} ${session.validationIssueCount == 1 ? 'field needs' : 'fields need'} attention',
                            onTap: () async {
                              // Validation also reveals invalid tabs, cards and
                              // advanced rows through their existing epoch hooks.
                              await session.validate();
                              if (sharedTabs != null) {
                                final tabs = sharedTabs.tabs
                                    .where((tab) => session.root.visible(tab))
                                    .toList();
                                final first = tabs.indexWhere(
                                  (tab) => _errorsIn(tab, session.root) > 0,
                                );
                                if (first >= 0) sharedTabIndex.value = first;
                              }
                              if (steps.isNotEmpty) {
                                final first = steps.indexWhere(
                                  (step) => _errorsIn(step, session.root) > 0,
                                );
                                if (first >= 0) await session.goToStep(first);
                              }
                              await WidgetsBinding.instance.endOfFrame;
                              await errorAnchors.revealFirst();
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OiIcon.raw(
                                  OiIcons.circleAlert,
                                  size: 14,
                                  color: context.colors.error.base,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: OiLabel.caption(
                                    '${session.validationIssueCount} ${session.validationIssueCount == 1 ? 'field needs' : 'fields need'} attention',
                                    color: context.colors.error.base,
                                  ),
                                ),
                              ],
                            ),
                          );
                    final controls = Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        OiButton.secondary(
                          label: 'Discard changes',
                          onTap: busy || session.hasUnknown
                              ? null
                              : () async {
                                  if (!await beakConfirmFormExit(
                                        context,
                                        session: session,
                                      ) ||
                                      !context.mounted) {
                                    return;
                                  }
                                  await session.discardChanges();
                                  if (context.mounted) {
                                    displayMode.value = BeakFormMode.read;
                                  }
                                },
                        ),
                        OiButton.primary(
                          label: submitLabel ?? strings.save,
                          onTap:
                              busy ||
                                  session.hasUnknown ||
                                  session.conflicts.isNotEmpty ||
                                  (primaryAction != null &&
                                      !session.canExecuteAction(primaryAction))
                              ? null
                              : finish,
                        ),
                      ],
                    );
                    return compact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              details,
                              const SizedBox(height: 6),
                              OiLabel.caption(
                                session.reviewChangeSummary,
                                color: context.colors.textMuted,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [?issue, controls],
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(child: details),
                                    if (issue != null) ...[
                                      const SizedBox(width: 12),
                                      issue,
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              controls,
                            ],
                          );
                  },
                ),
              )
            : null;
        Future<void> navigate(int target) async {
          if (await session.goToStep(target) && context.mounted) {
            completedSteps.value = {
              ...completedSteps.value,
              for (var index = 0; index < target; index++) index,
            };
          }
        }

        return _FormCommandScope(
          errorAnchors: errorAnchors,
          onEdit:
              canEdit &&
                  (model.behavior.editableWhen?.call(
                        session.root.initialRecord,
                      ) ??
                      true)
              ? () => displayMode.value = BeakFormMode.edit
              : null,
          onClose:
              onClose ??
              (router?.canPop() == true ? () => router!.pop() : null),
          onSaved: (record) {
            if (onSaved != null) {
              onSaved!(record);
            } else {
              displayMode.value = BeakFormMode.read;
            }
          },
          child: PopScope(
            canPop: session.canLeave,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (externalFrame) {
                  final framedBody = constraints.hasBoundedHeight
                      ? OiPageLayout(
                          padding: EdgeInsets.zero,
                          gap: sharedTabs == null ? 16 : 24,
                          footerGap: changeBar == null ? null : 0,
                          asideWidth: asideWidth,
                          asideFraction: asideFraction,
                          header: header == null ? null : region(header!),
                          navigation: sharedTabs == null
                              ? null
                              : _FormTabs(
                                  tabs: sharedTabs,
                                  draft: session.root,
                                  readOnly: readOnly,
                                  sharedIndex: sharedTabIndex,
                                  headerOnly: true,
                                ),
                          aside: aside == null
                              ? null
                              : region(aside!, compact: true),
                          asideFooter: asideFooter == null
                              ? null
                              : region(asideFooter!, compact: true),
                          footer: footer == null && changeBar == null
                              ? null
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (footer != null) region(footer!),
                                    ?changeBar,
                                  ],
                                ),
                          scrollable: true,
                          scrollHeaderWhenCompact: true,
                          child: body,
                        )
                      : SingleChildScrollView(
                          child: OiColumn(
                            breakpoint: context.breakpoint,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (header != null) region(header!),
                              body,
                              if (aside != null) region(aside!, compact: true),
                              if (asideFooter != null)
                                region(asideFooter!, compact: true),
                              if (footer != null) region(footer!),
                              ?changeBar,
                            ],
                          ),
                        );
                  return frameBuilder!(
                    context,
                    session,
                    displayMode.value,
                    actions,
                    framedBody,
                  );
                }
                if (constraints.hasBoundedHeight &&
                    steps.isNotEmpty &&
                    navigation == BeakWizardNavigation.rail) {
                  return OiWizardLayout(
                    navigationFooter: navigationDescription == null
                        ? null
                        : OiLabel.caption(
                            navigationDescription!,
                            color: context.colors.textMuted,
                          ),
                    steps: [
                      for (var index = 0; index < steps.length; index++)
                        OiWizardStepPresentation(
                          title: steps[index].title,
                          description: completedSteps.value.contains(index)
                              ? steps[index].completedDescription?.call(
                                      BeakFormReader(session.root),
                                      BeakFormatting.of(context),
                                    ) ??
                                    steps[index].description
                              : steps[index].description,
                        ),
                    ],
                    currentStep: session.currentStep,
                    completedSteps: completedSteps.value,
                    enabledSteps: {
                      for (
                        var i = 0;
                        i <= session.currentStep + 1 && i < steps.length;
                        i++
                      )
                        i,
                    },
                    onStepTap: busy || session.hasUnknown ? null : navigate,
                    header: header == null ? null : region(header!),
                    stepHeader: stepHeader,
                    aside: aside == null ? null : region(aside!, compact: true),
                    asideFooter: asideFooter == null
                        ? null
                        : region(asideFooter!, compact: true),
                    footer: changeBar == null
                        ? actions
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [actions, changeBar],
                          ),
                    scrollable: true,
                    child: body,
                  );
                }
                if (constraints.hasBoundedHeight &&
                    (header != null ||
                        aside != null ||
                        asideFooter != null ||
                        footer != null ||
                        changeBar != null)) {
                  return OiPageLayout(
                    header: header == null ? null : region(header!),
                    aside: aside == null ? null : region(aside!, compact: true),
                    asideFooter: asideFooter == null
                        ? null
                        : region(asideFooter!, compact: true),
                    footer: changeBar ?? actions,
                    scrollable: true,
                    scrollHeaderWhenCompact: true,
                    child: body,
                  );
                }
                return SingleChildScrollView(
                  child: OiColumn(
                    breakpoint: context.breakpoint,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    gap: const OiResponsive<double>(16),
                    children: [
                      if (header != null) region(header!),
                      ?stepHeader,
                      body,
                      if (aside != null) region(aside!),
                      if (asideFooter != null) region(asideFooter!),
                      actions,
                      ?changeBar,
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ReviewSectionView extends StatelessWidget {
  const _ReviewSectionView({required this.section, required this.draft});

  final BeakReviewSection section;
  final BeakDraftRecord draft;

  @override
  Widget build(BuildContext context) {
    final target = section.stepIndex;
    final session = draft.session;
    final heading = OiColumn(
      breakpoint: context.breakpoint,
      crossAxisAlignment: CrossAxisAlignment.start,
      gap: const OiResponsive<double>(4),
      children: [
        OiLabel.variant(
          section.title,
          variant: OiLabelVariant.h4,
          style: section.titleStyle,
        ),
        if (target != null && target >= 0 && target < session.steps.length)
          OiTappable(
            semanticLabel: 'Edit ${section.title}',
            onTap:
                session.submitting.value ||
                    session.hasUnknown ||
                    !draft.enabled(section)
                ? null
                : () => session.goToStep(target),
            child: SizedBox(
              height: 20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OiIcon.raw(
                    OiIcons.pencil,
                    size: 14,
                    color: context.colors.primary.base,
                  ),
                  const SizedBox(width: 6),
                  OiLabel.body('Edit', color: context.colors.primary.base),
                ],
              ),
            ),
          ),
      ],
    );
    final content = Padding(
      padding: section.contentPadding,
      child: OiColumn(
        breakpoint: context.breakpoint,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        gap: const OiResponsive<double>(12),
        children: [
          for (final child in section.children)
            if (draft.visible(child))
              _FormNodeView(node: child, draft: draft, readOnly: true),
        ],
      ),
    );
    return OiColumn(
      breakpoint: context.breakpoint,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      gap: OiResponsive<double>(section.dividerSpacing),
      children: [
        Padding(
          padding: section.padding,
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth >= 600
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 160, child: heading),
                      const SizedBox(width: 24),
                      Expanded(child: content),
                    ],
                  )
                : OiColumn(
                    breakpoint: context.breakpoint,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    gap: const OiResponsive<double>(12),
                    children: [heading, content],
                  ),
          ),
        ),
        if (section.divider) OiDivider(color: context.colors.borderSubtle),
      ],
    );
  }
}

class _FormNodeView extends HookWidget {
  const _FormNodeView({
    required this.node,
    required this.draft,
    required this.readOnly,
    this.sharedTabs,
    this.sharedTabIndex,
  });
  final BeakTabs? sharedTabs;
  final ValueNotifier<int>? sharedTabIndex;
  final BeakFormNode node;
  final BeakDraftRecord draft;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final reader = BeakFormReader(draft);
    if (!draft.visible(node)) return const SizedBox.shrink();
    List<Widget> children(BeakFormLayout node) => [
      for (final child in node.children)
        if (draft.visible(child))
          _FormNodeView(
            node: child,
            draft: draft,
            readOnly: readOnly,
            sharedTabs: sharedTabs,
            sharedTabIndex: sharedTabIndex,
          ),
    ];
    return switch (node) {
      BeakFormDivider() => OiDivider(color: context.colors.borderSubtle),
      final BeakModeLayout modes => _FormNodeView(
        node: readOnly ? modes.read : modes.edit,
        draft: draft,
        readOnly: readOnly,
      ),
      final BeakTabs tabs => _FormTabs(
        tabs: tabs,
        draft: draft,
        readOnly: readOnly,
        sharedIndex: identical(tabs, sharedTabs) ? sharedTabIndex : null,
        bodyOnly: identical(tabs, sharedTabs),
      ),
      final BeakReviewSection section => _ReviewSectionView(
        section: section,
        draft: draft,
      ),
      final BeakSection section => OiColumn(
        breakpoint: context.breakpoint,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        gap: OiResponsive<double>(section.gap),
        children: [
          if (section.divider)
            Padding(
              padding: EdgeInsets.only(bottom: section.dividerAfterSpacing),
              child: OiDivider(color: context.colors.borderSubtle),
            ),
          OiColumn(
            breakpoint: context.breakpoint,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            gap: OiResponsive<double>(section.headingGap),
            children: [
              LayoutBuilder(
                builder: (context, sectionConstraints) => Row(
                  children: [
                    Expanded(
                      child: OiLabel.variant(
                        section.title,
                        variant:
                            context
                                    .dependOnInheritedWidgetOfExactType<
                                      _FormRegionScope
                                    >()
                                    ?.compactHeadings ==
                                true
                            ? OiLabelVariant.h4
                            : OiLabelVariant.h2,
                        style: section.titleStyle,
                        color: switch (section.titleColor) {
                          BeakColor.primary => context.colors.primary.base,
                          BeakColor.secondary => context.colors.accent.base,
                          BeakColor.success => context.colors.success.base,
                          BeakColor.warning => context.colors.warning.base,
                          BeakColor.error => context.colors.error.base,
                          BeakColor.info => context.colors.info.base,
                          BeakColor.muted => context.colors.textMuted,
                          null => null,
                        },
                      ),
                    ),
                    if (section.trailing != null) ...[
                      const SizedBox(width: 12),
                      IntrinsicWidth(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: sectionConstraints.maxWidth * .6,
                          ),
                          child: BeakRecordTemplateView(
                            template: BeakRecordTemplate(
                              title: section.trailing!,
                            ),
                            draft: draft,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (section.description case final String description)
                OiLabel.body(
                  description,
                  style: section.descriptionStyle,
                  color: context.colors.textMuted,
                ),
            ],
          ),
          ...children(section),
        ],
      ),
      final BeakCard card => _FormCard(
        card: card,
        draft: draft,
        readOnly: readOnly,
      ),
      final BeakColumns columns => Padding(
        padding: columns.padding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth.isFinite
                ? ((constraints.maxWidth + columns.gap) /
                          (columns.minColumnWidth + columns.gap))
                      .floor()
                      .clamp(1, columns.columns)
                : columns.columns;
            final items = children(columns);
            if (columns.columnWidths.isNotEmpty && count >= items.length) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    if (index > 0) SizedBox(width: columns.gap),
                    if (index < columns.columnWidths.length &&
                        columns.columnWidths[index] != null)
                      SizedBox(
                        width: columns.columnWidths[index],
                        child: items[index],
                      )
                    else
                      Expanded(child: items[index]),
                  ],
                ],
              );
            }
            return OiGrid(
              breakpoint: context.breakpoint,
              columns: OiResponsive<int>(count),
              gap: OiResponsive<double>(columns.gap),
              children: items,
            );
          },
        ),
      ),
      final BeakFormLayout layout => OiColumn(
        breakpoint: context.breakpoint,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        gap: OiResponsive<double>(layout.spacing),
        children: children(layout),
      ),
      final BeakFormHeader header => _FormHeaderView(
        node: header,
        draft: draft,
      ),
      final BeakFormMetrics metrics => _FormMetricsView(
        node: metrics,
        draft: draft,
      ),
      final BeakFormSummary summary => _FormSummaryView(
        node: summary,
        draft: draft,
      ),
      final BeakFormNotice notice => _formNotice(context, notice, reader),
      final BeakFormPlaceholder placeholder => OiHatchPlaceholder(
        label: placeholder.label,
        height: placeholder.height,
        child: placeholder.template == null
            ? null
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: BeakRecordTemplateView(
                  template: placeholder.template!,
                  draft: draft,
                ),
              ),
      ),
      final BeakFormCapacity capacity => OiCapacityIndicator(
        label: capacity.label,
        subtitle: capacity.subtitle,
        showValue: capacity.showValue,
        showLabel: capacity.showLabel,
        height: capacity.height,
        gap: capacity.gap,
        labelStyle: capacity.labelStyle,
        valueStyle: capacity.valueStyle,
        caption: capacity.caption?.call(reader, BeakFormatting.of(context)),
        value: capacity.value(reader) ?? 0,
        max: capacity.max(reader) ?? 0,
        warningThreshold: capacity.warningThreshold,
        warningText: capacity.warningText,
        valueLabel:
            capacity.valueLabel?.call(reader, BeakFormatting.of(context)) ??
            '${BeakFormatting.of(context).format(capacity.value(reader), capacity.format)} / ${BeakFormatting.of(context).format(capacity.max(reader), capacity.format)}',
      ),
      final BeakFormProgress<Enum> progress => _ProgressView(
        node: progress,
        draft: draft,
      ),
      BeakFormTimeline(
        :final field,
        :final title,
        :final time,
        :final description,
        :final compact,
        :final messages,
        :final emphasizeMentions,
        :final inlineTime,
        :final actor,
        :final messageIdentity,
        :final columns,
      ) =>
        BeakRecordTimeline(
          entries: draft.read(field) ?? const [],
          title: title,
          time: time,
          description: description,
          compact: compact,
          messages: messages,
          emphasizeMentions: emphasizeMentions,
          inlineTime: inlineTime,
          actor: actor,
          messageIdentity: messageIdentity,
          columns: columns,
        ),
      final BeakRelationAdd add => _RelationAddAction(
        node: add,
        draft: draft,
        readOnly: readOnly,
      ),
      final BeakFormLinks links => _FormLinks(node: links, draft: draft),
      final BeakFormActionInput input => _InlineActionInput(
        input: input,
        draft: draft,
        readOnly: readOnly,
      ),
      BeakFormActions(:final names) => _ModelActions(
        draft: draft,
        names: names,
        enabled: draft.enabled(node),
      ),
      BeakFormTemplate(:final template) => BeakRecordTemplateView(
        template: template,
        draft: draft,
      ),
      final BeakInput<Object> input => _markedField(
        context,
        draft,
        input.field,
        _ScalarInput(input: input, draft: draft, readOnly: readOnly),
        readOnly: readOnly || input.readOnly || !draft.enabled(input),
      ),
      final BeakRelationInput input => _markedField(
        context,
        draft,
        input.field,
        _RelationInput(input: input, draft: draft, readOnly: readOnly),
        readOnly: readOnly || !draft.enabled(input),
      ),
      final BeakGallery gallery => BeakGalleryView(
        gallery: gallery,
        draft: draft,
        readOnly: readOnly,
        fieldBuilder: (node, row, locked) =>
            _FormNodeView(node: node, draft: row, readOnly: locked),
      ),
      final BeakFormLock lock => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OiButton.secondary(
            label: lock.label,
            enabled: false,
            icon: lock.icon ?? OiIcons.lockKeyhole,
            size: OiButtonSize.small,
            onTap: null,
          ),
          if (lock.description case final description?) ...[
            const SizedBox(height: 6),
            OiLabel.caption(description, color: context.colors.textMuted),
          ],
        ],
      ),
      final BeakRelationTable table => _RelationTable(
        table: table,
        draft: draft,
        readOnly: readOnly,
      ),
      final BeakCalculated calculated => _calculatedView(
        context,
        calculated,
        reader,
      ),
      BeakFormWidget(:final builder, :final showOnRead) =>
        readOnly && !showOnRead
            ? const SizedBox.shrink()
            : BeakDraftScope(
                draft: draft,
                readOnly: readOnly,
                enabled:
                    !readOnly &&
                    draft.enabled(node) &&
                    !draft.session.submitting.value &&
                    !draft.session.hasUnknown,
                child: Builder(builder: (context) => builder(context, draft)),
              ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _FormRegionScope extends InheritedWidget {
  const _FormRegionScope({required this.compactHeadings, required super.child});
  final bool compactHeadings;
  @override
  bool updateShouldNotify(_FormRegionScope oldWidget) =>
      compactHeadings != oldWidget.compactHeadings;
}

Widget _calculatedView(
  BuildContext context,
  BeakCalculated node,
  BeakFormReader reader,
) {
  final label = node.labelBuilder?.call(reader) ?? node.label;
  final description =
      node.subtitle?.call(reader, BeakFormatting.of(context)) ??
      node.description?.call(reader);
  final value = node.value(reader);
  final formatting = BeakFormatting.of(context);
  final text =
      node.display?.call(value, formatting) ??
      formatting.format(value, node.format);
  if (node.presentation == BeakCalculatedPresentation.message) {
    return OiColumn(
      breakpoint: context.breakpoint,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      gap: const OiResponsive<double>(4),
      children: [
        if (label != null)
          OiLabel.caption(label, color: context.colors.textMuted),
        OiSurface(
          color: context.colors.surfaceSubtle,
          borderRadius: context.radius.md,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: OiLabel.body(text, style: node.valueStyle),
          ),
        ),
        if (description != null)
          OiLabel.caption(
            description,
            color: _formSemanticColor(context, node.descriptionTone),
          ),
      ],
    );
  }
  if (node.presentation == BeakCalculatedPresentation.detail) {
    return OiColumn(
      breakpoint: context.breakpoint,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      gap: const OiResponsive<double>(2),
      children: [
        if (label != null)
          OiLabel.caption(label, color: context.colors.textMuted),
        Row(
          children: [
            if (node.icon != null) ...[
              OiIcon.raw(node.icon, size: 16, color: context.colors.textMuted),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OiLabel.body(
                text,
                style:
                    node.valueStyle ??
                    const TextStyle(fontWeight: FontWeight.w500),
                textAlign: node.textAlign,
              ),
            ),
          ],
        ),
        if (description != null)
          OiLabel.caption(
            description,
            color: _formSemanticColor(context, node.descriptionTone),
          ),
      ],
    );
  }
  if (node.presentation == BeakCalculatedPresentation.text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OiLabel.body(
          '${label == null ? '' : '$label: '}$text',
          style: node.valueStyle,
          textAlign: node.textAlign,
        ),
        if (description != null)
          OiLabel.small(
            description,
            textAlign: node.textAlign,
            color: context.colors.textMuted,
          ),
      ],
    );
  }
  return OiColumn(
    breakpoint: context.breakpoint,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    gap: const OiResponsive<double>(6),
    children: [
      if (node.presentation == BeakCalculatedPresentation.checkbox)
        OiCheckbox(value: value == true, label: label, enabled: false)
      else ...[
        if (label != null) OiLabel.body(label),
        OiSurface(
          color: context.colors.surfaceSubtle,
          borderRadius: context.radius.sm,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (node.icon != null) ...[
                  OiIcon.decorative(
                    icon: node.icon,
                    size: 16,
                    color: context.colors.textMuted,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(child: OiLabel.body(text, style: node.valueStyle)),
              ],
            ),
          ),
        ),
      ],
      if (description != null)
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: node.presentation == BeakCalculatedPresentation.checkbox
                ? 24
                : 0,
          ),
          child: OiLabel.caption(description, color: context.colors.textMuted),
        ),
    ],
  );
}

Color? _formSemanticColor(BuildContext context, BeakColor? color) =>
    switch (color) {
      BeakColor.primary => context.colors.primary.base,
      BeakColor.secondary => context.colors.accent.base,
      BeakColor.success => context.colors.success.base,
      BeakColor.warning => context.colors.warning.base,
      BeakColor.error => context.colors.error.base,
      BeakColor.info => context.colors.info.base,
      BeakColor.muted => context.colors.textMuted,
      null => null,
    };

class _FormSummaryView extends StatelessWidget {
  const _FormSummaryView({required this.node, required this.draft});

  final BeakFormSummary node;
  final BeakDraftRecord draft;

  @override
  Widget build(BuildContext context) {
    final reader = BeakFormReader(draft);
    final readers = node.source == null ? [reader] : reader.rows(node.source!);
    final formatting = BeakFormatting.of(context);
    final rows = <Widget>[];
    if (node.title != null) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: (node.headingGap ?? node.gap) - node.gap,
          ),
          child: OiLabel.variant(
            node.title!,
            variant: OiLabelVariant.bodyStrong,
            style: node.titleStyle,
            color: _formSemanticColor(context, node.titleColor),
          ),
        ),
      );
    }
    for (final source in readers) {
      for (final line in node.lines) {
        if (!(line.visibleIf?.call(source) ?? true)) continue;
        if (line.dependencies.any(
          (field) => !source.draft.capabilities.canRead(
            field.path.isEmpty ? field.key : field.path.first.key,
          ),
        )) {
          continue;
        }
        final label = line.labelBuilder?.call(source, formatting) ?? line.label;
        final subtitle = line.subtitle?.call(source, formatting);
        final value =
            line.valueLabel?.call(source, formatting) ??
            formatting.format(line.value(source), line.format);
        if (line.dividerBefore) {
          rows.add(OiDivider(spacing: line.dividerSpacing));
        }
        rows.add(
          Padding(
            padding: EdgeInsets.only(bottom: line.afterSpacing),
            child: OiKeyValue(
              label: label,
              value: value,
              direction: Axis.horizontal,
              padding: EdgeInsets.zero,
              valueAtEnd: true,
              crossAxisAlignment: line.valueAlignment,
              valueMaxWidthFraction: line.valueCaption == null ? .5 : .75,
              labelWidget: OiColumn(
                breakpoint: context.breakpoint,
                crossAxisAlignment: CrossAxisAlignment.start,
                gap: OiResponsive<double>(line.subtitleGap),
                children: [
                  OiLabel.variant(
                    label,
                    variant: line.emphasized
                        ? OiLabelVariant.bodyStrong
                        : OiLabelVariant.body,
                    style: line.labelStyle,
                    color: line.emphasized
                        ? null
                        : _formSemanticColor(context, node.labelColor),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    OiLabel.variant(
                      subtitle,
                      variant: OiLabelVariant.small,
                      style: line.subtitleStyle,
                      color: context.colors.textMuted,
                    ),
                ],
              ),
              valueWidget: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (line.valueCaption?.call(source, formatting)
                      case final caption?)
                    OiLabel.caption(caption, color: context.colors.textMuted),
                  OiLabel.variant(
                    value,
                    textAlign: TextAlign.end,
                    variant: line.emphasized
                        ? OiLabelVariant.bodyStrong
                        : OiLabelVariant.body,
                    style: line.valueStyle,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return Align(
      alignment: node.alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: node.maxWidth ?? double.infinity),
        child: OiColumn(
          breakpoint: context.breakpoint,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          gap: OiResponsive<double>(node.gap),
          children: rows,
        ),
      ),
    );
  }
}

class _FormMetricsView extends StatelessWidget {
  const _FormMetricsView({required this.node, required this.draft});
  final BeakFormMetrics node;
  final BeakDraftRecord draft;

  @override
  Widget build(BuildContext context) {
    if (node.metrics.isEmpty) return const SizedBox.shrink();
    final formatting = BeakFormatting.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final card = context.components.card;
        final available = math.max(
          0.0,
          constraints.maxWidth - 2 * (card?.borderWidth ?? 1),
        );
        final columns = (available / node.minColumnWidth).floor().clamp(
          1,
          node.metrics.length,
        );
        return OiSurface(
          shadow: node.inset ? null : card?.shadow,
          color: node.inset
              ? context.colors.surfaceSubtle
              : card?.backgroundColor,
          borderRadius: node.inset
              ? context.radius.md
              : card?.borderRadius ?? context.radius.md,
          border: node.inset
              ? null
              : OiBorderStyle.solid(
                  card?.borderColor ?? context.colors.border,
                  card?.borderWidth ?? 1,
                ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var start = 0; start < node.metrics.length; start += columns)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (
                        var i = start;
                        i < math.min(start + columns, node.metrics.length);
                        i++
                      )
                        Expanded(
                          flex: node.metrics[i].flex,
                          child: Container(
                            padding: node.padding,
                            decoration: BoxDecoration(
                              border: Border(
                                left: i % columns == 0
                                    ? BorderSide.none
                                    : BorderSide(
                                        color: context.colors.borderSubtle,
                                      ),
                                top: i < columns
                                    ? BorderSide.none
                                    : BorderSide(
                                        color: context.colors.borderSubtle,
                                      ),
                              ),
                            ),
                            child: OiColumn(
                              breakpoint: context.breakpoint,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              gap: OiResponsive<double>(node.gap),
                              children: [
                                OiLabel.caption(
                                  node.metrics[i].labelBuilder?.call(
                                        BeakFormReader(draft),
                                        formatting,
                                      ) ??
                                      node.metrics[i].label,
                                ),
                                OiLabel.variant(
                                  formatting.format(
                                    node.metrics[i].value(
                                      BeakFormReader(draft),
                                    ),
                                    node.metrics[i].format,
                                  ),
                                  variant: OiLabelVariant.bodyStrong,
                                  style: node.metrics[i].valueStyle,
                                  maxLines: 2,
                                ),
                                if ((node.metrics[i].subtitle?.call(
                                          BeakFormReader(draft),
                                          formatting,
                                        ) ??
                                        node.metrics[i].description)
                                    case final String description)
                                  OiLabel.caption(description),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FormHeaderView extends HookWidget {
  const _FormHeaderView({required this.node, required this.draft});
  final BeakFormHeader node;
  final BeakDraftRecord draft;

  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_FormCommandScope>();
    final session = draft.session;
    final saving = useState(false);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: OiRow(
        breakpoint: context.breakpoint,
        gap: const OiResponsive<double>(12),
        children: [
          if (node.showClose)
            OiButton.icon(
              label: 'Close',
              icon: OiIcons.x,
              onTap: scope?.onClose == null || session.submitting.value
                  ? null
                  : () async {
                      if (await beakConfirmFormExit(
                            context,
                            session: session,
                          ) &&
                          context.mounted) {
                        scope!.onClose!();
                      }
                    },
            ),
          if (node.showClose)
            SizedBox(
              height: 24,
              child: OiDivider(
                axis: Axis.vertical,
                color: context.colors.borderSubtle,
              ),
            ),
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OiLabel.h4(node.title),
                if (node.description != null)
                  OiLabel.caption(node.description!),
                if (node.showDraftSavedAt && session.draftSavedAt != null)
                  OiLabel.caption(
                    'Draft saved ${BeakFormatting.of(context).time(session.draftSavedAt!)}',
                  ),
              ],
            ),
          ),
          if (node.showDraftAction && session.drafts != null)
            OiButton.secondary(
              size: OiButtonSize.small,
              label: saving.value ? 'Saving draft…' : 'Save as draft',
              onTap:
                  saving.value ||
                      session.submitting.value ||
                      session.hasUnknown ||
                      session.hasStoredDraft
                  ? null
                  : () async {
                      saving.value = true;
                      await session.persistDraft();
                      if (!context.mounted) return;
                      saving.value = false;
                    },
            ),
        ],
      ),
    );
  }
}

Widget _formNotice(
  BuildContext context,
  BeakFormNotice notice,
  BeakFormReader state,
) {
  final message = notice.message(state);
  final title = notice.titleBuilder?.call(state) ?? notice.title;
  if (notice.plain) {
    return Builder(
      builder: (context) {
        final color = switch (notice.tone) {
          BeakColor.warning => context.colors.warning.base,
          BeakColor.error => context.colors.error.base,
          BeakColor.success => context.colors.success.base,
          BeakColor.muted => context.colors.textMuted,
          BeakColor.primary => context.colors.primary.base,
          BeakColor.secondary => context.colors.accent.base,
          BeakColor.info => context.colors.info.base,
        };
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OiIcon.decorative(
              icon:
                  notice.icon ??
                  (notice.tone == BeakColor.warning ||
                          notice.tone == BeakColor.error
                      ? OiIcons.triangleAlert
                      : OiIcons.info),
              size: 16,
              color: color,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OiLabel.small(
                title == null ? message : '$title: $message',
                color: color,
              ),
            ),
          ],
        );
      },
    );
  }
  final caption = notice.caption?.call(state);
  final annotation = caption == null
      ? null
      : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (notice.captionIcon != null) ...[
              OiIcon.decorative(
                icon: notice.captionIcon,
                size: 12,
                color: context.colors.textMuted,
              ),
              const SizedBox(width: 4),
            ],
            OiLabel.caption(caption, color: context.colors.textMuted),
          ],
        );
  return switch (notice.tone) {
    BeakColor.warning => OiBanner.warning(
      title: title,
      inlineTitle: notice.inline,
      icon: notice.icon,
      message: message,
      dismissible: false,
      trailing: annotation,
    ),
    BeakColor.error => OiBanner.error(
      title: title,
      inlineTitle: notice.inline,
      icon: notice.icon,
      message: message,
      dismissible: false,
      trailing: annotation,
    ),
    BeakColor.success => OiBanner.success(
      title: title,
      inlineTitle: notice.inline,
      icon: notice.icon,
      message: message,
      dismissible: false,
      trailing: annotation,
    ),
    BeakColor.muted => OiBanner.neutral(
      title: title,
      inlineTitle: notice.inline,
      icon: notice.icon,
      message: message,
      dismissible: false,
      trailing: annotation,
    ),
    _ => OiBanner.info(
      title: title,
      inlineTitle: notice.inline,
      icon: notice.icon,
      message: message,
      dismissible: false,
      trailing: annotation,
    ),
  };
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.node, required this.draft});
  final BeakFormProgress<Enum> node;
  final BeakDraftRecord draft;

  @override
  Widget build(BuildContext context) {
    final column = node.field.column;
    if (column is! BeakEnumColumn<Enum>) {
      throw const BeakConfigurationException(
        'Workflow progress requires an enum column.',
      );
    }
    final steps = node.steps;
    final states =
        steps?.map((step) => step.state).toList() ??
        node.states ??
        column.values;
    final stored = node.field.ownerRecord(draft.snapshot)?[node.field.key]?.raw;
    final state =
        draft.read(node.field) ?? (stored == null ? node.initialState : null);
    final current = node.planned || state == null ? -1 : states.indexOf(state);
    if (states.isEmpty || (current < 0 && !node.planned)) {
      return renderBeakField(
        context,
        field: node.field,
        record: draft.snapshot,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => OiStepper(
        totalSteps: states.length,
        currentStep: current,
        labelStyle: node.labelStyle,
        timeline: node.timeline,
        stepLabels:
            steps
                ?.map(
                  (step) =>
                      step.labelBuilder?.call(BeakFormReader(draft)) ??
                      step.label,
                )
                .toList() ??
            states.map((state) => column.labelFor(state!)).toList(),
        stepDetails: steps == null
            ? null
            : [
                for (final step in steps)
                  OiColumn(
                    breakpoint: context.breakpoint,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    gap: OiResponsive<double>(node.contextSpacing),
                    children: [
                      if (step.details case final template?)
                        BeakRecordTemplateView(
                          template: template,
                          draft: draft,
                          titleVariant: OiLabelVariant.caption,
                        ),
                      if (step.context case final template?)
                        if (step.contextInset)
                          OiSurface(
                            color: context.colors.surfaceSubtle,
                            borderRadius: context.radius.sm,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: BeakRecordTemplateView(
                              template: template,
                              draft: draft,
                            ),
                          )
                        else
                          BeakRecordTemplateView(
                            template: template,
                            draft: draft,
                          ),
                    ],
                  ),
              ],
        completedColor: steps == null ? null : context.colors.primary.base,
        currentOutlined: steps != null,
        indicatorSize: steps == null ? 28 : 24,
        completedSteps: {for (var i = 0; i < current; i++) i},
        style: constraints.maxWidth < 560
            ? OiStepperStyle.vertical
            : OiStepperStyle.horizontal,
      ),
    );
  }
}

bool _actionPlaced(BeakFormNode node, String name, BeakDraftRecord draft) {
  if (!draft.visible(node)) return false;
  return switch (node) {
    BeakFormActions(:final names) => names == null || names.contains(name),
    BeakFormActionInput(name: final actionName, :final submitWithForm) =>
      actionName == name || submitWithForm == name,
    BeakFormLayout(:final children) => children.any(
      (child) => _actionPlaced(child, name, draft),
    ),
    _ => false,
  };
}

class _FormErrorRegistry {
  final anchors = <_FormErrorAnchorState>[];
  Future<void> revealFirst() async {
    for (final anchor in List.of(anchors)) {
      if (!anchor.canReveal) {
        continue;
      }
      await Scrollable.ensureVisible(
        anchor.context,
        alignment: .15,
        duration: const Duration(milliseconds: 180),
      );
      if (!anchor.canReveal) continue;
      FocusNode? focus;
      void visit(Element element) {
        if (focus != null) return;
        if (element.widget case EditableText(:final focusNode)) {
          if (focusNode.canRequestFocus) focus = focusNode;
        } else if (element.widget case Focus(focusNode: final node?)) {
          if (node.canRequestFocus) focus = node;
        }
        if (focus == null) element.visitChildElements(visit);
      }

      (anchor.context as Element).visitChildElements(visit);
      if (focus != null) {
        focus!.requestFocus();
        return;
      }
    }
  }
}

Widget _errorAnchor(
  BuildContext context,
  BeakDraftRecord draft,
  BeakFieldRef<Object> field,
  Widget child, {
  required bool enabled,
}) {
  final registry = context
      .dependOnInheritedWidgetOfExactType<_FormCommandScope>()
      ?.errorAnchors;
  return registry == null
      ? child
      : _FormErrorAnchor(
          registry: registry,
          draft: draft,
          field: field,
          enabled: enabled,
          child: child,
        );
}

class _FormErrorAnchor extends StatefulWidget {
  const _FormErrorAnchor({
    required this.registry,
    required this.draft,
    required this.field,
    required this.enabled,
    required this.child,
  });
  final _FormErrorRegistry registry;
  final BeakDraftRecord draft;
  final BeakFieldRef<Object> field;
  final bool enabled;
  final Widget child;
  @override
  State<_FormErrorAnchor> createState() => _FormErrorAnchorState();
}

class _FormErrorAnchorState extends State<_FormErrorAnchor> {
  bool get canReveal {
    if (!mounted || !widget.enabled || !hasError) return false;
    var visible = true;
    context.visitAncestorElements((element) {
      if (element.widget
          case Offstage(offstage: true) ||
              ExcludeFocus(excluding: true) ||
              Visibility(visible: false)) {
        visible = false;
        return false;
      }
      return true;
    });
    return visible;
  }

  bool get hasError =>
      widget.draft.errors[widget.field.key]?.isNotEmpty == true ||
      widget.draft.controller.inputErrors.containsKey(widget.field.key);
  @override
  void initState() {
    super.initState();
    widget.registry.anchors.add(this);
  }

  @override
  void didUpdateWidget(_FormErrorAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.registry, widget.registry)) {
      oldWidget.registry.anchors.remove(this);
      widget.registry.anchors.add(this);
    }
  }

  @override
  void dispose() {
    widget.registry.anchors.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _FormCommandScope extends InheritedWidget {
  const _FormCommandScope({
    required this.onSaved,
    required this.onClose,
    required this.errorAnchors,
    this.onEdit,
    required super.child,
  });
  final _FormErrorRegistry errorAnchors;
  final void Function(BeakRecord) onSaved;
  final VoidCallback? onClose;
  final VoidCallback? onEdit;
  @override
  bool updateShouldNotify(_FormCommandScope oldWidget) =>
      onSaved != oldWidget.onSaved ||
      onClose != oldWidget.onClose ||
      onEdit != oldWidget.onEdit;
}

class _RelationAddAction extends StatelessWidget {
  const _RelationAddAction({
    required this.node,
    required this.draft,
    required this.readOnly,
  });
  final BeakRelationAdd node;
  final BeakDraftRecord draft;
  final bool readOnly;
  @override
  Widget build(BuildContext context) {
    final table = draft.relationTable(node.field);
    final scope = context
        .dependOnInheritedWidgetOfExactType<_FormCommandScope>();
    if (!table.allowAdding ||
        table.readOnly ||
        !draft.visible(table) ||
        (readOnly && scope?.onEdit == null)) {
      return const SizedBox.shrink();
    }
    final enabled =
        draft.enabled(node) &&
        draft.enabled(table) &&
        !draft.session.submitting.value &&
        !draft.session.hasUnknown;
    final label = node.label ?? 'Add ${table.label ?? table.field.label}';
    return OiAddAction(
      label: label,
      caption: node.caption,
      presentation: node.presentation == BeakRelationAddPresentation.search
          ? OiAddActionPresentation.search
          : OiAddActionPresentation.dashed,
      placeholder: node.placeholder,
      onTap: !enabled
          ? null
          : () async {
              if (readOnly) {
                scope?.onEdit?.call();
              }
              final checkpoint = draft.checkpoint();
              final row = draft.addRow(table.field);
              final accepted = await _editModal(
                context,
                row,
                table.rowLayout,
                title: label,
              );
              if (accepted != true) {
                draft.restore(checkpoint);
              }
            },
    );
  }
}

class _FormLinks extends StatelessWidget {
  const _FormLinks({required this.node, required this.draft});
  final BeakFormLinks node;
  final BeakDraftRecord draft;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final link in node.links)
        if (draft.visible(
          BeakFormTemplate(
            template: BeakRecordTemplate(title: link.destination),
          ),
        ))
          if (link.destination.read(draft) case final String destination
              when destination.isNotEmpty)
            OiButton.secondary(
              label: link.label,
              icon: link.icon,
              size: OiButtonSize.small,
              onTap: !draft.enabled(node)
                  ? null
                  : () async {
                      // Recheck permissions at activation, not only when building.
                      if (!draft.visible(
                        BeakFormTemplate(
                          template: BeakRecordTemplate(title: link.destination),
                        ),
                      )) {
                        return;
                      }
                      final current = link.destination.read(draft);
                      if (current == null || current.isEmpty) {
                        return;
                      }
                      try {
                        await launchBeakUri(Uri.parse(current));
                      } on BeakException catch (error) {
                        if (context.mounted) {
                          BeakOverlays(
                            context,
                          ).toast(error.message, level: OiToastLevel.error);
                        }
                      }
                    },
            ),
    ],
  );
}

class _InlineActionInput extends StatelessWidget {
  const _InlineActionInput({
    required this.input,
    required this.draft,
    required this.readOnly,
  });
  final BeakFormActionInput input;
  final BeakDraftRecord draft;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final session = draft.session;
    final action = session.model.behavior.action(input.name);
    final primary = !readOnly && input.submitWithForm != null;
    final effective = primary
        ? session.model.behavior.action(input.submitWithForm!)
        : action;
    if (!session.canExecuteAction(effective)) return const SizedBox.shrink();
    final arguments = session.actionInput(input.name);
    return Watch.builder(
      builder: (context) {
        arguments.revision.value;
        final busy =
            session.submitting.value ||
            session.hasUnknown ||
            !draft.enabled(input);
        final description = primary
            ? input.editDescription ?? input.description
            : input.description;
        Future<void> execute() async {
          final values = await session.actionArguments(input.name);
          if (values == null || !context.mounted) return;
          await session.executeAction(input.name, arguments: values);
        }

        final button = input.inlineFooter
            ? OiButton.primary(
                label: action.label,
                size: OiButtonSize.small,
                onTap: busy ? null : execute,
              )
            : OiButton.secondary(
                label: action.label,
                onTap: busy ? null : execute,
              );
        return OiColumn(
          breakpoint: context.breakpoint,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          gap: OiResponsive<double>(input.inlineFooter ? 6 : 8),
          children: [
            ExcludeFocus(
              excluding: busy,
              child: IgnorePointer(
                ignoring: busy,
                child: _FormNodeView(
                  node: arguments.root.layout,
                  draft: arguments.root,
                  readOnly: false,
                ),
              ),
            ),
            if (input.inlineFooter)
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: input.footerMinHeight),
                child: Row(
                  children: [
                    Expanded(
                      child: description == null
                          ? const SizedBox.shrink()
                          : OiLabel.caption(
                              description,
                              color: context.colors.textMuted,
                            ),
                    ),
                    if (!primary) ...[const SizedBox(width: 8), button],
                  ],
                ),
              )
            else ...[
              if (description != null) OiLabel.caption(description),
              if (!primary)
                Align(alignment: AlignmentDirectional.centerEnd, child: button),
            ],
          ],
        );
      },
    );
  }
}

class _ModelActions extends HookWidget {
  const _ModelActions({
    required this.draft,
    this.names,
    this.enabled = true,
    this.compact = false,
    this.iconOnly = false,
  });
  final bool compact, iconOnly;
  final BeakDraftRecord draft;
  final List<String>? names;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final session = draft.session;
    if (!identical(draft, session.root)) {
      throw const BeakConfigurationException(
        'Model commands belong to the root form.',
      );
    }
    final definitions = session.model.behavior.actions;
    final actions = names == null
        ? definitions
        : [
            for (final name in names!)
              definitions.firstWhere(
                (action) => action.name == name,
                orElse: () => throw BeakConfigurationException(
                  'Unknown model command: $name.',
                ),
              ),
          ];
    final scope = context
        .dependOnInheritedWidgetOfExactType<_FormCommandScope>();
    final open = useState(false);
    final available = actions.where(session.canExecuteAction).toList();
    if (available.isEmpty) return const SizedBox.shrink();
    Future<void> execute(BeakModelAction action) async {
      if (compact) {
        open.value = false;
        await WidgetsBinding.instance.endOfFrame;
        if (!context.mounted) return;
      }
      final arguments = await showBeakActionInput(context, session, action);
      if (arguments == null || !context.mounted) return;
      final result = await session.executeAction(
        action.name,
        arguments: arguments,
      );
      if (result?.complete == true && !session.isDirty && context.mounted) {
        scope?.onSaved(result?.rootRecord ?? session.root.snapshot);
      }
    }

    final busy =
        !enabled ||
        session.submitting.value ||
        session.hasUnknown ||
        session.conflicts.isNotEmpty;
    Widget button(BeakModelAction action) => OiButton.secondary(
      label: action.label,
      onTap: busy ? null : () => execute(action),
    );
    if (compact) {
      return OiPopover(
        label: 'More actions',
        open: open.value,
        onClose: () => open.value = false,
        alignment: OiFloatingAlignment.bottomEnd,
        anchor: iconOnly
            ? OiButton.icon(
                label: 'More actions',
                icon: OiIcons.ellipsis,
                variant: OiButtonVariant.secondary,
                onTap: busy ? null : () => open.value = !open.value,
              )
            : OiButton.secondary(
                label: 'More actions',
                icon: OiIcons.ellipsis,
                onTap: busy ? null : () => open.value = !open.value,
              ),
        content: Padding(
          padding: const EdgeInsets.all(8),
          child: OiColumn(
            breakpoint: context.breakpoint,
            gap: const OiResponsive<double>(6),
            children: [for (final action in available) button(action)],
          ),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final action in available) button(action)],
    );
  }
}

int _errorsIn(BeakFormNode node, BeakDraftRecord owner) {
  if (node.visibleIf?.call(BeakFormReader(owner)) == false) return 0;
  return switch (node) {
    BeakFormLayout(:final children) => children.fold(
      0,
      (count, child) => count + _errorsIn(child, owner),
    ),
    BeakInput<Object>(:final field) => owner.errors[field.key]?.length ?? 0,
    BeakRelationInput(:final field) => owner.errors[field.key]?.length ?? 0,
    final BeakRelationTable table =>
      (owner.errors[table.field.key]?.length ?? 0) +
          owner
              .rows(table.field)
              .fold(0, (count, row) => count + _errorsIn(table.rowLayout, row)),
    _ => 0,
  };
}

class _FormCard extends HookWidget {
  const _FormCard({
    required this.card,
    required this.draft,
    required this.readOnly,
  });
  final BeakCard card;
  final BeakDraftRecord draft;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final collapsed = useState(!card.initiallyExpanded);
    useEffect(() {
      if (_errorsIn(card, draft) > 0) collapsed.value = false;
      return null;
    }, [draft.validationEpoch]);
    final content = OiColumn(
      breakpoint: context.breakpoint,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      gap: OiResponsive<double>(card.spacing),
      children: [
        if (card.presentation != BeakCardPresentation.plain)
          if (card.description case final String description)
            OiLabel.body(description),
        for (final child in card.children)
          if (draft.visible(child))
            _FormNodeView(node: child, draft: draft, readOnly: readOnly),
      ],
    );
    if (card.presentation == BeakCardPresentation.plain) {
      if (card.collapsible) {
        return OiDisclosure(
          title: card.title ?? 'Details',
          headerPadding:
              card.disclosurePadding ?? const EdgeInsets.symmetric(vertical: 8),
          description: card.headerSubtitle == null
              ? card.description
              : draft.visible(
                  BeakFormTemplate(
                    template: BeakRecordTemplate(title: card.headerSubtitle!),
                  ),
                )
              ? BeakFormatting.of(context).format(
                  card.headerSubtitle!.read(draft),
                  card.headerSubtitle!.format ?? BeakValueFormat.text,
                )
              : null,
          expanded: !collapsed.value,
          onChanged: (value) => collapsed.value = !value,
          child: content,
        );
      }
      return OiColumn(
        breakpoint: context.breakpoint,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        gap: const OiResponsive<double>(12),
        children: [
          if (card.title case final title?) OiLabel.h4(title),
          if (card.description case final description?)
            OiLabel.body(description),
          content,
        ],
      );
    }
    Widget? metadata(BeakValueBinding<Object>? binding) =>
        binding == null ||
            !draft.visible(
              BeakFormTemplate(template: BeakRecordTemplate(title: binding)),
            )
        ? null
        : BeakRecordTemplateView(
            template: BeakRecordTemplate(title: binding),
            draft: draft,
            titleVariant: OiLabelVariant.caption,
          );
    return OiCard(
      padding: card.padding,
      subtitle: metadata(card.headerSubtitle),
      trailing: metadata(card.headerTrailing),
      collapseLeading: card.collapseLeading,
      headerGap: card.headerGap,
      title: card.title == null
          ? null
          : OiLabel.variant(
              card.title!,
              variant: card.collapseLeading
                  ? OiLabelVariant.bodyStrong
                  : OiLabelVariant.h4,
            ),
      label: card.title,
      collapsible: card.collapsible,
      collapsed: collapsed.value,
      onCollapsedChanged: (value) => collapsed.value = value,
      child: content,
    );
  }
}

class _FormTabs extends HookWidget {
  const _FormTabs({
    required this.tabs,
    required this.draft,
    required this.readOnly,
    this.sharedIndex,
    this.headerOnly = false,
    this.bodyOnly = false,
  });
  final ValueNotifier<int>? sharedIndex;
  final bool headerOnly, bodyOnly;
  final BeakTabs tabs;
  final BeakDraftRecord draft;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final localIndex = useState(tabs.initialIndex);
    final selected = sharedIndex ?? localIndex;
    final visible = tabs.tabs
        .where((tab) => tab.visibleIf?.call(BeakFormReader(draft)) != false)
        .toList();

    useEffect(() {
      final invalid = visible.indexWhere((tab) => _errorsIn(tab, draft) > 0);
      if (invalid >= 0) selected.value = invalid;
      return null;
    }, [draft.validationEpoch]);
    if (visible.isEmpty) return const SizedBox.shrink();
    final index = selected.value.clamp(0, visible.length - 1);
    return OiColumn(
      breakpoint: context.breakpoint,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      gap: const OiResponsive<double>(20),
      children: [
        if (!bodyOnly)
          OiTabs(
            tabs: [
              for (final tab in visible)
                OiTabItem(
                  label: tab.title,
                  icon: tab.icon,
                  badge: !tab.showValidationBadge || _errorsIn(tab, draft) == 0
                      ? ((tab.badge?.dependencies.every(
                                  (field) => draft.capabilities.canRead(
                                    field.path.isEmpty
                                        ? field.key
                                        : field.path.first.key,
                                  ),
                                ) ??
                                true)
                            ? tab.badge?.read(draft)
                            : null)
                      : _errorsIn(tab, draft),
                ),
            ],
            selectedIndex: index,
            onSelected: (index) => selected.value = index,
            scrollable: true,
          ),
        if (!headerOnly)
          Stack(
            children: [
              for (var i = 0; i < visible.length; i++)
                Offstage(
                  key: ValueKey(visible[i]),
                  offstage: i != index,
                  child: TickerMode(
                    enabled: i == index,
                    child: ExcludeFocus(
                      excluding: i != index,
                      child: _FormNodeView(
                        node: visible[i],
                        draft: draft,
                        readOnly: readOnly,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

Widget _changeMarker(BuildContext context, {required String description}) =>
    Semantics(
      label: description,
      child: SizedBox.square(
        dimension: 6,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.primary.base,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );

Widget _markedField(
  BuildContext context,
  BeakDraftRecord draft,
  BeakFieldRef<Object> field,
  Widget editor, {
  required bool readOnly,
}) {
  if (readOnly || !draft.session.showChangeIndicators) {
    return _errorAnchor(context, draft, field, editor, enabled: !readOnly);
  }
  final theme = OiTheme.of(context);
  return _errorAnchor(
    context,
    draft,
    field,
    OiTheme(
      data: draft.fieldChanged(field)
          ? theme.copyWith(
              components: theme.components.copyWith(
                textInput:
                    (theme.components.textInput ?? const OiTextInputThemeData())
                        .copyWith(
                          labelMarkerColor: context.colors.primary.base,
                          labelMarkerDescription: 'Modified',
                        ),
              ),
            )
          : theme,
      child: editor,
    ),
    enabled: true,
  );
}

class _ScalarInput extends HookWidget {
  const _ScalarInput({
    required this.input,
    required this.draft,
    required this.readOnly,
    this.showLabel = true,
  });
  final bool showLabel;
  final BeakInput<Object> input;
  final BeakDraftRecord draft;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final column = input.field.column;
    final definition = input.attributeDefinition?.call(BeakFormReader(draft));
    final label =
        input.labelBuilder?.call(BeakFormReader(draft)) ??
        input.label ??
        definition?.label ??
        input.field.label;
    if (readOnly) {
      final choices = input.choices?.call(BeakFormReader(draft));
      final value = draft.read(input.field);
      String choiceLabel(Object? item) =>
          choices?.where((option) => option.value == item).firstOrNull?.label ??
          BeakFormatting.of(context).format(item, BeakValueFormat.text);
      return OiColumn(
        breakpoint: context.breakpoint,
        crossAxisAlignment: showLabel
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.start,
        children: [
          if (showLabel) OiLabel.caption(label),
          if (choices != null)
            OiLabel.body(
              value is Iterable<Object>
                  ? value.map(choiceLabel).join(', ')
                  : choiceLabel(value),
            )
          else if ((
                column.semantic.objectSchema,
                column.semantic.tryDecode(draft.snapshot[column.key]),
              )
              case (final BeakObjectSchema schema, final BeakJsonObject object))
            BeakObjectView(schema: schema, value: object)
          else if ((column, draft.snapshot[column.key]?.raw) case (
            BeakImageColumn(),
            final String key,
          ))
            BeakStoredImage(
              column: column,
              storageKey: key,
              alt: label,
              table: draft.model.table,
              client: draft.session.uploader,
            )
          else if (input.currency)
            OiLabel.body(switch (draft.snapshot[column.key]?.raw) {
              final num amount => BeakFormatting.of(context).currency(
                input.minorUnits
                    ? amount / math.pow(10, input.currencyScale)
                    : amount,
              ),
              _ => '—',
            })
          else
            renderBeakField(
              context,
              field: input.field,
              record: draft.snapshot,
              renderContext: BeakContext.detail,
            ),
        ],
      );
    }
    final enabled =
        !draft.session.submitting.value &&
        !draft.session.hasUnknown &&
        !input.readOnly &&
        input.derive == null &&
        draft.enabled(input);
    final error = draft.errors[input.field.key]?.join(' ');
    if (input.attributeType != null || input.attributeDefinition != null) {
      return BeakAttributeInput(
        type:
            definition?.type ??
            input.attributeType?.call(BeakFormReader(draft)) ??
            BeakAttributeType.text,
        value: draft.controller.valueOf<String>(column),
        label: label,
        description: input.description ?? definition?.description,
        options: definition != null
            ? [
                for (final choice in definition.choices)
                  BeakInputOption(choice, choice),
              ]
            : input.choices?.call(BeakFormReader(draft)) ?? const [],
        enabled: enabled,
        error: draft.controller.inputErrors[column.key] ?? error,
        onChanged: (value) => draft.controller.setValue(column, value),
        onError: (message) => draft.controller.setInputError(column, message),
      );
    }
    if (input.presentation != BeakInputPresentation.automatic ||
        input.choices != null ||
        input.maxLines != null ||
        input.controlHeight != null ||
        input.multilineContentPadding != null ||
        column.semantic.kind != BeakSemanticKind.none ||
        column is BeakJsonColumn ||
        column is BeakDateTimeColumn ||
        draft.model.relationships.whereType<BeakBelongsTo>().any(
          (relation) => relation.foreignKey == column.key,
        ) ||
        (column is BeakBoolColumn && column.tristate)) {
      final editor = BeakBoundValueInput(
        controller: draft.controller,
        column: column,
        label: showLabel ? label : '',
        description: input.description,
        enabled: enabled,
        error: error,
        presentation: input.presentation,
        choices: input.choices?.call(BeakFormReader(draft)),
        choiceMinWidth: input.choiceMinWidth,
        controlWidth: input.controlWidth,
        choiceCardPadding: input.choiceCardPadding,
        groupLabelAsField: input.groupLabelAsField,
        allowCustom: input.allowCustom,
        maxLines: input.maxLines,
        placeholder: input.placeholder,
        showCounter: input.showCounter,
        dateShortcuts:
            input.dateShortcuts?.call(BeakFormReader(draft)) ?? const [],
      );
      if (input.controlHeight == null &&
          input.multilineContentPadding == null) {
        return editor;
      }
      final theme = OiTheme.of(context);
      return OiTheme(
        data: theme.copyWith(
          components: theme.components.copyWith(
            textInput:
                (theme.components.textInput ?? const OiTextInputThemeData())
                    .copyWith(
                      height: input.controlHeight,
                      multilineContentPadding: input.multilineContentPadding
                          ?.resolve(Directionality.of(context)),
                    ),
          ),
        ),
        child: editor,
      );
    }
    if (input.currency) {
      return BeakCurrencyField(input: input, draft: draft, enabled: enabled);
    }
    final control =
        beakFormFieldFor(
          controller: draft.controller,
          column: column,
          label: label,
          description: input.description,
          enabled: enabled,
          obscureText: input.obscureText,
          uploader: draft.session.uploader,
          filePicker: draft.session.filePicker,
        ) ??
        const SizedBox.shrink();
    return OiAfScope(
      rawController: draft.controller,
      messageResolver: const OiAfDefaultMessageResolver(),
      child: OiColumn(
        breakpoint: context.breakpoint,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          control,
          if (error != null &&
              draft.controller.getError(draft.controller.slotOf(column)) !=
                  error)
            OiLabel.caption(error, color: context.colors.error.base),
        ],
      ),
    );
  }
}

class _RelationInput extends HookWidget {
  const _RelationInput({
    required this.input,
    required this.draft,
    required this.readOnly,
    this.showLabel = true,
  });
  final BeakRelationInput input;
  final BeakDraftRecord draft;
  final bool readOnly;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final field = input.field;
    final refreshedItems = useMemoized(() => <BeakRecord>[], [
      draft.optionRevisionFor(field),
    ]);
    final label = showLabel ? input.label ?? field.label : '';
    final record = draft.read(field);
    if (readOnly) {
      if (input.template != null && record != null) {
        return OiColumn(
          breakpoint: context.breakpoint,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (label.isNotEmpty) OiLabel.caption(label),
            BeakRecordTemplateView(template: input.template!, record: record),
          ],
        );
      }
      return OiLabel.body(
        '${label.isEmpty ? '' : '$label: '}${record == null ? '' : field.relation.displayLabelOf(record)}',
      );
    }
    if (input.presentation == BeakRelationPresentation.code) {
      return _RelationCodeInput(input: input, draft: draft);
    }
    if (input.presentation != BeakRelationPresentation.combobox) {
      return _RelationChoices(input: input, draft: draft);
    }
    return OiColumn(
      breakpoint: context.breakpoint,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OiComboBox<BeakRecord>(
          items: refreshedItems,
          label: input.label ?? field.label,
          showLabel: showLabel,
          labelOf: (record) {
            final title = input.template?.title;
            return title == null
                ? field.relation.displayLabelOf(record)
                : BeakFormatting.of(context).format(
                    title.readFrom(record),
                    title.format ?? BeakValueFormat.text,
                  );
          },
          value: record,
          hint:
              input.descriptionBuilder?.call(BeakFormReader(draft)) ??
              input.description ??
              (draft.missingPrerequisites(input).isEmpty
                  ? null
                  : 'Select ${draft.missingPrerequisites(input).map((field) => field.label).join(', ')} first.'),
          enabled:
              !draft.session.submitting.value &&
              !draft.session.hasUnknown &&
              draft.enabled(input),
          error:
              draft.errors[field.key]?.join(' ') ??
              draft.optionErrors[field.key]?.message,
          clearable:
              !field.isRequired &&
              !input.validate.any((rule) => rule is BeakRequired),
          search: (term) => draft.search(input, term),
          onSelect: (value) => draft.select(field, value),
          onCreate: input.exclusive
              ? null
              : (term) async {
                  await _createRelatedOption(context, input, draft, term);
                },
        ),
        if (draft.optionErrors.containsKey(field.key))
          OiButton.ghost(
            label: 'Retry options',
            onTap: () => draft.search(input, ''),
          ),
      ],
    );
  }
}

class _RelationCodeInput extends HookWidget {
  const _RelationCodeInput({required this.input, required this.draft});

  final BeakRelationInput input;
  final BeakDraftRecord draft;

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController();
    useListenable(controller);
    final pending = useState(false);
    final issue = useState<String?>(null);
    final record = draft.read(input.field);
    final enabled =
        !draft.session.submitting.value &&
        !draft.session.hasUnknown &&
        draft.enabled(input) &&
        draft.missingPrerequisites(input).isEmpty;

    Future<void> apply() async {
      if (!enabled ||
          pending.value ||
          record != null ||
          controller.text.trim().isEmpty) {
        return;
      }
      pending.value = true;
      issue.value = null;
      try {
        final records = await draft.search(input, controller.text);
        if (!context.mounted) return;
        if (records.length != 1) {
          issue.value =
              draft.optionErrors[input.field.key]?.message ??
              (records.isEmpty
                  ? 'No available record matches this code.'
                  : 'This code matches more than one record.');
          return;
        }
        final reason = input.disabledReason?.call(
          records.single,
          BeakFormReader(draft),
        );
        if (reason != null) {
          issue.value = reason;
          return;
        }
        draft.select(input.field, records.single);
        controller.clear();
      } finally {
        if (context.mounted) pending.value = false;
      }
    }

    return OiColumn(
      breakpoint: context.breakpoint,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      gap: const OiResponsive<double>(8),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OiTextInput(
                semanticLabel: input.label ?? input.field.label,
                controller: controller,
                placeholder: input.placeholder,
                enabled: enabled && !pending.value && record == null,
                error: issue.value ?? draft.errors[input.field.key]?.join(' '),
                onChanged: (_) => issue.value = null,
                onSubmitted: (_) => apply(),
              ),
            ),
            const SizedBox(width: 8),
            OiButton.outline(
              label: 'Apply',
              loading: pending.value,
              enabled:
                  enabled &&
                  record == null &&
                  controller.text.trim().isNotEmpty,
              onTap: apply,
            ),
          ],
        ),
        if (record != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: OiSurface(
              color: context.colors.surfaceSubtle,
              borderRadius: context.radius.md,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    OiIcon.raw(
                      OiIcons.circleCheck,
                      color: context.colors.success.base,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: input.template == null
                          ? OiLabel.body(
                              input.field.relation.displayLabelOf(record),
                            )
                          : BeakRecordTemplateView(
                              template: input.template!,
                              record: record,
                            ),
                    ),
                    if (input.selectionSummary case final summary?) ...[
                      const SizedBox(width: 12),
                      IntrinsicWidth(
                        child: _FormNodeView(
                          node: summary,
                          draft: draft,
                          readOnly: true,
                        ),
                      ),
                    ],
                    OiButton.ghost(
                      size: OiButtonSize.small,
                      label: 'Remove',
                      enabled: enabled && !pending.value,
                      onTap: () {
                        draft.select(input.field, null);
                        issue.value = null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (input.descriptionBuilder?.call(BeakFormReader(draft)) ??
                input.description
            case final description?)
          OiLabel.caption(description, color: context.colors.textMuted),
      ],
    );
  }
}

Future<void> _createRelatedOption(
  BuildContext context,
  BeakRelationInput input,
  BeakDraftRecord draft,
  String term,
) async {
  final checkpoint = draft.checkpoint();
  final child = draft.createSelection(input);
  final displayColumn = child.model.columnByKey(child.model.displayColumnKey);
  if (displayColumn != null && child.controller.hasFieldFor(displayColumn)) {
    child.controller.setValue<Object>(displayColumn, term);
  }
  final accepted = await _editModal(
    context,
    child,
    child.layout,
    title: input.createLabel ?? 'Create ${input.field.label}',
  );
  if (accepted != true) {
    draft.restore(checkpoint);
  }
}

class _RelationChoices extends StatelessWidget {
  const _RelationChoices({required this.input, required this.draft});
  final BeakRelationInput input;
  final BeakDraftRecord draft;

  @override
  Widget build(BuildContext context) {
    final field = input.field;
    final selected = draft.read(field);
    final prerequisites = draft.missingPrerequisites(input);
    final enabled =
        draft.enabled(input) &&
        !draft.session.submitting.value &&
        !draft.session.hasUnknown;
    return _RecordOptions(
      queryKey: (input, draft.optionRevisionFor(field)),
      pinnedItems:
          selected != null && field.target.primaryKeyOf(selected) == null
          ? [selected]
          : const [],
      load: (term) => draft.search(input, term),
      label: input.label ?? field.label,
      description:
          input.descriptionBuilder?.call(BeakFormReader(draft)) ??
          input.description,
      descriptionInline: input.descriptionInline,
      divider: input.divider,
      search: input.presentation == BeakRelationPresentation.search,
      compactResults: input.presentation == BeakRelationPresentation.search,
      grid: input.presentation == BeakRelationPresentation.cards,
      minCardWidth: input.minCardWidth,
      enabled: enabled,
      onCreate: input.exclusive
          ? null
          : (term) => _createRelatedOption(context, input, draft, term),
      createLabel:
          input.createLabelBuilder?.call(BeakFormReader(draft)) ??
          input.createLabel ??
          'Create ${field.label}',
      createDescription: input.createDescription,
      createIcon: input.createIcon,
      blockedMessage: prerequisites.isEmpty
          ? null
          : 'Select ${prerequisites.map((field) => field.label).join(', ')} first.',
      error:
          draft.errors[field.key]?.join(' ') ??
          draft.optionErrors[field.key]?.message,
      itemBuilder: (record, query) {
        final reason = input.disabledReason?.call(
          record,
          BeakFormReader(draft),
        );
        final name = field.relation.displayLabelOf(record);
        final recommended =
            reason == null &&
            (input.defaultOptionMatch?.call(record, BeakFormReader(draft)) ??
                (input.defaultOption != null &&
                    field.target.primaryKeyOf(record) ==
                        field.target.primaryKeyOf(
                          draft.read(input.defaultOption!) ??
                              const BeakRecord(values: {}),
                        )));
        final separateBody =
            input.presentation == BeakRelationPresentation.cards &&
            !input.compact &&
            input.template != null &&
            (input.template!.details.isNotEmpty ||
                input.template!.footnote != null);
        return OiRadioTile<Object>.card(
          key: ValueKey(
            '${field.key}:${field.target.primaryKeyOf(record) ?? 'local'}',
          ),
          title: name,
          controlLeading:
              input.presentation == BeakRelationPresentation.cards &&
              !input.compact,
          bordered: input.presentation == BeakRelationPresentation.cards,
          indicator: input.compact
              ? OiRadioTileIndicator.none
              : input.presentation == BeakRelationPresentation.search
              ? OiRadioTileIndicator.check
              : OiRadioTileIndicator.radio,
          dense:
              input.presentation == BeakRelationPresentation.search ||
              input.compact,
          contentPadding:
              input.cardPadding ??
              (input.presentation == BeakRelationPresentation.search
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                  : input.compact
                  ? const EdgeInsets.all(12)
                  : const EdgeInsets.all(16)),
          titleWidget: input.template == null
              ? null
              : BeakRecordTemplateView(
                  template: input.template!,
                  record: record,
                  highlightQuery:
                      input.presentation == BeakRelationPresentation.search
                      ? query
                      : null,
                  titleTrailing: recommended && !input.compact
                      ? OiBadge.soft(
                          label: input.defaultOptionLabel,
                          color: OiBadgeColor.info,
                        )
                      : null,
                  avatarTone:
                      input.presentation == BeakRelationPresentation.search &&
                          selected != null &&
                          field.target.primaryKeyOf(selected) ==
                              field.target.primaryKeyOf(record)
                      ? BeakAvatarTone(
                          background: context.colors.surface,
                          foreground: context.colors.primary.base,
                        )
                      : null,
                  detailsLeading:
                      input.compact &&
                          selected != null &&
                          field.target.primaryKeyOf(selected) ==
                              field.target.primaryKeyOf(record)
                      ? OiIcon.raw(
                          OiIcons.check,
                          size: 12,
                          color: context.colors.primary.base,
                        )
                      : null,
                  part: separateBody
                      ? BeakRecordTemplatePart.identity
                      : BeakRecordTemplatePart.all,
                  inlineSubtitle:
                      input.presentation == BeakRelationPresentation.search
                      ? true
                      : null,
                ),
          bodyWidget: separateBody
              ? BeakRecordTemplateView(
                  template: input.template!,
                  record: record,
                  part: BeakRecordTemplatePart.details,
                )
              : null,
          value: field.target.primaryKeyOf(record) ?? field,
          groupValue: selected == null
              ? null
              : field.target.primaryKeyOf(selected) ?? field,
          subtitle: reason,
          enabled: enabled && reason == null,
          onChanged: (_) {
            if (field.target.primaryKeyOf(record) != null) {
              draft.select(field, record);
            }
          },
        );
      },
    );
  }
}

class _CatalogPicker extends HookWidget {
  const _CatalogPicker({required this.table, required this.draft});
  final BeakRelationTable table;
  final BeakDraftRecord draft;

  @override
  Widget build(BuildContext context) {
    final catalog = table.catalog!;
    final selectedTab = useState(0);
    final selectedFilters = useState(<int>{});
    final selectedVariants = useState(<Object?, Object?>{});
    final expandedRows = useState(<String>{});
    final page = useState(0);
    final dataRevision = useBeakDataRevision(
      draft.session.repository.dataSource,
      table: catalog.selection.target.table,
    );
    final rows = catalog.presentation == BeakCatalogPresentation.rows;
    final checkboxes =
        catalog.presentation == BeakCatalogPresentation.checkboxes;
    final facets = [
      if (catalog.tabs.isNotEmpty)
        catalog.tabs[selectedTab.value.clamp(0, catalog.tabs.length - 1)],
      for (final index in selectedFilters.value) catalog.filters[index],
    ];
    final active = [
      for (final facet in facets) ...[
        ?facet.filter,
        ?facet.filterBuilder?.call(BeakFormReader(draft)),
      ],
    ];
    final filter = active.isEmpty ? null : BeakAndFilter(active);
    final base = draft.catalogQuery(table, '', filter: filter);
    useEffect(() {
      page.value = 0;
      return null;
    }, [base, selectedTab.value, selectedFilters.value]);

    final enabled =
        draft.enabled(table) &&
        !draft.session.submitting.value &&
        !draft.session.hasUnknown;
    return _RecordOptions(
      queryKey: (base, dataRevision),
      pinnedItems: checkboxes
          ? [
              for (final row in draft.rows(table.field))
                ?row.read(catalog.selection),
            ]
          : const [],
      label: checkboxes ? '' : catalog.searchLabel,
      searchPlaceholder: rows,
      recordFilter: (record) =>
          facets.every((facet) => facet.matches?.call(record) ?? true),
      search: !checkboxes,
      enabled: enabled,
      searchTrailing:
          catalog.compactToolbar &&
              catalog.tabs.isNotEmpty &&
              catalog.tabs.length <= 5
          ? OiSegmentedControl<int>(
              semanticLabel: 'Catalog categories',
              segments: [
                for (var index = 0; index < catalog.tabs.length; index++)
                  OiSegment(value: index, label: catalog.tabs[index].label),
              ],
              selected: selectedTab.value,
              onChanged: (index) => selectedTab.value = index,
              enabled: enabled,
              size: OiSegmentedControlSize.medium,
            )
          : null,
      toolbar:
          catalog.tabs.isEmpty &&
              catalog.filters.isEmpty &&
              catalog.notice == null
          ? null
          : OiColumn(
              breakpoint: context.breakpoint,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              gap: const OiResponsive<double>(12),
              children: [
                if (catalog.tabs.isNotEmpty &&
                    (!catalog.compactToolbar || catalog.tabs.length > 5))
                  OiTabs(
                    tabs: [
                      for (final tab in catalog.tabs)
                        OiTabItem(label: tab.label),
                    ],
                    selectedIndex: selectedTab.value,
                    onSelected: enabled
                        ? (index) => selectedTab.value = index
                        : (_) {},
                    scrollable: true,
                  ),
                if (catalog.filters.isNotEmpty)
                  Wrap(
                    spacing: catalog.compactToolbar ? 8 : 16,
                    runSpacing: 8,
                    children: [
                      for (
                        var index = 0;
                        index < catalog.filters.length;
                        index++
                      )
                        if (catalog.compactToolbar)
                          OiFilterChip(
                            label: catalog.filters[index].label,
                            selected: selectedFilters.value.contains(index),
                            onTap: enabled
                                ? () => selectedFilters.value =
                                      selectedFilters.value.contains(index)
                                      ? ({...selectedFilters.value}
                                          ..remove(index))
                                      : {...selectedFilters.value, index}
                                : null,
                          )
                        else
                          OiCheckbox(
                            label: catalog.filters[index].label,
                            value: selectedFilters.value.contains(index),
                            onChanged: enabled
                                ? (value) {
                                    selectedFilters.value = value == true
                                        ? {...selectedFilters.value, index}
                                        : ({...selectedFilters.value}
                                            ..remove(index));
                                  }
                                : null,
                          ),
                    ],
                  ),
                if (catalog.notice case final notice?
                    when draft.visible(notice))
                  _formNotice(context, notice, BeakFormReader(draft)),
              ],
            ),
      load: (term) async {
        page.value = 0;
        final query = draft.catalogQuery(table, term, filter: filter);
        final maximum = catalog.maxOptions;
        final records = <BeakRecord>[];
        var nextPage = 1;
        while (true) {
          final result = (await draft.session.repository.query(
            maximum == null
                ? query
                : query.paginate(
                    page: nextPage,
                    perPage: math.min(maximum, 200),
                  ),
          )).valueOrThrow;
          if ((maximum != null && result.total > maximum) ||
              (maximum == null &&
                  catalog.groupBy != null &&
                  result.total > result.items.length)) {
            throw const BeakConfigurationException(
              'Too many catalog options. Refine the search or filters.',
            );
          }
          records.addAll(result.items);
          if (maximum == null || records.length >= result.total) break;
          if (result.items.isEmpty) {
            throw const BeakConfigurationException(
              'The catalog changed while loading. Retry the search.',
            );
          }
          nextPage++;
        }
        return records;
      },
      itemsBuilder: checkboxes
          ? (records) => Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                for (final record in {
                  for (final selected
                      in draft
                          .rows(table.field)
                          .map((row) => row.read(catalog.selection))
                          .whereType<BeakRecord>())
                    catalog.selection.target.primaryKeyOf(selected): selected,
                  for (final record in records)
                    catalog.selection.target.primaryKeyOf(record): record,
                }.values)
                  _CatalogCheckbox(
                    table: table,
                    draft: draft,
                    record: record,
                    enabled: enabled,
                  ),
              ],
            )
          : !rows && catalog.groupBy == null && catalog.quantity == null
          ? null
          : (records) {
              final groups = <Object?, List<BeakRecord>>{};
              for (final record in records) {
                final group =
                    catalog.groupBy?.readFrom(record) ??
                    catalog.selection.target.primaryKeyOf(record);
                groups.putIfAbsent(group, () => []).add(record);
              }
              final entries = groups.entries.toList();
              final preferred =
                  catalog.groupOrder?.call(BeakFormReader(draft)) ??
                  const <Object>[];
              if (preferred.isNotEmpty) {
                final original = {
                  for (var i = 0; i < entries.length; i++) entries[i].key: i,
                };
                int rank(Object? key) {
                  final index = preferred.indexOf(key!);
                  return index < 0 ? preferred.length + original[key]! : index;
                }

                entries.sort((a, b) => rank(a.key).compareTo(rank(b.key)));
              }
              final perPage = catalog.pageSize ?? math.max(entries.length, 1);
              final current = page.value
                  .clamp(0, math.max(0, (entries.length - 1) ~/ perPage))
                  .toInt();
              return OiColumn(
                breakpoint: context.breakpoint,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                gap: OiResponsive<double>(rows ? 0 : 12),
                children: [
                  if (rows)
                    if (catalog.columnLabels case final labels?)
                      LayoutBuilder(
                        builder: (context, constraints) =>
                            constraints.maxWidth < 600
                            ? const SizedBox.shrink()
                            : Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 18,
                                      bottom: 13,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: OiLabel.caption(
                                            labels.item,
                                            color: context.colors.textMuted,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        SizedBox(
                                          width: 160,
                                          child: OiLabel.caption(
                                            labels.variant,
                                            color: context.colors.textMuted,
                                          ),
                                        ),
                                        const SizedBox(width: 22),
                                        SizedBox(
                                          width: 92,
                                          child: OiLabel.caption(
                                            labels.quantity,
                                            textAlign: TextAlign.end,
                                            color: context.colors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OiDivider(color: context.colors.border),
                                ],
                              ),
                      ),
                  for (final group
                      in entries.skip(current * perPage).take(perPage))
                    _CatalogGroup(
                      key: ValueKey(group.key),
                      table: table,
                      draft: draft,
                      records: group.value,
                      enabled: enabled,
                      selectedId: selectedVariants.value[group.key],
                      onVariantChanged: (value) => selectedVariants.value = {
                        ...selectedVariants.value,
                        group.key: value,
                      },
                      expandedRows: expandedRows,
                    ),
                  if (catalog.pageSize != null && entries.length > perPage)
                    OiPagination(
                      totalItems: entries.length,
                      currentPage: current,
                      label: 'groups',
                      perPage: perPage,
                      showPerPage: false,
                      onPageChange: enabled
                          ? (value) => page.value = value
                          : null,
                    ),
                  if (catalog.footer != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OiLabel.caption(
                        catalog.footer!,
                        color: context.colors.textMuted,
                      ),
                    ),
                ],
              );
            },
      itemBuilder: (record, query) {
        final reason = catalog.disabledReason?.call(
          record,
          BeakFormReader(draft),
        );
        return OiCard(
          child: OiRow(
            breakpoint: context.breakpoint,
            gap: const OiResponsive<double>(12),
            children: [
              Expanded(
                child: BeakRecordTemplateView(
                  template: catalog.template,
                  record: record,
                ),
              ),
              if (reason != null) Flexible(child: OiLabel.caption(reason)),
              OiButton.secondary(
                label: catalog.addLabel,
                semanticLabel:
                    '${catalog.addLabel} ${catalog.selection.relation.displayLabelOf(record)}',
                onTap: enabled && reason == null
                    ? () => draft.addCatalogRow(table, record)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CatalogCheckbox extends StatelessWidget {
  const _CatalogCheckbox({
    required this.table,
    required this.draft,
    required this.record,
    required this.enabled,
  });
  final BeakRelationTable table;
  final BeakDraftRecord draft;
  final BeakRecord record;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final catalog = table.catalog!;
    final target = catalog.selection.target;
    final id = target.primaryKeyOf(record);
    final rows = draft.rows(table.field).where((row) {
      final selected = row.read(catalog.selection);
      return selected != null && target.primaryKeyOf(selected) == id;
    }).toList();
    final reason = catalog.disabledReason?.call(record, BeakFormReader(draft));
    final selected = rows.isNotEmpty;
    return OiCheckbox(
      value: selected,
      semanticLabel: catalog.selection.relation.displayLabelOf(record),
      labelWidget: BeakRecordTemplateView(
        template: catalog.template,
        record: record,
      ),
      enabled:
          enabled &&
          (selected ? table.allowRemove : table.allowAdding && reason == null),
      onChanged: (value) {
        if (value) {
          draft.addCatalogRow(table, record);
        } else {
          for (final row in rows) {
            draft.removeRow(row);
          }
        }
      },
    );
  }
}

class _CatalogGroup extends StatelessWidget {
  const _CatalogGroup({
    required this.table,
    required this.draft,
    required this.records,
    required this.enabled,
    required this.selectedId,
    required this.onVariantChanged,
    required this.expandedRows,
    super.key,
  });
  final BeakRelationTable table;
  final BeakDraftRecord draft;
  final List<BeakRecord> records;
  final bool enabled;
  final Object? selectedId;
  final ValueChanged<Object?> onVariantChanged;
  final ValueNotifier<Set<String>> expandedRows;

  @override
  Widget build(BuildContext context) {
    final catalog = table.catalog!;
    final expanded = expandedRows;
    final target = catalog.selection.target;
    final record =
        records
            .where((record) => target.primaryKeyOf(record) == selectedId)
            .firstOrNull ??
        records.first;
    final id = target.primaryKeyOf(record)!;
    final title = BeakFormatting.of(context).format(
      catalog.template.title.readFrom(record),
      catalog.template.title.format ?? BeakValueFormat.text,
    );
    final variantName = catalog.variantLabel?.readFrom(record);
    final identityLabel = variantName == null || variantName == title
        ? title
        : '$title, $variantName';
    final matching = draft.rows(table.field).where((row) {
      final selected = row.read(catalog.selection);
      return selected != null && target.primaryKeyOf(selected) == id;
    }).toList();
    final quantity = catalog.quantity;
    final count = quantity == null
        ? matching.length
        : matching.fold<int>(
            0,
            (total, row) => total + (row.read(quantity) ?? 0),
          );
    final reason = catalog.disabledReason?.call(record, BeakFormReader(draft));
    bool canChange(BeakDraftRecord row) =>
        table.allowEdit &&
        (quantity == null ||
            (row.capabilities.canWrite(quantity.key) &&
                row.model.behavior.canEdit(quantity.key, row.initialRecord)));
    void increment() {
      if (quantity != null && matching.isNotEmpty) {
        final row = matching.first;
        row.set(quantity, (row.read(quantity) ?? 0) + 1);
      } else {
        final row = draft.addCatalogRow(table, record);
        if (quantity != null && (row.read(quantity) ?? 0) < 1) {
          row.set(quantity, 1);
        }
      }
    }

    void decrement() {
      final row = matching.last;
      final amount = quantity == null ? 1 : row.read(quantity) ?? 0;
      if (quantity != null && amount > 1) {
        row.set(quantity, amount - 1);
      } else {
        draft.removeRow(row);
      }
    }

    final canIncrease =
        enabled &&
        reason == null &&
        (matching.isEmpty || quantity == null
            ? table.allowAdding
            : canChange(matching.first));
    final canDecrease =
        enabled &&
        matching.isNotEmpty &&
        (quantity != null && (matching.last.read(quantity) ?? 0) > 1
            ? canChange(matching.last)
            : table.allowRemove);
    Future<void> editOptions(int index) async {
      final row = matching[index];
      if (table.advancedPresentation == BeakAdvancedPresentation.inline) {
        expanded.value = expanded.value.contains(row.localId)
            ? ({...expanded.value}..remove(row.localId))
            : {...expanded.value, row.localId};
        return;
      }
      final checkpoint = row.checkpoint();
      final accepted = await _editModal(
        context,
        row,
        table.advancedForm!,
        title: catalog.selection.relation.displayLabelOf(record),
      );
      if (accepted != true) row.restore(checkpoint);
    }

    if (catalog.presentation == BeakCatalogPresentation.rows) {
      final showVariant =
          records.length > 1 ||
          catalog.variantLabel != null ||
          catalog.price != null;
      String optionText(BeakRecord option) => [
        catalog.variantLabel?.readFrom(option) ??
            catalog.selection.relation.displayLabelOf(option),
        if (catalog.price case final price?)
          formatBeakField(context, field: price, record: option),
      ].join(' · ');
      Widget variant = SizedBox(
        width: 160,
        child: records.length > 1
            ? Semantics(
                label: 'Variant for ${catalog.template.title.readFrom(record)}',
                child: OiSelect<Object>(
                  value: id,
                  options: [
                    for (final option in records)
                      OiSelectOption(
                        value: target.primaryKeyOf(option)!,
                        label: optionText(option),
                      ),
                  ],
                  onChanged: enabled ? onVariantChanged : null,
                ),
              )
            : OiLabel.body(optionText(record), maxLines: 2),
      );
      if (catalog.controlHeight != null) {
        final theme = OiTheme.of(context);
        variant = OiTheme(
          data: theme.copyWith(
            components: theme.components.copyWith(
              textInput:
                  (theme.components.textInput ?? const OiTextInputThemeData())
                      .copyWith(
                        height: catalog.controlHeight,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
            ),
          ),
          child: variant,
        );
      }
      final controls = Wrap(
        alignment: WrapAlignment.end,
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (quantity != null && count > 0)
            SizedBox(
              width: 90,
              child: OiQuantitySelector(
                value: count,
                label: identityLabel,
                decreaseLabel: 'Decrease $identityLabel',
                increaseLabel: 'Increase $identityLabel',
                compact: true,
                min: canDecrease ? 0 : count,
                max: canIncrease ? math.max(count + 1, 0x7fffffff) : count,
                onChange: (value) => value > count ? increment() : decrement(),
                disabled: !enabled,
              ),
            )
          else
            SizedBox(
              width: 90,
              child: OiButton.secondary(
                label: catalog.addLabel,
                icon: OiIcons.plus,
                size: OiButtonSize.small,
                semanticLabel: quantity == null
                    ? '${catalog.addLabel} $identityLabel'
                    : 'Increase $identityLabel',
                onTap: canIncrease ? increment : null,
              ),
            ),
        ],
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final identity = BeakRecordTemplateView(
                  template: catalog.template,
                  record: record,
                  inlineSubtitle: true,
                  metadataTrailing:
                      table.advancedForm != null &&
                          table.allowEdit &&
                          matching.isNotEmpty &&
                          (catalog.advancedLabel?.visibleFrom(record) ?? true)
                      ? Wrap(
                          children: [
                            for (var i = 0; i < matching.length; i++)
                              if (catalog.advancedLabel != null)
                                MergeSemantics(
                                  child: OiTappable(
                                    semanticLabel: matching.length == 1
                                        ? 'Options for $identityLabel'
                                        : 'Options for $identityLabel item ${i + 1}',
                                    onTap: enabled
                                        ? () => editOptions(i)
                                        : null,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          OiLabel.caption(
                                            catalog.advancedLabel!.readFrom(
                                                  record,
                                                ) ??
                                                'Options',
                                            color: context.colors.primary.base,
                                          ),
                                          const SizedBox(width: 6),
                                          OiIcon.raw(
                                            expanded.value.contains(
                                                  matching[i].localId,
                                                )
                                                ? OiIcons.chevronUp
                                                : OiIcons.chevronDown,
                                            size: 12,
                                            color: context.colors.primary.base,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              else
                                OiButton.icon(
                                  label: matching.length == 1
                                      ? 'Options'
                                      : 'Options for item ${i + 1}',
                                  icon: OiIcons.chevronDown,
                                  size: OiButtonSize.small,
                                  onTap: enabled ? () => editOptions(i) : null,
                                ),
                          ],
                        )
                      : null,
                );
                final actions = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showVariant) ...[variant, const SizedBox(width: 22)],
                    SizedBox(width: 92, child: controls),
                  ],
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (constraints.maxWidth >= 600)
                      Row(
                        children: [
                          Expanded(child: identity),
                          const SizedBox(width: 16),
                          actions,
                        ],
                      )
                    else ...[
                      identity,
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [if (showVariant) variant, controls],
                      ),
                    ],
                    if (reason != null) OiLabel.caption(reason),
                    if (table.advancedPresentation ==
                        BeakAdvancedPresentation.inline)
                      for (final row in matching)
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            start:
                                constraints.maxWidth >= 600 &&
                                    catalog.template.icon != null
                                ? catalog.template.iconSize +
                                      catalog.template.identityGap
                                : 0,
                          ),
                          child: _InlineRelationAdvanced(
                            key: ValueKey('advanced:${row.localId}'),
                            topSpacing: 15,
                            table: table,
                            row: row,
                            readOnly: !enabled || !table.allowEdit,
                            expanded: expanded.value.contains(row.localId),
                            onChanged: (value) {
                              expanded.value = value
                                  ? {...expanded.value, row.localId}
                                  : ({...expanded.value}..remove(row.localId));
                            },
                            showHeading: false,
                          ),
                        ),
                  ],
                );
              },
            ),
          ),
          OiDivider(color: context.colors.borderSubtle),
        ],
      );
    }
    return OiCard(
      child: OiColumn(
        breakpoint: context.breakpoint,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        gap: const OiResponsive<double>(12),
        children: [
          BeakRecordTemplateView(template: catalog.template, record: record),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (records.length > 1)
                SizedBox(
                  width: 200,
                  child: OiSelect<Object>(
                    label: 'Variant',
                    value: id,
                    options: [
                      for (final option in records)
                        OiSelectOption<Object>(
                          value: target.primaryKeyOf(option)!,
                          label:
                              catalog.variantLabel?.readFrom(option) ??
                              catalog.selection.relation.displayLabelOf(option),
                        ),
                    ],
                    onChanged: enabled ? onVariantChanged : null,
                  ),
                ),
              if (catalog.price case final BeakScalarField<Object> price)
                renderBeakField(context, field: price, record: record),
              if (quantity != null)
                OiRow(
                  breakpoint: context.breakpoint,
                  mainAxisSize: MainAxisSize.min,
                  gap: const OiResponsive<double>(8),
                  children: [
                    OiButton.ghost(
                      label: '−',
                      semanticLabel:
                          'Decrease ${catalog.selection.relation.displayLabelOf(record)}',
                      onTap: canDecrease ? decrement : null,
                    ),
                    OiLabel.bodyStrong('$count'),
                    OiButton.ghost(
                      label: '+',
                      semanticLabel:
                          'Increase ${catalog.selection.relation.displayLabelOf(record)}',
                      onTap: canIncrease ? increment : null,
                    ),
                  ],
                )
              else
                OiButton.secondary(
                  label: catalog.addLabel,
                  onTap: canIncrease ? increment : null,
                ),
            ],
          ),
          if (reason != null) OiLabel.caption(reason),
          if (table.advancedForm != null && table.allowEdit)
            for (var i = 0; i < matching.length; i++)
              OiButton.ghost(
                label: matching.length == 1
                    ? 'Options'
                    : 'Options for item ${i + 1}',
                onTap: !enabled ? null : () => editOptions(i),
              ),
          if (table.advancedPresentation == BeakAdvancedPresentation.inline)
            for (final row in matching)
              _InlineRelationAdvanced(
                key: ValueKey('advanced:${row.localId}'),
                table: table,
                row: row,
                readOnly: !enabled || !table.allowEdit,
                expanded: expanded.value.contains(row.localId),
                onChanged: (value) {
                  expanded.value = value
                      ? {...expanded.value, row.localId}
                      : ({...expanded.value}..remove(row.localId));
                },
                showHeading: false,
              ),
        ],
      ),
    );
  }
}

/// Shared asynchronous option surface; it owns only transient search text.
class _RecordOptions extends HookWidget {
  const _RecordOptions({
    required this.queryKey,
    required this.load,
    required this.label,
    required this.itemBuilder,
    this.itemsBuilder,
    required this.enabled,
    required this.search,
    this.grid = false,
    this.minCardWidth = 260,
    this.compactResults = false,
    this.searchPlaceholder = false,
    this.recordFilter,
    this.description,
    this.descriptionInline = false,
    this.divider = false,
    this.error,
    this.blockedMessage,
    this.onCreate,
    this.createLabel,
    this.createDescription,
    this.createIcon,
    this.toolbar,
    this.searchTrailing,
    this.pinnedItems = const [],
  });
  final Future<void> Function(String term)? onCreate;
  final String? createLabel;
  final String? createDescription;
  final IconData? createIcon;
  final Widget? toolbar;
  final Widget? searchTrailing;
  final List<BeakRecord> pinnedItems;
  final Object queryKey;
  final Future<List<BeakRecord>> Function(String) load;
  final String label;
  final Widget Function(BeakRecord, String) itemBuilder;
  final Widget Function(List<BeakRecord>)? itemsBuilder;
  final bool enabled, search, grid, compactResults;
  final double minCardWidth;
  final bool searchPlaceholder;
  final bool descriptionInline, divider;
  final bool Function(BeakRecord record)? recordFilter;
  final String? description, error, blockedMessage;

  @override
  Widget build(BuildContext context) {
    final term = useState('');
    final requestedTerm = useState('');
    final retry = useState(0);
    final controller = useTextEditingController();
    useEffect(() {
      final timer = Timer(
        const Duration(milliseconds: 200),
        () => requestedTerm.value = term.value,
      );
      return timer.cancel;
    }, [term.value]);
    final request = useMemoized(
      () => blockedMessage == null
          ? load(requestedTerm.value)
          : Future.value(<BeakRecord>[]),
      [queryKey, requestedTerm.value, retry.value, blockedMessage],
    );
    final result = useFuture(request, preserveState: false);
    final records = [
      ...pinnedItems,
      ...?result.data,
    ].where((record) => recordFilter?.call(record) ?? true).toList();
    Widget createButton() => grid
        ? MergeSemantics(
            child: OiTappable(
              semanticLabel: createLabel ?? 'Create new',
              onTap: enabled && blockedMessage == null
                  ? () => onCreate!(term.value)
                  : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OiIcon.raw(
                      createIcon ?? OiIcons.plus,
                      size: 14,
                      color: context.colors.primary.base,
                    ),
                    const SizedBox(width: 8),
                    OiLabel.body(
                      createLabel ?? 'Create new',
                      color: context.colors.primary.base,
                    ),
                  ],
                ),
              ),
            ),
          )
        : OiButton.ghost(
            label: createLabel ?? 'Create new',
            size: OiButtonSize.small,
            icon: createIcon ?? OiIcons.plus,
            onTap: enabled && blockedMessage == null
                ? () => onCreate!(term.value)
                : null,
          );
    Widget createRow() => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OiDivider(color: context.colors.borderSubtle),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: MergeSemantics(
            child: OiTappable(
              semanticLabel: createLabel ?? 'Create new',
              onTap: enabled && blockedMessage == null
                  ? () => onCreate!(term.value)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceSubtle,
                          borderRadius: context.radius.md,
                        ),
                        child: OiIcon.raw(
                          createIcon ?? OiIcons.plus,
                          size: 16,
                          color: context.colors.primary.base,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OiLabel.body(
                              createLabel ?? 'Create new',
                              color: context.colors.primary.base,
                            ),
                            if (createDescription != null)
                              OiLabel.caption(
                                createDescription!,
                                color: context.colors.textMuted,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    final content = OiColumn(
      breakpoint: context.breakpoint,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      gap: OiResponsive<double>(descriptionInline ? 8 : 12),
      children: [
        if ((!search || compactResults) &&
            (label.isNotEmpty || description != null))
          OiColumn(
            breakpoint: context.breakpoint,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            gap: const OiResponsive<double>(2),
            children: [
              if (descriptionInline)
                Row(
                  children: [
                    Expanded(child: OiLabel.h4(label)),
                    if (description != null)
                      Flexible(
                        child: OiLabel.caption(
                          description!,
                          color: context.colors.textMuted,
                          textAlign: TextAlign.end,
                        ),
                      ),
                  ],
                )
              else if (label.isNotEmpty)
                if (grid && onCreate != null)
                  OiRow(
                    breakpoint: context.breakpoint,
                    children: [
                      Expanded(child: OiLabel.h4(label)),
                      createButton(),
                    ],
                  )
                else
                  OiLabel.h4(label),
              if (description != null && !descriptionInline)
                OiLabel.body(description!, color: context.colors.textMuted),
            ],
          ),
        if (search)
          LayoutBuilder(
            builder: (context, constraints) {
              final input = Semantics(
                label: label,
                child: OiTextInput(
                  controller: controller,
                  label: compactResults || searchPlaceholder ? null : label,
                  placeholder: searchPlaceholder ? label : null,
                  leading: const OiIcon.decorative(icon: OiIcons.search),
                  enabled: enabled,
                  onChanged: (value) => term.value = value,
                ),
              );
              if (searchTrailing == null) return input;
              return constraints.maxWidth >= 600
                  ? Row(
                      children: [
                        Expanded(child: input),
                        const SizedBox(width: 12),
                        searchTrailing!,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        input,
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: searchTrailing,
                        ),
                      ],
                    );
            },
          ),
        ?toolbar,

        if (blockedMessage != null)
          OiLabel.caption(blockedMessage!)
        else if (term.value != requestedTerm.value ||
            result.connectionState != ConnectionState.done)
          const OiProgress.linear(indeterminate: true, label: 'Loading options')
        else if (result.hasError) ...[
          OiBanner.error(
            message: result.error is BeakException
                ? (result.error! as BeakException).message
                : 'Could not load options.',
            dismissible: false,
          ),
          OiButton.ghost(label: 'Retry options', onTap: () => retry.value++),
        ] else if (records.isEmpty)
          const OiLabel.caption('No matching options.')
        else if (itemsBuilder != null)
          itemsBuilder!(records)
        else if (grid)
          OiGrid(
            breakpoint: context.breakpoint,
            minColumnWidth: OiResponsive<double>(minCardWidth),
            gap: const OiResponsive<double>(12),
            stretchRows: true,
            children: records
                .map((record) => itemBuilder(record, term.value))
                .toList(),
          )
        else if (compactResults)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  child: OiColumn(
                    breakpoint: context.breakpoint,
                    mainAxisSize: MainAxisSize.min,
                    gap: const OiResponsive<double>(4),
                    children: records
                        .map((record) => itemBuilder(record, term.value))
                        .toList(),
                  ),
                ),
              ),
              if (onCreate != null) ...[const SizedBox(height: 4), createRow()],
            ],
          )
        else
          ...records.map((record) => itemBuilder(record, term.value)),
        if (onCreate != null && !grid && (!compactResults || records.isEmpty))
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: createButton(),
          ),
        if (error != null) ...[
          OiLabel.caption(error!),
          OiButton.ghost(label: 'Retry options', onTap: () => retry.value++),
        ],
      ],
    );
    return !divider
        ? content
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              OiDivider(color: context.colors.borderSubtle),
              const SizedBox(height: 24),
              content,
            ],
          );
  }
}

Future<bool?> _editModal(
  BuildContext context,
  BeakDraftRecord draft,
  BeakFormLayout layout, {
  required String title,
}) => showOiDialog<bool>(
  context,
  builder: (context, close) => OiDialog.standard(
    label: title,
    title: title,
    content: Watch.builder(
      builder: (context) {
        draft.session.revision.value;
        return SingleChildScrollView(
          child: _FormNodeView(node: layout, draft: draft, readOnly: false),
        );
      },
    ),
    actions: [
      OiButton.ghost(label: 'Cancel', onTap: () => close(false)),
      OiButton.primary(
        label: 'Apply',
        onTap: () async {
          if (await draft.validate()) close(true);
        },
      ),
    ],
    onClose: () => close(false),
  ),
);

class _InlineRelationAdvanced extends HookWidget {
  const _InlineRelationAdvanced({
    required this.table,
    required this.row,
    required this.readOnly,
    this.expanded,
    this.onChanged,
    this.showHeading = true,
    this.topSpacing = 12,
    super.key,
  });
  final BeakRelationTable table;
  final BeakDraftRecord row;
  final bool readOnly;
  final bool? expanded;
  final ValueChanged<bool>? onChanged;
  final bool showHeading;
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    final local = useState(false);
    final layout = table.advancedForm;
    final open =
        (expanded ?? local.value) ||
        (layout != null && _errorsIn(layout, row) > 0);
    final opened = useState(open);
    useEffect(() {
      if (open) opened.value = true;
      return null;
    }, [open]);
    if (layout == null) return const SizedBox.shrink();
    final content = OiSurface(
      color: context.colors.surfaceSubtle,
      borderRadius: context.radius.md,
      child: Padding(
        padding: table.advancedContentPadding,
        child: _FormNodeView(node: layout, draft: row, readOnly: readOnly),
      ),
    );
    if (showHeading) {
      return OiDisclosure(
        title: 'Options',
        expanded: open,
        onChanged: onChanged ?? (value) => local.value = value,
        child: opened.value ? content : const SizedBox.shrink(),
      );
    }
    return Offstage(
      offstage: !open,
      child: ExcludeFocus(
        excluding: !open,
        child: Padding(
          padding: EdgeInsets.only(top: topSpacing),
          child: opened.value ? content : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _CompactRelationRows extends HookWidget {
  const _CompactRelationRows({
    required this.table,
    required this.draft,
    required this.locked,
  });
  final BeakRelationTable table;
  final BeakDraftRecord draft;
  final bool locked;

  String label(BeakFormNode node) => switch (node) {
    BeakInput<Object>(:final field, :final label) => label ?? field.label,
    BeakRelationInput(:final field, :final label) => label ?? field.label,
    BeakCalculated(:final label) => label ?? '',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final expanded = useState(<String>{});
    void toggle(BeakDraftRecord row) {
      expanded.value = expanded.value.contains(row.localId)
          ? ({...expanded.value}..remove(row.localId))
          : {...expanded.value, row.localId};
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final controlWidth =
            table.advancedPresentation == BeakAdvancedPresentation.inline
            ? 32.0
            : 72.0;
        final fixedWidths = table.columnWidths.whereType<double>();
        final minWidth = fixedWidths.isEmpty
            ? table.minRowWidth
            : math.max(
                table.minRowWidth,
                fixedWidths.fold<double>(120, (sum, width) => sum + width) +
                    table.children.length * 16 +
                    controlWidth,
              );
        final compact = constraints.maxWidth < minWidth;
        final rows = draft.rows(table.field);
        Widget cell(
          BeakFormNode node,
          BeakDraftRecord row, {
          bool identity = false,
        }) {
          if (identity || !compact) {
            if (node is BeakInput<Object>) {
              return _errorAnchor(
                context,
                row,
                node.field,
                _ScalarInput(
                  input: node,
                  draft: row,
                  readOnly: locked || !table.allowEdit || node.readOnly,
                  showLabel: false,
                ),
                enabled: !locked && table.allowEdit && !node.readOnly,
              );
            }
            if (node is BeakRelationInput) {
              return _errorAnchor(
                context,
                row,
                node.field,
                _RelationInput(
                  input: node,
                  draft: row,
                  readOnly: locked || !table.allowEdit,
                  showLabel: false,
                ),
                enabled: !locked && table.allowEdit,
              );
            }
            if (node is BeakCalculated) {
              final reader = BeakFormReader(row);
              final formatting = BeakFormatting.of(context);
              final subtitle =
                  node.subtitle?.call(reader, formatting) ??
                  node.description?.call(reader);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OiLabel.body(
                    node.display?.call(node.value(reader), formatting) ??
                        formatting.format(node.value(reader), node.format),
                    style: node.valueStyle,
                    textAlign: node.textAlign,
                  ),
                  if (subtitle != null)
                    OiLabel.caption(
                      subtitle,
                      textAlign: node.textAlign,
                      color: context.colors.textMuted,
                    ),
                ],
              );
            }
          }
          return _FormNodeView(
            node: node,
            draft: row,
            readOnly: locked || !table.allowEdit,
          );
        }

        final inlineAdvanced =
            table.advancedPresentation == BeakAdvancedPresentation.inline &&
            table.advancedForm != null;
        bool showAdvanced(BeakDraftRecord row) =>
            inlineAdvanced &&
            row.visible(table.advancedForm!) &&
            (!locked ||
                (table.advancedReadVisibleIf?.call(BeakFormReader(row)) ??
                    true));
        Widget identity(BeakDraftRecord row) {
          Widget? controls = table.identityChildren.isNotEmpty
              ? Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final node in table.identityChildren)
                      if (row.visible(node))
                        SizedBox(
                          width: table.identityControlWidth,
                          child: cell(node, row, identity: true),
                        ),
                  ],
                )
              : null;
          if (controls != null && table.identityControlHeight != null) {
            final theme = OiTheme.of(context);
            controls = OiTheme(
              data: theme.copyWith(
                components: theme.components.copyWith(
                  textInput:
                      (theme.components.textInput ??
                              const OiTextInputThemeData())
                          .copyWith(
                            height: table.identityControlHeight,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                          ),
                ),
              ),
              child: controls,
            );
          }
          final options = showAdvanced(row)
              ? SizedBox.square(
                  dimension: 24,
                  child: OiButton.icon(
                    label:
                        'Options for ${table.field.relation.displayLabelOf(row.snapshot)}',
                    icon: expanded.value.contains(row.localId)
                        ? OiIcons.chevronUp
                        : OiIcons.chevronDown,
                    size: OiButtonSize.small,
                    onTap: () => toggle(row),
                  ),
                )
              : null;
          if (table.rowTemplate case final template?) {
            return BeakRecordTemplateView(
              template: template,
              draft: row,
              inlineSubtitle: controls == null && options == null ? null : true,
              metadataLeading: controls,
              metadataTrailing: options,
              titleTrailing:
                  !locked &&
                      row.id == null &&
                      draft.session.showChangeIndicators
                  ? _changeMarker(context, description: 'Added item, not saved')
                  : null,
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OiLabel.body(table.field.relation.displayLabelOf(row.snapshot)),
              ?controls,
              ?options,
            ],
          );
        }

        Widget column(int index, Widget child) {
          final aligned = index < table.columnAlignments.length
              ? Align(alignment: table.columnAlignments[index], child: child)
              : child;
          return index < table.columnWidths.length &&
                  table.columnWidths[index] != null
              ? SizedBox(width: table.columnWidths[index], child: aligned)
              : Expanded(child: aligned);
        }

        final controls =
            !locked &&
            (table.allowRemove ||
                table.allowEdit && table.advancedForm != null);
        return OiColumn(
          breakpoint: context.breakpoint,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact && (table.showColumnHeadings ?? table.showHeading))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: OiRow(
                  breakpoint: context.breakpoint,
                  gap: OiResponsive<double>(table.rowGap),
                  children: [
                    Expanded(
                      flex: table.identityFlex,
                      child: OiLabel.caption(table.field.label),
                    ),
                    for (var index = 0; index < table.children.length; index++)
                      column(
                        index,
                        OiLabel.caption(label(table.children[index])),
                      ),
                    if (controls || table.reserveActions)
                      SizedBox(width: controlWidth),
                  ],
                ),
              ),
            for (final row in rows)
              Container(
                key: ValueKey(row.localId),
                padding: table.rowPadding,
                constraints: BoxConstraints(minHeight: table.rowMinHeight),
                decoration: BoxDecoration(
                  border: table.showRowDividers
                      ? Border(
                          top: BorderSide(color: context.colors.borderSubtle),
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    compact
                        ? OiColumn(
                            breakpoint: context.breakpoint,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            gap: const OiResponsive<double>(12),
                            children: [
                              identity(row),
                              if (table.children.isNotEmpty)
                                OiGrid(
                                  breakpoint: context.breakpoint,
                                  minColumnWidth: const OiResponsive<double>(
                                    120,
                                  ),
                                  gap: const OiResponsive<double>(12),
                                  children: [
                                    for (final node in table.children)
                                      cell(node, row),
                                  ],
                                ),
                              if (controls) _rowControls(context, row),
                            ],
                          )
                        : OiRow(
                            breakpoint: context.breakpoint,
                            gap: OiResponsive<double>(table.rowGap),
                            children: [
                              Expanded(
                                flex: table.identityFlex,
                                child: identity(row),
                              ),
                              for (
                                var index = 0;
                                index < table.children.length;
                                index++
                              )
                                column(index, cell(table.children[index], row)),
                              if (controls || table.reserveActions)
                                SizedBox(
                                  width: controlWidth,
                                  child: controls
                                      ? _rowControls(context, row)
                                      : null,
                                ),
                            ],
                          ),
                    if (showAdvanced(row))
                      _InlineRelationAdvanced(
                        table: table,
                        row: row,
                        readOnly: locked || !table.allowEdit,
                        showHeading: false,
                        expanded: expanded.value.contains(row.localId),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _rowControls(BuildContext context, BeakDraftRecord row) {
    final busy = draft.session.submitting.value || draft.session.hasUnknown;
    final identity = table.field.relation.displayLabelOf(row.snapshot);
    return OiRow(
      breakpoint: context.breakpoint,
      children: [
        if (table.allowEdit &&
            table.advancedForm != null &&
            table.advancedPresentation == BeakAdvancedPresentation.dialog)
          OiButton.icon(
            label: 'Edit $identity',
            icon: OiIcons.pencil,
            size: OiButtonSize.small,
            onTap: busy
                ? null
                : () async {
                    final checkpoint = row.checkpoint();
                    final accepted = await _editModal(
                      context,
                      row,
                      table.advancedForm!,
                      title: table.label ?? table.field.label,
                    );
                    if (accepted != true) row.restore(checkpoint);
                  },
          ),
        if (table.allowRemove)
          OiButton.icon(
            label: 'Remove $identity',
            icon: OiIcons.trash2,
            size: OiButtonSize.small,
            onTap: busy ? null : () => draft.removeRow(row),
          ),
      ],
    );
  }
}

class _RelationTable extends HookWidget {
  const _RelationTable({
    required this.table,
    required this.draft,
    required this.readOnly,
  });
  final BeakRelationTable table;
  final BeakDraftRecord draft;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final rows = draft.rows(table.field);
    final locked = readOnly || !draft.enabled(table);
    final label = table.label ?? table.field.label;
    final heading = table.showHeading ? label : '';
    final body = OiColumn(
      breakpoint: context.breakpoint,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      gap: const OiResponsive<double>(12),
      children: [
        if (!locked && table.allowAdding && table.catalog != null)
          _CatalogPicker(table: table, draft: draft),
        if (table.presentation == BeakRelationTablePresentation.rows &&
            (locked || table.catalog == null))
          _CompactRelationRows(table: table, draft: draft, locked: locked)
        else if (locked ||
            (table.catalog?.presentation !=
                    BeakCatalogPresentation.checkboxes &&
                (table.catalog?.groupBy == null &&
                    table.catalog?.quantity == null)))
          for (final row in rows)
            OiCard(
              key: ValueKey(row.localId),
              child: OiColumn(
                breakpoint: context.breakpoint,
                children: [
                  if (table.rowTemplate case final BeakRecordTemplate template)
                    BeakRecordTemplateView(template: template, draft: row),
                  if (table.children.isNotEmpty ||
                      table.identityChildren.isNotEmpty)
                    OiGrid(
                      breakpoint: context.breakpoint,
                      minColumnWidth: const OiResponsive<double>(200),
                      gap: const OiResponsive<double>(12),
                      children: [
                        for (final node in [
                          ...table.identityChildren,
                          ...table.children,
                        ])
                          _FormNodeView(
                            node: node,
                            draft: row,
                            readOnly: locked || !table.allowEdit,
                          ),
                      ],
                    ),
                  if (!locked)
                    OiRow(
                      breakpoint: context.breakpoint,
                      children: [
                        if (table.advancedForm != null &&
                            table.allowEdit &&
                            table.advancedPresentation ==
                                BeakAdvancedPresentation.dialog)
                          OiButton.ghost(
                            label: 'Advanced',
                            onTap:
                                draft.session.submitting.value ||
                                    draft.session.hasUnknown
                                ? null
                                : () async {
                                    final checkpoint = row.checkpoint();
                                    final accepted = await _editModal(
                                      context,
                                      row,
                                      table.advancedForm!,
                                      title: label,
                                    );
                                    if (accepted != true) {
                                      row.restore(checkpoint);
                                    }
                                  },
                          ),
                        if (table.allowRemove)
                          OiButton.ghost(
                            label: 'Remove',
                            onTap:
                                draft.session.submitting.value ||
                                    draft.session.hasUnknown
                                ? null
                                : () => draft.removeRow(row),
                          ),
                      ],
                    ),
                  if (table.advancedPresentation ==
                          BeakAdvancedPresentation.inline &&
                      table.advancedForm != null)
                    _InlineRelationAdvanced(
                      table: table,
                      row: row,
                      readOnly: locked || !table.allowEdit,
                    ),
                ],
              ),
            ),
        if (draft.errors[table.field.key] case final List<String> errors)
          OiLabel.body(errors.join(' ')),
        if (table.summary != null)
          OiLabel.body(
            '${table.summaryLabel == null ? '' : '${table.summaryLabel}: '}${BeakFormatting.of(context).format(table.summary!([for (final row in rows) BeakFormReader(row)]), table.summaryFormat)}',
          ),
        if (!locked &&
            table.allowAdding &&
            table.showAddAction &&
            table.catalog == null)
          OiButton.secondary(
            label: 'Add $label',
            onTap: draft.session.submitting.value || draft.session.hasUnknown
                ? null
                : () async {
                    final checkpoint = draft.checkpoint();
                    final row = draft.addRow(table.field);
                    if (table.advancedForm == null) return;
                    final accepted = await _editModal(
                      context,
                      row,
                      table.rowLayout,
                      title: 'Add $label',
                    );
                    if (accepted != true) {
                      draft.restore(checkpoint);
                    }
                  },
          ),
      ],
    );
    return table.presentation == BeakRelationTablePresentation.rows
        ? OiColumn(
            breakpoint: context.breakpoint,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            gap: const OiResponsive<double>(12),
            children: [if (heading.isNotEmpty) OiLabel.h4(heading), body],
          )
        : OiCard(
            title: heading.isEmpty ? null : OiLabel.h4(heading),
            child: body,
          );
  }
}

// Mounted forms are scoped to their router and removed on unmount. This registry
// contains no persistence store and never mixes independent panel navigators.
final Map<GoRouter, Set<BeakFormSession>> _mountedForms = {};

/// Confirms abandoning an active draft when a resource route is replaced.
Future<bool> beakConfirmFormExit(
  BuildContext context, {
  BeakFormSession? session,
}) async {
  final sessions = <BeakFormSession>{
    ...?_mountedForms[GoRouter.maybeOf(context)],
    ?session,
  }.where((session) => !session.canLeave).toList();
  if (sessions.isEmpty) return true;
  if (sessions.any((session) => session.submitting.value)) {
    await showOiDialog<void>(
      context,
      builder: (context, close) => OiDialog.standard(
        label: 'Save in progress',
        title: 'Save in progress',
        content: const OiLabel.body(
          'Wait for the save result before leaving this form.',
        ),
        actions: [OiButton.primary(label: 'Stay', onTap: () => close(null))],
        onClose: () => close(null),
      ),
    );
    return false;
  }
  var stored = true;
  for (final session in sessions) {
    final persisted = session.drafts != null && await session.persistDraft();
    stored = stored && persisted;
  }
  if (!context.mounted) return false;
  final partial = sessions.any((session) => session.saveResult.value != null);
  final unknown = sessions.any((session) => session.hasUnknown);
  final accepted = await showOiDialog<bool>(
    context,
    builder: (context, close) => OiDialog.confirm(
      label: 'Unsaved changes',
      title: 'Leave this form?',
      content: OiLabel.body(
        unknown
            ? 'Some save results are unknown. Leaving cannot undo changes already saved. Stay to check the save status.'
            : partial
            ? 'Some changes are already saved. Discard only the remaining unsaved changes?'
            : stored
            ? 'Your draft is stored locally and can be resumed when you return.'
            : 'Discard the unsaved changes in this form?',
      ),
      actions: [
        OiButton.secondary(label: 'Stay', onTap: () => close(false)),
        OiButton.destructive(
          label: unknown || stored ? 'Leave' : 'Discard changes',
          onTap: () => close(true),
        ),
      ],
      onClose: () => close(false),
    ),
  );
  if (accepted == true) {
    for (final session in sessions) {
      session.allowExit();
    }
  }
  return accepted == true;
}

/// Opens a graph-change review without persisting anything.
Future<bool?> showBeakFormReview(
  BuildContext context,
  BeakFormSession session,
) => showOiDialog<bool>(
  context,
  builder: (context, close) => OiDialog.standard(
    label: 'Review changes',
    title: 'Review changes',
    content: SingleChildScrollView(
      child: OiColumn(
        breakpoint: context.breakpoint,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        gap: const OiResponsive<double>(12),
        children: [
          if (session.reviewChanges.isEmpty)
            const OiLabel.body('No field or relationship changes.'),
          for (final change in session.reviewChanges)
            OiColumn(
              breakpoint: context.breakpoint,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OiLabel.bodyStrong('${change.label}: ${change.kind.name}'),
                if (change.kind == BeakDraftChangeKind.update)
                  OiLabel.body(
                    '${_reviewValue(context, change.column, change.before)} → ${_reviewValue(context, change.column, change.after)}',
                  ),
              ],
            ),
        ],
      ),
    ),
    actions: [
      OiButton.ghost(label: 'Back', onTap: () => close(false)),
      OiButton.primary(label: 'Continue', onTap: () => close(true)),
    ],
    onClose: () => close(false),
  ),
);

/// Opens development diagnostics without displaying draft field values.
Future<void> showBeakFormInspector(
  BuildContext context,
  BeakFormSession session,
) => showOiDialog<void>(
  context,
  builder: (context, close) => OiDialog.standard(
    label: 'Form inspector',
    title: 'Form inspector',
    content: SingleChildScrollView(
      child: OiColumn(
        breakpoint: context.breakpoint,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        gap: const OiResponsive<double>(12),
        children: [
          for (final field in session.explain())
            OiCard(
              title: OiLabel.h4(field.label),
              child: OiColumn(
                breakpoint: context.breakpoint,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OiLabel.body(field.path),
                  OiLabel.body(
                    '${field.visible ? 'Visible' : 'Hidden'} · ${field.enabled ? 'Editable' : 'Read only'} · ${field.origin}',
                  ),
                  if (field.dependencies.isNotEmpty)
                    OiLabel.body(
                      'Depends on: ${field.dependencies.join(', ')}',
                    ),
                  for (final rule in field.validation) OiLabel.body(rule),
                ],
              ),
            ),
        ],
      ),
    ),
    actions: [OiButton.primary(label: 'Close', onTap: () => close(null))],
    onClose: () => close(null),
  ),
);

/// Uses the declared action input model, or a confirmation for input-free actions.
/// The returned values are arguments to the record's transaction, never a new row.
Future<BeakRecord?> showBeakActionInput(
  BuildContext context,
  BeakFormSession session,
  BeakModelAction action,
) async {
  if (!session.canExecuteAction(action)) return null;
  final input = action.inputModel;
  if (input == null) {
    final accepted = await showOiDialog<bool>(
      context,
      builder: (context, close) => OiDialog.confirm(
        label: action.label,
        title: action.label,
        content: OiLabel.body(
          action.description ?? 'Apply this action to the record?',
        ),
        actions: [
          OiButton.ghost(label: 'Cancel', onTap: () => close(false)),
          OiButton.primary(label: action.label, onTap: () => close(true)),
        ],
        onClose: () => close(false),
      ),
    );
    return accepted == true ? const BeakRecord(values: {}) : null;
  }
  final arguments = BeakFormSession(
    model: input,
    dataSource: session.repository.dataSource,
    registry: session.registry,
  );
  try {
    final accepted = await _editModal(
      context,
      arguments.root,
      arguments.root.layout,
      title: action.label,
    );
    return accepted == true ? arguments.root.buildRecord() : null;
  } finally {
    arguments.dispose();
  }
}

String _reviewValue(
  BuildContext context,
  BeakColumn? column,
  BeakValue? value,
) {
  final formatting = BeakFormatting.of(context);
  if (column == null) return value?.raw?.toString() ?? formatting.emptyValue;
  return formatting.formatCell(
    column,
    BeakRecord(values: {column.key: value ?? const BeakNullValue()}),
  );
}
