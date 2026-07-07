import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_autoforms/obers_ui_autoforms.dart';
import 'package:signals/signals_flutter.dart';

import '../detail/relation_manager.dart';
import 'beak_form_controller_builder.dart';
import 'beak_form_step.dart';
import 'field_widget_mapper.dart';
import 'form_view_model.dart';
import 'relation_field.dart';
import 'upload_field.dart';

/// The generated create/edit form: a model's form-context columns rendered
/// as typed autoforms fields with client-side validation mirroring the
/// column rules, belongs-to pickers, upload fields, sectioning with
/// conditional visibility, edit-mode prefill from `getOne`, and 422
/// responses mapped back onto the fields — zero per-resource form code.
///
/// A `null` [recordId] renders the create form; any other value loads that
/// record and switches to edit mode (prefilling fields and revealing the
/// to-many relation surfaces). Declaring [sections] both subsets and orders
/// the fields and gates each group behind its `visibleWhen` predicate.
///
/// ```dart
/// BeakDataForm(
///   model: const ProductModel(),
///   dataSource: dataSource,
///   recordId: editingId, // null → create, otherwise → edit
///   filePicker: pickImageFromDisk,
///   onSaved: (record) => context.go('/products/${record['id']?.raw}'),
///   sections: [
///     const BeakFormSection(
///       title: 'Basics',
///       columns: [ProductColumns.name, ProductColumns.onSale],
///     ),
///     BeakFormSection(
///       title: 'Pricing',
///       columns: const [ProductColumns.salePrice],
///       // Only shown while the "on sale" switch is on.
///       visibleWhen: (values) =>
///           values.valueOf<bool>(ProductColumns.onSale) ?? false,
///     ),
///   ],
/// )
/// ```
class BeakDataForm extends HookWidget {
  /// Creates the form for [model] over [dataSource].
  ///
  /// A `null` [recordId] renders the create form; otherwise the record
  /// loads and the form edits it. [sections] groups and subsets the fields;
  /// [onSaved] fires with the stored record after a successful submit.
  /// [uploader] defaults to [dataSource] when it also implements
  /// [BeakUploadClient]; [filePicker] supplies picked file bytes for
  /// upload columns.
  const BeakDataForm({
    required this.model,
    required this.dataSource,
    this.recordId,
    this.sections,
    this.steps,
    this.onSaved,
    this.uploader,
    this.filePicker,
    super.key,
  });

  /// The model this form creates or edits records of.
  final BeakModel model;

  /// The source loads and submits run against.
  final BeakDataSource dataSource;

  /// Primary key of the record under edit, or `null` for create mode.
  final Object? recordId;

  /// Field grouping with optional conditional visibility; `null` renders
  /// one implicit section over every form column. Ignored when [steps] is
  /// set.
  final List<BeakFormSection>? sections;

  /// When set (and non-empty), the form renders as an `OiWizard`: one page
  /// per step, each entering its own columns, with per-step validation
  /// gating advance and the final step submitting. Takes precedence over
  /// [sections].
  final List<BeakFormStep>? steps;

  /// Invoked with the stored record after a successful submit.
  final void Function(BeakRecord record)? onSaved;

  /// Upload transport for image/file columns; defaults to [dataSource]
  /// when it implements [BeakUploadClient].
  final BeakUploadClient? uploader;

  /// Picking strategy for image/file columns.
  final BeakFilePicker? filePicker;

  @override
  Widget build(BuildContext context) {
    final viewModel = useMemoized(
      () => FormViewModel(model, dataSource, recordId: recordId),
      [model, dataSource, recordId],
    );
    final controller = useMemoized(() {
      final List<BeakFormSection>? effectiveSections = steps == null
          ? sections
          : [
              for (final step in steps!)
                BeakFormSection(title: step.title, columns: step.columns),
            ];
      return BeakFormController(model: model, sections: effectiveSections);
    }, [model, sections, steps]);
    useEffect(() {
      viewModel.load();
      return viewModel.dispose;
    }, [viewModel]);
    useEffect(() => controller.dispose, [controller]);
    useEffect(
      () => viewModel.initial.subscribe((record) {
        if (record != null) {
          controller.prefill(record);
        }
      }),
      [viewModel, controller],
    );
    // Validate up front in wizard mode so a step's sync gate can read accurate
    // field validity (empty required fields are already known-invalid);
    // display stays clean because manual validation does not reveal errors.
    useEffect(() {
      if (steps != null && steps!.isNotEmpty) {
        controller.validate();
      }
      return null;
    }, [controller]);
    final blockedStep = useState<String?>(null);

    final BeakUploadClient? effectiveUploader =
        uploader ??
        switch (dataSource) {
          final BeakUploadClient client => client,
          _ => null,
        };

    return SignalBuilder(
      builder: (context) {
        if (viewModel.loading.value) {
          return const OiLabel.body('Loading…');
        }
        return OiAfForm<BeakFormSlot, BeakRecord>(
          controller: controller,
          onSubmit: (data, _) => _submit(data, viewModel, controller),
          child: switch (steps) {
            final List<BeakFormStep> declared when declared.isNotEmpty =>
              _wizard(
                context,
                controller: controller,
                steps: declared,
                uploader: effectiveUploader,
                blockedStep: blockedStep,
              ),
            _ => OiColumn(
              breakpoint: context.breakpoint,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._fieldSections(controller, effectiveUploader),
                const OiAfErrorSummary<BeakFormSlot>(showOnlyAfterSubmit: true),
                OiAfSubmitButton<BeakFormSlot, BeakRecord>(
                  label: recordId == null ? 'Create' : 'Save',
                  loadingLabel: 'Saving…',
                ),
              ],
            ),
          },
        );
      },
    );
  }

  /// Renders the form as an `OiWizard` — one page per [steps] entry. Each
  /// step shows its explanation and fields; advancing runs the step's
  /// validation (revealing a blocked notice when incomplete); the final step
  /// submits through the shared controller.
  Widget _wizard(
    BuildContext context, {
    required BeakFormController controller,
    required List<BeakFormStep> steps,
    required BeakUploadClient? uploader,
    required ValueNotifier<String?> blockedStep,
  }) {
    return OiWizard(
      onComplete: (_) => controller.submit(),
      steps: [
        for (final step in steps)
          OiWizardStep(
            title: step.title,
            subtitle: step.subtitle,
            icon: step.icon,
            validate: (_) {
              final bool ok = _isStepValid(controller, step);
              blockedStep.value = ok ? null : step.title;
              return ok;
            },
            builder: (_) => ListenableBuilder(
              listenable: controller,
              builder: (context, _) => OiColumn(
                breakpoint: context.breakpoint,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (step.description case final String description)
                    OiBanner.info(message: description, dismissible: false),
                  if (blockedStep.value == step.title)
                    const OiBanner.warning(
                      message:
                          'Please complete the required fields on this step '
                          'before continuing.',
                      dismissible: false,
                    ),
                  for (final column in step.columns)
                    if (controller.hasFieldFor(column))
                      if (_buildField(controller, column, uploader)
                          case final Widget field)
                        field,
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Whether every field on [step] currently validates — the sync gate the
  /// wizard reads before advancing.
  bool _isStepValid(BeakFormController controller, BeakFormStep step) {
    var valid = true;
    for (final column in step.columns) {
      if (!controller.hasFieldFor(column)) {
        continue;
      }
      if (!controller.isFieldValid(controller.slotOf(column))) {
        valid = false;
      }
    }
    return valid;
  }

  /// Builds the input widget for [column] — a belongs-to picker for a foreign
  /// key, otherwise the type-mapped field.
  Widget? _buildField(
    BeakFormController controller,
    BeakColumn column,
    BeakUploadClient? uploader,
  ) {
    final BeakBelongsTo? relation = {
      for (final relation in model.relationships)
        if (relation is BeakBelongsTo) relation.foreignKey: relation,
    }[column.key];
    if (relation != null) {
      return BeakBelongsToField(
        controller: controller,
        relation: relation,
        dataSource: dataSource,
      );
    }
    return beakFormFieldFor(
      controller: controller,
      column: column,
      uploader: uploader,
      filePicker: filePicker,
    );
  }

  Future<void> _submit(
    BeakRecord data,
    FormViewModel viewModel,
    BeakFormController controller,
  ) async {
    final BeakRecord? saved = await viewModel.submit(data);
    if (saved != null) {
      onSaved?.call(saved);
      return;
    }
    controller.applyServerErrors(viewModel.fieldErrors.value);
    final BeakException? failure = viewModel.error.value;
    if (failure != null) {
      controller.setGlobalError(failure.message);
    }
  }

  /// The form body: either the declared sections (each title gated by its
  /// visibility predicate) or one implicit section over every form column,
  /// followed by the edit-mode relation surfaces.
  List<Widget> _fieldSections(
    BeakFormController controller,
    BeakUploadClient? effectiveUploader,
  ) {
    final Map<String, BeakBelongsTo> relationByForeignKey = {
      for (final relation in model.relationships)
        if (relation is BeakBelongsTo) relation.foreignKey: relation,
    };

    Widget? fieldFor(BeakColumn column) {
      final BeakBelongsTo? relation = relationByForeignKey[column.key];
      if (relation != null) {
        return BeakBelongsToField(
          controller: controller,
          relation: relation,
          dataSource: dataSource,
        );
      }
      return beakFormFieldFor(
        controller: controller,
        column: column,
        uploader: effectiveUploader,
        filePicker: filePicker,
      );
    }

    final List<Widget> body = [];
    final List<BeakFormSection>? declared = sections;
    if (declared == null) {
      // The controller is the single source of field eligibility — the
      // form only renders what it registered, so the two can never drift.
      final Set<String> columnKeys = {
        for (final column in model.columns) column.key,
      };
      for (final column in model.columns) {
        if (!controller.hasFieldFor(column)) {
          continue;
        }
        final Widget? field = fieldFor(column);
        if (field != null) {
          body.add(field);
        }
      }
      for (final relation in relationByForeignKey.values) {
        if (controller.hasFieldForKey(relation.foreignKey) &&
            !columnKeys.contains(relation.foreignKey)) {
          body.add(
            BeakBelongsToField(
              controller: controller,
              relation: relation,
              dataSource: dataSource,
            ),
          );
        }
      }
    } else {
      for (final section in declared) {
        body.add(
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (!controller.isSectionVisible(section)) {
                return const SizedBox.shrink();
              }
              return OiColumn(
                breakpoint: context.breakpoint,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OiLabel.smallStrong(section.title),
                  for (final column in section.columns)
                    if (controller.hasFieldFor(column))
                      if (fieldFor(column) case final Widget field) field,
                ],
              );
            },
          ),
        );
      }
    }

    final Object? parentId = recordId;
    if (parentId != null) {
      for (final relation in model.relationships) {
        switch (relation) {
          case final BeakBelongsToMany manyToMany:
            body.add(
              BeakBelongsToManyField(
                model: model,
                parentId: parentId,
                relation: manyToMany,
                dataSource: dataSource,
              ),
            );
          case final BeakHasMany hasMany:
            body.add(
              BeakRelationManager(
                parentModel: model,
                parentId: parentId,
                relationship: hasMany,
                dataSource: dataSource,
              ),
            );
          case BeakBelongsTo() || BeakHasOne():
            break;
        }
      }
    }
    return body;
  }
}
