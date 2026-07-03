import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

const validator = BeakUploadValidator();

BeakUpload _upload({
  String filename = 'photo.png',
  String mimeType = 'image/png',
  int sizeInBytes = 100,
}) => BeakUpload(
  filename: filename,
  mimeType: mimeType,
  bytes: Uint8List(sizeInBytes),
);

/// Unwraps the expected failure, asserting it is a validation exception.
BeakValidationException _errorOf(BeakResult<BeakUpload> result) {
  final BeakException error = result.fold(
    onOk: (_) => fail('Expected the upload to be rejected.'),
    onErr: (error) => error,
  );
  if (error is! BeakValidationException) {
    fail('Expected a BeakValidationException, got $error.');
  }
  return error;
}

void main() {
  group('BeakUploadValidator', () {
    test('accepts an unconstrained upload unchanged', () {
      final upload = _upload();
      final result = validator.validate(upload);
      expect(result.isOk, isTrue);
      expect(result.valueOrThrow, same(upload));
    });

    group('size', () {
      test('accepts an upload exactly at the limit', () {
        expect(
          validator
              .validate(_upload(sizeInBytes: 100), maxSizeInBytes: 100)
              .isOk,
          isTrue,
        );
      });

      test('rejects an upload over the limit', () {
        final error = _errorOf(
          validator.validate(_upload(sizeInBytes: 101), maxSizeInBytes: 100),
        );
        expect(error.fieldErrors, contains('size'));
        expect(error.fieldErrors['size']?.single, contains('101'));
        expect(error.fieldErrors['size']?.single, contains('100'));
      });
    });

    group('allowed types', () {
      test('accepts a matching MIME type and extension', () {
        expect(
          validator
              .validate(
                _upload(),
                allowedTypes: const [BeakFileType.png, BeakFileType.jpeg],
              )
              .isOk,
          isTrue,
        );
      });

      test('matches MIME types case-insensitively', () {
        expect(
          validator
              .validate(
                _upload(mimeType: 'IMAGE/PNG'),
                allowedTypes: const [BeakFileType.png],
              )
              .isOk,
          isTrue,
        );
      });

      test('accepts an extension-less filename by MIME type alone', () {
        expect(
          validator
              .validate(
                _upload(filename: 'photo'),
                allowedTypes: const [BeakFileType.png],
              )
              .isOk,
          isTrue,
        );
      });

      test('rejects a disallowed MIME type', () {
        final error = _errorOf(
          validator.validate(
            _upload(mimeType: 'application/pdf'),
            allowedTypes: const [BeakFileType.png],
          ),
        );
        expect(error.fieldErrors['type']?.single, contains('application/pdf'));
      });

      test('rejects a disallowed extension', () {
        final error = _errorOf(
          validator.validate(
            _upload(filename: 'photo.pdf'),
            allowedTypes: const [BeakFileType.png],
          ),
        );
        expect(error.fieldErrors['type']?.single, contains('pdf'));
      });

      test('reports MIME and extension mismatches separately', () {
        final error = _errorOf(
          validator.validate(
            _upload(filename: 'doc.pdf', mimeType: 'application/pdf'),
            allowedTypes: const [BeakFileType.png],
          ),
        );
        expect(error.fieldErrors['type'], hasLength(2));
      });
    });

    group('dimensions', () {
      const maxDimensions = BeakDimensions(
        widthInPixels: 1000,
        heightInPixels: 800,
      );

      test('accepts an image within the bounds', () {
        expect(
          validator
              .validate(
                _upload(),
                maxDimensions: maxDimensions,
                actualDimensions: const BeakDimensions(
                  widthInPixels: 1000,
                  heightInPixels: 800,
                ),
              )
              .isOk,
          isTrue,
        );
      });

      test('rejects an image that is too wide', () {
        final error = _errorOf(
          validator.validate(
            _upload(),
            maxDimensions: maxDimensions,
            actualDimensions: const BeakDimensions(
              widthInPixels: 1001,
              heightInPixels: 100,
            ),
          ),
        );
        expect(error.fieldErrors['dimensions']?.single, contains('1001'));
      });

      test('rejects an image that is too tall', () {
        final error = _errorOf(
          validator.validate(
            _upload(),
            maxDimensions: maxDimensions,
            actualDimensions: const BeakDimensions(
              widthInPixels: 100,
              heightInPixels: 801,
            ),
          ),
        );
        expect(error.fieldErrors, contains('dimensions'));
      });

      test('rejects dimension rules without decoded dimensions', () {
        final error = _errorOf(
          validator.validate(_upload(), maxDimensions: maxDimensions),
        );
        expect(
          error.fieldErrors['dimensions']?.single,
          contains('could not be determined'),
        );
      });
    });

    group('aspect ratio', () {
      test('accepts an exact match', () {
        expect(
          validator
              .validate(
                _upload(),
                aspectRatio: 1.5,
                actualDimensions: const BeakDimensions(
                  widthInPixels: 1500,
                  heightInPixels: 1000,
                ),
              )
              .isOk,
          isTrue,
        );
      });

      test('tolerates tiny deviations', () {
        expect(
          validator
              .validate(
                _upload(),
                aspectRatio: 1.78,
                actualDimensions: const BeakDimensions(
                  widthInPixels: 1600,
                  heightInPixels: 900,
                ),
              )
              .isOk,
          isTrue,
        );
      });

      test('rejects a mismatched ratio', () {
        final error = _errorOf(
          validator.validate(
            _upload(),
            aspectRatio: 1.0,
            actualDimensions: const BeakDimensions(
              widthInPixels: 800,
              heightInPixels: 600,
            ),
          ),
        );
        expect(error.fieldErrors, contains('aspectRatio'));
      });

      test('rejects a ratio rule without decoded dimensions', () {
        final error = _errorOf(validator.validate(_upload(), aspectRatio: 1.0));
        expect(
          error.fieldErrors['dimensions']?.single,
          contains('could not be determined'),
        );
      });
    });

    test('aggregates every violation into one exception', () {
      final error = _errorOf(
        validator.validate(
          _upload(filename: 'doc.pdf', mimeType: 'application/pdf'),
          maxSizeInBytes: 10,
          allowedTypes: const [BeakFileType.png],
          maxDimensions: const BeakDimensions.square(100),
          aspectRatio: 1.0,
          actualDimensions: const BeakDimensions(
            widthInPixels: 200,
            heightInPixels: 100,
          ),
        ),
      );
      expect(
        error.fieldErrors.keys,
        containsAll(const ['size', 'type', 'dimensions', 'aspectRatio']),
      );
      expect(error.message, contains('doc.pdf'));
    });
  });
}
