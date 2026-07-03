import '../common/beak_exception.dart';
import '../common/beak_result.dart';
import 'beak_upload.dart';
import 'file_rules/beak_dimensions.dart';
import 'file_rules/beak_file_type.dart';

/// Enforces a column's Filament-style file rules on an upload — pure logic,
/// no I/O.
///
/// Dimension and aspect-ratio rules need decoded pixel sizes; the caller
/// (the upload endpoint) decodes the image and passes them as
/// `actualDimensions`, keeping the validator free of image codecs.
final class BeakUploadValidator {
  /// Creates an upload validator.
  const BeakUploadValidator();

  /// Largest accepted deviation between an image's width/height ratio and a
  /// required `aspectRatio`.
  static const double aspectRatioTolerance = 0.01;

  /// Validates [upload] against a column's rules.
  ///
  /// Returns the upload unchanged when every rule passes, or a
  /// [BeakValidationException] aggregating one message list per violated
  /// aspect under the keys `size`, `type`, `dimensions` and `aspectRatio`.
  BeakResult<BeakUpload> validate(
    BeakUpload upload, {
    int? maxSizeInBytes,
    List<BeakFileType> allowedTypes = const [],
    BeakDimensions? maxDimensions,
    double? aspectRatio,
    BeakDimensions? actualDimensions,
  }) {
    final Map<String, List<String>> fieldErrors = {};
    void report(String aspect, String message) =>
        fieldErrors.putIfAbsent(aspect, () => []).add(message);

    if (maxSizeInBytes != null && upload.sizeInBytes > maxSizeInBytes) {
      report(
        'size',
        'The file is ${upload.sizeInBytes} bytes, exceeding the limit of '
            '$maxSizeInBytes bytes.',
      );
    }

    if (allowedTypes.isNotEmpty) {
      final String mimeType = upload.mimeType.toLowerCase();
      if (!allowedTypes.any((type) => type.mimeType == mimeType)) {
        report('type', 'The MIME type "$mimeType" is not allowed.');
      }
      final String? extension = upload.extension;
      if (extension != null &&
          !allowedTypes.any((type) => type.extensions.contains(extension))) {
        report('type', 'The file extension ".$extension" is not allowed.');
      }
    }

    final bool needsDimensions = maxDimensions != null || aspectRatio != null;
    if (needsDimensions && actualDimensions == null) {
      report(
        'dimensions',
        'The image dimensions could not be determined; the file may not be '
            'a decodable image.',
      );
    }
    if (actualDimensions != null) {
      if (maxDimensions != null &&
          (actualDimensions.widthInPixels > maxDimensions.widthInPixels ||
              actualDimensions.heightInPixels > maxDimensions.heightInPixels)) {
        report(
          'dimensions',
          'The image is ${actualDimensions.widthInPixels}x'
              '${actualDimensions.heightInPixels} pixels, exceeding the '
              'limit of ${maxDimensions.widthInPixels}x'
              '${maxDimensions.heightInPixels} pixels.',
        );
      }
      if (aspectRatio != null) {
        final double actualRatio =
            actualDimensions.widthInPixels / actualDimensions.heightInPixels;
        if ((actualRatio - aspectRatio).abs() > aspectRatioTolerance) {
          report(
            'aspectRatio',
            'The image aspect ratio is '
                '${actualRatio.toStringAsFixed(3)}, but $aspectRatio is '
                'required.',
          );
        }
      }
    }

    if (fieldErrors.isEmpty) {
      return BeakOk(upload);
    }
    return BeakErr(
      BeakValidationException(
        'The upload "${upload.filename}" failed validation.',
        fieldErrors: fieldErrors,
      ),
    );
  }
}
