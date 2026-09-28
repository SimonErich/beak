import 'dart:convert';

import 'package:beak_core/beak_core.dart';

import '../data/beak_relation_loads.dart';
import '../formatting/beak_field_format.dart';
import '../presentation/beak_record_template.dart';

/// A printable persisted record with explicitly selected fields and collections.
final class BeakRecordDocument {
  /// Reuses typed bindings and the containing panel's formatting policy.
  const BeakRecordDocument({
    required this.title,
    required this.sections,
    this.subtitle = const [],
    this.fileName = 'document.html',
  });

  /// Document heading, read from the authorized persisted record.
  final BeakValueBinding<Object> title;

  /// Identity metadata below the heading.
  final List<BeakValueBinding<Object>> subtitle;

  /// Ordered field groups and related-row tables.
  final List<BeakDocumentPart> sections;

  /// Name used by the portable HTML download fallback.
  final String fileName;

  /// Fetches one authorized persisted record with all declared relation loads.
  Future<BeakDocumentSnapshot> load({
    required BeakModel model,
    required Object id,
    required BeakDataSource source,
    required BeakFormatPolicy formatting,
  }) async {
    final fields = <BeakFieldRef<Object>>[
      ...title.dependencies,
      for (final value in subtitle) ...value.dependencies,
      for (final section in sections)
        ...switch (section) {
          BeakDocumentSection(:final fields) => [
            for (final value in fields) ...value.dependencies,
          ],
          BeakDocumentCollection(:final field, :final columns) => [
            field,
            for (final column in columns)
              if (column.model.table == field.target.table)
                BeakScalarField<Object>(
                  model: model,
                  column: column.column,
                  path: [...field.path, field.relation, ...column.path],
                )
              else
                throw const BeakConfigurationException(
                  'Document collection columns must belong to its related model.',
                ),
          ],
        },
    ];
    final page = await source.query(
      beakWithFieldLoads(
        BeakQuerySpec(
          table: model.table,
          pagination: const BeakPagination(perPage: 1),
        ).withFilter(
          BeakFieldFilter.forKey(
            model.primaryKey.key,
            BeakOperator.eq,
            BeakValue.of(id),
          ),
        ),
        fields,
      ),
    );
    if (page.items.isEmpty) {
      throw const BeakNotFoundException('The document record is unavailable.');
    }
    return render(page.items.single, formatting: formatting);
  }

  /// Creates a standalone, escaped HTML snapshot from already authorized data.
  BeakDocumentSnapshot render(
    BeakRecord record, {
    required BeakFormatPolicy formatting,
  }) {
    final reader = _DocumentReader(record);
    bool visible(BeakValueBinding<Object> value) =>
        value.visibleIf?.call(reader) ?? true;
    String value(BeakValueBinding<Object> binding) => binding.field == null
        ? formatting.format(
            binding.read(reader),
            binding.format ?? BeakValueFormat.text,
          )
        : _fieldText(binding.field!, record, formatting);
    final heading = value(title);
    final body = StringBuffer('<header><h1>${_escape(heading)}</h1>');
    for (final item in subtitle.where(visible)) {
      body.write('<p>${_escape(value(item))}</p>');
    }
    body.write('</header>');
    for (final part in sections) {
      body.write('<section><h2>${_escape(part.title)}</h2>');
      switch (part) {
        case BeakDocumentSection(:final fields):
          body.write('<dl>');
          for (final item in fields.where(visible)) {
            body.write(
              '<div><dt>${_escape(item.label ?? item.field?.label ?? '')}</dt><dd>${_escape(value(item))}</dd></div>',
            );
          }
          body.write('</dl>');
        case BeakDocumentCollection(:final field, :final columns):
          body.write('<table><thead><tr>');
          for (final column in columns) {
            body.write('<th scope="col">${_escape(column.label)}</th>');
          }
          body.write('</tr></thead><tbody>');
          for (final row in field.readFrom(record) ?? const <BeakRecord>[]) {
            body.write('<tr>');
            for (final column in columns) {
              body.write(
                '<td>${_escape(_fieldText(column, row, formatting))}</td>',
              );
            }
            body.write('</tr>');
          }
          body.write('</tbody></table>');
      }
      body.write('</section>');
    }
    return BeakDocumentSnapshot(
      title: heading,
      fileName: fileName,
      html:
          '<!doctype html><html lang="${_escape(formatting.locale.replaceAll('_', '-'))}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta http-equiv="Content-Security-Policy" content="default-src &#39;none&#39;; style-src &#39;unsafe-inline&#39;"><title>${_escape(heading)}</title><style>$_styles</style></head><body><main>$body</main></body></html>',
    );
  }
}

/// One ordered part of a printable record.
sealed class BeakDocumentPart {
  /// Creates a named document part.
  const BeakDocumentPart({required this.title});

  /// Section heading.
  final String title;
}

/// Labelled values from the root record and its to-one paths.
final class BeakDocumentSection extends BeakDocumentPart {
  /// Fields are printed in declaration order.
  const BeakDocumentSection({required super.title, required this.fields});

  /// Typed fields or pure computed bindings with explicit dependencies.
  final List<BeakValueBinding<Object>> fields;
}

/// A related-row table, using generated fields of the related model.
final class BeakDocumentCollection extends BeakDocumentPart {
  /// Loads the relation and nested paths used by [columns] in the same query.
  const BeakDocumentCollection({
    required super.title,
    required this.field,
    required this.columns,
  });

  /// Related rows to print.
  final BeakToManyField field;

  /// Related scalar fields in printed order, including formatting overrides.
  final List<BeakScalarField<Object>> columns;
}

/// Frozen, portable document; contains no controller or live draft reference.
final class BeakDocumentSnapshot {
  /// Holds already escaped HTML generated by a document definition.
  const BeakDocumentSnapshot({
    required this.title,
    required this.html,
    required this.fileName,
  });

  /// Plain text title.
  final String title;

  /// Standalone HTML containing only the selected snapshot values.
  final String html;

  /// Suggested download name.
  final String fileName;
}

final class _DocumentReader implements BeakDraftReader {
  const _DocumentReader(this.record);
  final BeakRecord record;
  @override
  T? read<T extends Object>(BeakFieldRef<T> field) => field.readFrom(record);
}

String _fieldText(
  BeakScalarField<Object> field,
  BeakRecord record,
  BeakFormatPolicy formatting,
) {
  if (field.column.semantic.kind == BeakSemanticKind.password) {
    return formatting.emptyValue;
  }
  final raw = field.readFrom(record);
  if (field case BeakFormattedField<Object>(
    :final format,
    :final minorUnits,
    :final scale,
  )) {
    return formatting.format(
      minorUnits && raw is int ? BeakDecimal(raw, scale: scale) : raw,
      format,
    );
  }
  var owner = record;
  for (final relation in field.path) {
    final next = owner.relations[relation.key]?.firstOrNull;
    if (next == null) return formatting.emptyValue;
    owner = next;
  }
  return formatting.formatCell(field.column, owner);
}

String _escape(String value) => const HtmlEscape().convert(value);

const _styles = '''
@page{size:A4;margin:18mm}*{box-sizing:border-box}body{margin:0;color:#172126;background:white;font:14px/1.5 system-ui,sans-serif}main{max-width:900px;margin:auto;padding:24px}header{border-bottom:2px solid #172126;padding-bottom:16px}h1{font-size:28px;margin:0 0 8px}h2{font-size:17px;margin:24px 0 12px}p{margin:4px 0;white-space:pre-wrap}dl{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px;margin:0}dl div{break-inside:avoid}dt{color:#53636b;font-size:12px}dd{margin:2px 0 0;white-space:pre-wrap;overflow-wrap:anywhere}table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:9px;border-bottom:1px solid #dce2e5;vertical-align:top;overflow-wrap:anywhere}thead{display:table-header-group}tr{break-inside:avoid}section{margin-bottom:20px}@media print{main{padding:0;max-width:none}h2{break-after:avoid}}@media(max-width:500px){dl{grid-template-columns:1fr}}
''';
