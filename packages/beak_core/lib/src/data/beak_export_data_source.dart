import '../columns/beak_column.dart';
import '../formatting/beak_format_policy.dart';
import '../query/beak_query_spec.dart';

/// Optional server-authorized CSV export capability.
///
/// Export covers every matching row, irrespective of query pagination. The
/// ordered [columns] projection contains physical scalar model columns; custom
/// UI templates and client-only calculations are deliberately not serialized.
abstract interface class BeakExportDataSource {
  /// Exports an authorized query with an explicit display policy or raw values.
  Future<String> export(
    BeakQuerySpec spec, {
    List<BeakColumn>? columns,
    Map<String, BeakExportFormat> formats = const {},
    BeakFormatPolicy? formatting,
    bool raw = false,
  });
}

/// A portable display override for one authorized scalar export field.
final class BeakExportFormat {
  /// Keeps storage values intact; minor units apply only to integer amounts.
  const BeakExportFormat(
    this.format, {
    this.minorUnits = false,
    this.scale = 2,
  });

  /// Requested presentation.
  final BeakValueFormat format;

  /// Interprets integer values as exact scaled units before formatting.
  final bool minorUnits;

  /// Decimal places in the stored integer units.
  final int scale;

  /// Serializes the display-only override.
  Map<String, Object?> toJson() => {
    'format': format.name,
    'minorUnits': minorUnits,
    'scale': scale,
  };

  /// Rejects unknown formats and malformed scale or storage options.
  factory BeakExportFormat.fromJson(Map<String, Object?> json) {
    final format = BeakValueFormat.values
        .where((value) => value.name == json['format'])
        .firstOrNull;
    final minorUnits = json['minorUnits'] ?? false;
    final scale = json['scale'] ?? 2;
    if (format == null ||
        minorUnits is! bool ||
        scale is! int ||
        scale < 0 ||
        scale > 12) {
      throw const FormatException('Invalid export field formatting.');
    }
    return BeakExportFormat(format, minorUnits: minorUnits, scale: scale);
  }
}
