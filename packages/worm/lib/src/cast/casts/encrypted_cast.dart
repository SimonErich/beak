/// Cast skeleton for encrypted columns.
library;

import '../attribute_cast.dart';

/// Base class for casts that transparently encrypt a domain string
/// before it lands in storage and decrypt the ciphertext on read.
///
/// Concrete subclasses implement [encryptString] and [decryptString]
/// using their chosen primitive (AES-GCM, libsodium secret-box, KMS,
/// etc.). The cast itself only handles the type checks and null
/// passthrough so the implementation stays focused on cryptography.
abstract class EncryptedCast extends AttributeCast {
  /// Creates an [EncryptedCast].
  const EncryptedCast({this.field = 'value'});

  /// Field name reported in `CastException`s when conversion fails.
  final String field;

  @override
  String get name => 'encrypted';

  /// Encrypt [plaintext] into the value stored by the adapter.
  ///
  /// Implementations typically return a base64-encoded string or
  /// raw bytes payload that includes any nonce/tag the cipher needs
  /// for [decryptString] to reverse the transformation.
  Object encryptString(String plaintext);

  /// Reverse [encryptString], returning the original plaintext.
  String decryptString(Object ciphertext);

  @override
  String? decode(Object? raw) {
    if (raw == null) return null;
    try {
      return decryptString(raw);
    } on FormatException catch (error) {
      throw castError(
        field: field,
        source: raw,
        reason: 'Failed to decrypt value: ${error.message}',
        targetType: 'String',
      );
    }
  }

  @override
  Object? encode(Object? value) {
    if (value == null) return null;
    if (value is String) return encryptString(value);
    throw castError(
      field: field,
      source: value,
      reason: 'EncryptedCast only encrypts String values.',
      targetType: 'String',
    );
  }
}
