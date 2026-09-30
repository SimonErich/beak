import 'package:beak_core/beak_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:mime/mime.dart';

import '../data/beak_upload_repository.dart';
import '../localization/beak_localizations.dart';
import 'beak_form_controller_builder.dart';
import 'beak_draft_uploads.dart';
import 'beak_resolved_image.dart';

/// Supplies a picked file's bytes and metadata, or `null` when the user
/// cancelled.
///
/// Platform pickers surface names only; Beak needs bytes to validate and
/// upload. The native picker is automatic; apps may override it for cameras or
/// existing asset libraries.
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
// --8<-- [start:BeakFilePicker]
typedef BeakFilePicker = Future<BeakUpload?> Function();
// --8<-- [end:BeakFilePicker]

/// Default platform picker; hosts may replace it with camera or asset selection.
Future<BeakUpload?> beakPickFile({int? maxSizeInBytes}) async {
  final file = await openFile();
  if (file == null) return null;
  if (maxSizeInBytes != null && await file.length() > maxSizeInBytes) {
    throw BeakValidationException(
      'The file exceeds the limit of $maxSizeInBytes bytes.',
    );
  }
  final bytes = await file.readAsBytes();
  return BeakUpload(
    filename: file.name,
    mimeType:
        lookupMimeType(file.name, headerBytes: bytes) ??
        file.mimeType ??
        'application/octet-stream',
    bytes: bytes,
  );
}

/// The form field for [BeakImageColumn]/[BeakFileColumn]: picking a file
/// validates the column's size/type rules client-side (identical messages
/// to the backend), uploads through the configured [BeakUploadClient], and
/// stores the returned storage key as the field value — with a thumbnail
/// preview for images.
///
/// [BeakConfiguredForm] wires one automatically for each upload column; construct
/// it directly only in a hand-composed form. Without an [uploader] it renders
/// read-only. A [filePicker] override is optional.
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
  /// Without an [uploader] the field renders read-only.
  const BeakUploadField({
    required this.controller,
    required this.column,
    this.uploader,
    this.filePicker,
    this.label,
    this.enabled = true,
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

  /// Optional placement label overriding the model label.
  final String? label;

  /// Whether picking another file is currently allowed.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Enum slot = controller.slotOf(column);
    final strings = BeakLocalizations.of(context);
    useListenable(controller);
    final feedback = useState<String?>(null);
    final stored = useState<BeakStoredFile?>(null);
    final busy = useState(false);

    final BeakUploadClient? client = uploader;
    final BeakFilePicker picker =
        filePicker ??
        () => beakPickFile(
          maxSizeInBytes: switch (column) {
            BeakUploadColumn(:final maxSizeInBytes) => maxSizeInBytes,
            _ => null,
          },
        );

    Future<void> pick() async {
      if (client == null || busy.value || !enabled) {
        return;
      }
      busy.value = true;
      feedback.value = null;
      final BeakUpload? file;
      try {
        file = await picker();
      } on Exception catch (error) {
        if (context.mounted) {
          busy.value = false;
          feedback.value = error is BeakException
              ? error.message
              : strings.formOpenFileFailed;
        }
        return;
      }
      if (!context.mounted) return;
      if (file == null) {
        busy.value = false;
        return;
      }
      final result = await BeakUploadRepository(
        client,
      ).upload(controller.model.table, column, file);
      if (!context.mounted) return;
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
    final BeakStoredFile? preview = storedKey == null
        ? null
        : (client is BeakDraftUploads
              ? client.preview(storedKey)
              : stored.value);
    final bool isImage = switch (column) {
      BeakImageColumn() => true,
      _ => false,
    };
    final previewRequest = useMemoized(
      () =>
          isImage &&
              storedKey != null &&
              preview == null &&
              client is BeakUploadUrlClient
          ? switch (client) {
              final BeakUploadUrlClient resolver => resolver.uploadUrl(
                controller.model.table,
                column.key,
                storedKey,
              ),
              _ => null,
            }
          : null,
      [client, storedKey, isImage],
    );
    final resolved = useFuture(previewRequest);
    final imageUrl =
        preview?.variants['thumbnail']?.url ?? preview?.url ?? resolved.data;

    final fieldLabel = label ?? column.label;
    return OiColumn(
      breakpoint: context.breakpoint,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OiLabel.smallStrong(fieldLabel),
        if (imageUrl != null && isImage)
          BeakResolvedImage(
            src: imageUrl.toString(),
            alt: column.label,
            widthInPixels: 80,
            heightInPixels: 80,
            fit: BoxFit.cover,
            errorWidget: const OiIcon.decorative(icon: OiIcons.image),
          ),
        if (storedKey != null)
          OiLabel.caption(
            (client is BeakDraftUploads ? client.filename(storedKey) : null) ??
                storedKey.split('/').last,
          ),
        OiButton.secondary(
          label: busy.value
              ? strings.formPreparingFile
              : strings.formChooseFile,
          semanticLabel: strings.formChooseFileFor(fieldLabel),
          enabled: client != null && !busy.value && enabled,
          onTap: client == null || busy.value || !enabled ? null : pick,
        ),
        if (storedKey != null && enabled)
          OiButton.ghost(
            label: strings.formRemoveFile,
            semanticLabel: strings.formRemoveFileFrom(fieldLabel),
            onTap: busy.value
                ? null
                : () {
                    stored.value = null;
                    controller.set<String>(slot, null);
                  },
          ),
        if (message != null)
          Semantics(liveRegion: true, child: OiLabel.caption(message)),
      ],
    );
  }
}
