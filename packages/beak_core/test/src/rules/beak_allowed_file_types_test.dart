import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const rule = BeakAllowedFileTypes([BeakFileType.jpeg, BeakFileType.png]);
  const message = 'File type must be one of: jpg, png.';

  test('accepts allowed BeakFileType values', () {
    expect(rule.validate(BeakFileType.jpeg), isNull);
    expect(rule.validate(BeakFileType.png), isNull);
  });

  test('rejects disallowed BeakFileType values', () {
    expect(rule.validate(BeakFileType.pdf), message);
  });

  test('matches file names by extension, case-insensitively', () {
    expect(rule.validate('photo.JPG'), isNull);
    expect(rule.validate('photo.jpeg'), isNull);
    expect(rule.validate('doc.pdf'), message);
    expect(rule.validate('photo'), message);
  });

  test('matches MIME type strings exactly', () {
    expect(rule.validate('image/png'), isNull);
    expect(rule.validate('application/pdf'), message);
  });

  test('an empty list allows everything', () {
    const unrestricted = BeakAllowedFileTypes([]);
    expect(unrestricted.validate(BeakFileType.zip), isNull);
    expect(unrestricted.validate('anything.bin'), isNull);
  });

  test('skips null and non-file values', () {
    expect(rule.validate(null), isNull);
    expect(rule.validate(42), isNull);
  });

  test('has a stable id', () {
    expect(rule.id, 'allowed_file_types');
  });
}
