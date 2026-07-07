import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';

import 'beak_form_controller_builder.dart';
import 'upload_field.dart';

/// Carries a form's controller and its upload wiring down to the record-bound
/// blocks (`BeakFieldBlock`, `BeakFieldGroupBlock`, `BeakRelationBlock`), so a
/// resource's layout renders **editable inputs** when it sits inside a form
/// and **read-only values** when it sits inside a `BeakRecordScope`.
///
/// This is what lets one structured layout drive both the show page and the
/// create/edit form: the blocks look for a form scope first (→ inputs), then a
/// record scope (→ values). A `BeakDataForm` with a `layout` installs one of
/// these around the block host.
class BeakFormScope extends InheritedWidget {
  /// Provides [controller] (and its upload wiring) to [child]'s subtree.
  const BeakFormScope({
    required this.controller,
    required this.model,
    required this.dataSource,
    required this.recordId,
    required this.uploader,
    required this.filePicker,
    required super.child,
    super.key,
  });

  /// The controller the input blocks bind their fields to.
  final BeakFormController controller;

  /// The model whose columns/relations the layout addresses.
  final BeakModel model;

  /// The source belongs-to pickers and relation managers query.
  final BeakDataSource dataSource;

  /// The record under edit, or `null` in create mode (to-many relation
  /// surfaces only appear once there is a parent to attach to).
  final Object? recordId;

  /// Upload transport for image/file inputs.
  final BeakUploadClient? uploader;

  /// Picking strategy for image/file inputs.
  final BeakFilePicker? filePicker;

  /// The nearest form scope above [context], or `null` when there is none.
  static BeakFormScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BeakFormScope>();

  @override
  bool updateShouldNotify(BeakFormScope oldWidget) =>
      oldWidget.controller != controller || oldWidget.recordId != recordId;
}
