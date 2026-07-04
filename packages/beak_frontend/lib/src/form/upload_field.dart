import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../data/beak_upload_repository.dart';
import 'beak_form_controller_builder.dart';

/// Supplies a picked file's bytes and metadata, or `null` when the user
/// cancelled.
///
/// Platform pickers surface names only; Beak needs bytes to validate and
/// upload, so the app injects the picking strategy (the reference app wires
/// a `file_picker`-based one).
///
/// ```dart
/// Future<BeakUpload?> pickImageFromDisk() async {
///   final result = await FilePicker.platform.pickFiles(withData: true);
///   final file = result?.files.single;
///   if (file == null || file.bytes == null) {
///     return null;
///   }
///   return BeakUpload(
///     filename: file.name,
///     mimeType: 'image/png',
///     bytes: file.bytes!,
///   );
/// }
/// ```
typedef BeakFilePicker = Future<BeakUpload?> Function();

/// The form field for [BeakImageColumn]/[BeakFileColumn]: picking a file
/// validates the column's size/type rules client-side (identical messages
/// to the backend), uploads through the configured [BeakUploadClient], and
/// stores the returned storage key as the field value — with a thumbnail
/// preview for images.
///
/// [BeakDataForm] wires one automatically for each upload column; construct
/// it directly only in a hand-composed form. Without both an [uploader] and
/// a [filePicker] it renders read-only.
///
/// ```dart
/// BeakUploadField(
///   controller: controller,
///   column: ProductColumns.heroImage, // a BeakImageColumn
///   uploader: dataSource, // an HTTP data source is also a BeakUploadClient
///   filePicker: pickImageFromDisk,
/// )
/// ```
class BeakUploadField extends HookWidget {
  /// Creates the upload field for [column] bound to [controller].
  ///
  /// Without an [uploader] and a [filePicker] the field renders read-only.
  const BeakUploadField({
    required this.controller,
    required this.column,
    this.uploader,
    this.filePicker,
    super.key,
  });

  /// The form controller holding the column's field.
  final BeakFormController controller;

  /// The image/file column this field uploads for.
  final BeakColumn column;

  /// The upload transport, if configured.
  final BeakUploadClient? uploader;

  /// The picking strategy, if configured.
  final BeakFilePicker? filePicker;

  @override
  Widget build(BuildContext context) {
    final BeakFormSlot slot = controller.slotOf(column);
    useListenable(controller);
    final feedback = useState<String?>(null);
    final stored = useState<BeakStoredFile?>(null);
    final busy = useState(false);

    final BeakUploadClient? client = uploader;
    final BeakFilePicker? picker = filePicker;

    Future<void> pick() async {
      if (client == null || picker == null || busy.value) {
        return;
      }
      final BeakUpload? file = await picker();
      if (file == null) {
        return;
      }
      busy.value = true;
      feedback.value = null;
      final result = await BeakUploadRepository(
        client,
      ).upload(controller.model.table, column, file);
      busy.value = false;
      switch (result) {
        case BeakOk(:final value):
          stored.value = value;
          controller.set(slot, value.key);
        case BeakErr(:final error):
          feedback.value = switch (error) {
            BeakValidationException(:final fieldErrors) => [
              for (final messages in fieldErrors.values) ...messages,
            ].join(' '),
            _ => error.message,
          };
      }
    }

    final String? storedKey = controller.get<String>(slot);
    final String? message = feedback.value ?? controller.getError(slot);
    final BeakStoredFile? preview = stored.value;
    final bool isImage = switch (column) {
      BeakImageColumn() => true,
      _ => false,
    };

    return OiColumn(
      breakpoint: context.breakpoint,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OiLabel.smallStrong(column.label),
        if (preview != null && isImage)
          OiImage(
            src: (preview.variants['thumbnail']?.url ?? preview.url).toString(),
            alt: column.label,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorWidget: const OiIcon.decorative(icon: OiIcons.image),
          ),
        if (storedKey != null) OiLabel.caption(storedKey),
        OiButton.secondary(
          label: busy.value ? 'Uploading…' : 'Choose file',
          onTap: client == null || picker == null || busy.value ? null : pick,
        ),
        if (message != null) OiLabel.caption(message),
      ],
    );
  }
}
