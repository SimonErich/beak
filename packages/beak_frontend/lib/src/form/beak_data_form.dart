import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_autoforms/obers_ui_autoforms.dart';
import 'package:signals/signals_flutter.dart';

import '../detail/relation_manager.dart';
import 'beak_form_controller_builder.dart';
import 'field_widget_mapper.dart';
import 'form_view_model.dart';
import 'relation_field.dart';
import 'upload_field.dart';

/// The generated create/edit form: a model's form-context columns rendered
/// as typed autoforms fields with client-side validation mirroring the
/// column rules, belongs-to pickers, upload fields, sectioning with
/// conditional visibility, edit-mode prefill from `getOne`, and 422
/// responses mapped back onto the fields — zero per-resource form code.
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
    this.onSaved,
    this.uploader,
    this.filePicker,
    super.key,
  });

  /// The model this form creates or edits records of.
  final BeakModel model;

  /// The source loads and submits run against.
  final BeakDataSource dataSource;

  /// The record under edit, or `null` for create mode.
  final Object? recordId;

  /// Field grouping with optional conditional visibility; `null` renders
  /// one implicit section over every form column.
  final List<BeakFormSection>? sections;

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
    final controller = useMemoized(
      () => BeakFormController(model: model, sections: sections),
      [model, sections],
    );
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
          child: OiColumn(
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
        );
      },
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
      final String primaryKeyKey = model.primaryKey.key;
      final Set<String> columnKeys = {
        for (final column in model.columns) column.key,
      };
      for (final column in model.columns) {
        if (!column.visibleOn.contains(BeakContext.form) ||
            column.key == primaryKeyKey) {
          continue;
        }
        final Widget? field = fieldFor(column);
        if (field != null) {
          body.add(field);
        }
      }
      for (final relation in relationByForeignKey.values) {
        if (!columnKeys.contains(relation.foreignKey)) {
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
