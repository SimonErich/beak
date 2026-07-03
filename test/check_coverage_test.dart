import 'package:test/test.dart';

import '../tool/check_coverage.dart';

void main() {
  const belowThresholdLcov = '''
SF:lib/foo.dart
DA:1,1
DA:2,0
DA:3,0
DA:4,0
end_of_record
''';

  const aboveThresholdLcov = '''
SF:lib/foo.dart
DA:1,1
DA:2,1
DA:3,1
DA:4,0
end_of_record
''';

  test('fails a synthetic below-threshold lcov report', () {
    final summary = parseLcov(belowThresholdLcov);
    expect(summary.linesFound, 4);
    expect(summary.linesHit, 1);
    expect(summary.percent, 25.0);
    expect(meetsThreshold(summary, 75), isFalse);
  });

  test('passes a synthetic above-threshold lcov report', () {
    final summary = parseLcov(aboveThresholdLcov);
    expect(summary.linesFound, 4);
    expect(summary.linesHit, 3);
    expect(summary.percent, 75.0);
    expect(meetsThreshold(summary, 75), isTrue);
  });

  test('merges DA lines across multiple lcov records', () {
    const multiRecordLcov = '''
SF:lib/a.dart
DA:1,1
end_of_record
SF:lib/b.dart
DA:1,0
end_of_record
''';
    final summary = parseLcov(multiRecordLcov);
    expect(summary.linesFound, 2);
    expect(summary.linesHit, 1);
    expect(summary.percent, 50.0);
  });

  test('treats a report with no executable lines as fully covered', () {
    final summary = parseLcov('SF:lib/foo.dart\nend_of_record\n');
    expect(summary.linesFound, 0);
    expect(summary.percent, 100.0);
    expect(meetsThreshold(summary, 100), isTrue);
  });

  test('unknown packages gate at the default threshold', () {
    expect(thresholdFor('some_future_package'), defaultThresholdPct);
    expect(defaultThresholdPct, 85);
  });

  test('beak_core is pure Dart and gates at full coverage', () {
    expect(thresholdFor('beak_core'), 100);
  });

  test('the phase-06 packages gate at the default threshold', () {
    for (final package in const [
      'beak_storage_s3',
      'beak_storage_ftp',
      'beak_image',
    ]) {
      expect(thresholdFor(package), defaultThresholdPct, reason: package);
    }
  });

  test('phase-00 skeleton packages start at a zero threshold', () {
    for (final package in const [
      'beak_backend',
      'beak_frontend',
      'beak_cli',
      'reference_admin',
      'reference_admin_server',
    ]) {
      expect(thresholdFor(package), 0, reason: package);
    }
  });
}
