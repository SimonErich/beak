import 'dart:convert';
import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../data/beak_run.dart';
import '../formatting/beak_formatting.dart';
import '../formatting/beak_field_format.dart';
import '../localization/beak_localizations.dart';
import 'beak_query_controller.dart';

/// Explicit scalar projection for a server-authorized CSV download.
final class BeakListExport {
  /// Field order is stable and independent of composite UI column templates.
  // --8<-- [start:BeakListExport]
  const BeakListExport({
    required this.fields,
    this.label = 'Export',
    this.fileName,
    this.raw = false,
  });
  // --8<-- [end:BeakListExport]

  /// Direct scalar fields of the list model, in exported order.
  final List<BeakScalarField<Object>> fields;

  /// Button label.
  final String label;

  /// Download name; defaults to the model table followed by `.csv`.
  final String? fileName;

  /// Exports physical machine values rather than the panel display policy.
  final bool raw;

  /// Portable overrides retained from typed presentation fields.
  Map<String, BeakExportFormat> get formats => raw
      ? const {}
      : {
          for (final field in fields)
            if (field case BeakFormattedField<Object>(
              :final format,
              :final minorUnits,
              :final scale,
            ))
              field.column.key: BeakExportFormat(
                format,
                minorUnits: minorUnits,
                scale: scale,
              ),
        };

  /// Downloads the authorized projection of a frozen query, including a
  /// selection query. Shared by the page and bulk-selection export actions.
  Future<void> download({
    required BeakQuerySpec query,
    required BeakModel model,
    required BeakDataSource source,
    BeakFormatting? formatting,
    Future<void> Function(String contents, String fileName) save = saveBeakCsv,
  }) async {
    if (source case final BeakExportDataSource exports) {
      final csv = await exports.export(
        query,
        columns: columnsFor(model),
        formats: formats,
        formatting: raw ? null : formatting,
        raw: raw,
      );
      await save(csv, fileName ?? '${model.table}.csv');
      return;
    }
    throw const BeakConfigurationException(
      'This data source does not support CSV exports.',
    );
  }

  /// Resolves fields against the canonical model metadata.
  List<BeakColumn> columnsFor(BeakModel model) {
    if (fields.isEmpty ||
        fields.map((field) => field.column.key).toSet().length !=
            fields.length) {
      throw const BeakConfigurationException(
        'Export fields must be non-empty and unique.',
      );
    }
    return [
      for (final field in fields)
        if (field.model.table == model.table && field.path.isEmpty)
          model.columns
                  .where((column) => column.key == field.column.key)
                  .firstOrNull ??
              (throw const BeakConfigurationException(
                'An export field is not declared by its model.',
              ))
        else
          throw const BeakConfigurationException(
            'Export fields must be direct scalar fields of the list model.',
          ),
    ];
  }
}

/// An export button that freezes its query and policy at the time of the click.
class BeakListExportButton extends HookWidget {
  /// Uses only the optional export capability; no client-side data scraping.
  const BeakListExportButton({
    required this.definition,
    required this.controller,
    required this.source,
    this.download = saveBeakCsv,
    super.key,
  });

  /// CSV projection and presentation.
  final BeakListExport definition;

  /// Active query shared with the table.
  final BeakQueryController controller;

  /// Authorized panel source.
  final BeakDataSource source;

  /// Platform delivery seam for embedded hosts and tests.
  final Future<void> Function(String contents, String fileName) download;

  @override
  Widget build(BuildContext context) {
    final loading = useState(false);
    final failure = useState<BeakException?>(null);
    // A wrong projection is a mistake in the definition: fail when the button
    // first draws, not when somebody clicks it.
    useMemoized(() => definition.columnsFor(controller.model), [
      definition,
      controller.model,
    ]);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        OiButton.secondary(
          label: definition.label,
          icon: OiIcons.download,
          loading: loading.value,
          onTap: loading.value
              ? null
              : () async {
                  final query = controller.query;
                  final formatting = definition.raw
                      ? null
                      : BeakFormatting.of(context);
                  loading.value = true;
                  failure.value = null;
                  final result = await beakRun(() async {
                    await definition.download(
                      query: query,
                      model: controller.model,
                      source: source,
                      formatting: formatting,
                      save: (contents, fileName) async {
                        if (context.mounted) await download(contents, fileName);
                      },
                    );
                  });
                  if (!context.mounted) return;
                  loading.value = false;
                  if (result case BeakErr(error: final error)) {
                    failure.value = error;
                  }
                },
        ),
        if (failure.value case final BeakException error)
          OiLabel.caption(BeakLocalizations.of(context).errorMessage(error)),
      ],
    );
  }
}

/// Delivers UTF-8 CSV using the platform save dialog or browser download.
Future<void> saveBeakCsv(String contents, String fileName) async {
  try {
    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );
    if (location == null) return;
    await XFile.fromData(
      Uint8List.fromList(utf8.encode(contents)),
      name: fileName,
      mimeType: 'text/csv',
    ).saveTo(location.path);
  } on Exception {
    throw const BeakStorageException('The CSV file could not be saved.');
  }
}
