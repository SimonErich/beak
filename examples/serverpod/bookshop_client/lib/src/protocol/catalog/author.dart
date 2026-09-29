/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;

/// Someone whose books the shop sells.
abstract class Author
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Author._({
    this.id,
    required this.name,
    this.bio,
    this.website,
  });

  factory Author({
    int? id,
    required String name,
    String? bio,
    String? website,
  }) = _AuthorImpl;

  factory Author.fromJson(Map<String, dynamic> jsonSerialization) {
    return Author(
      id: jsonSerialization['id'] as int?,
      name: jsonSerialization['name'] as String,
      bio: jsonSerialization['bio'] as String?,
      website: jsonSerialization['website'] as String?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  /// The name printed on the cover.
  String name;

  /// A short biography for the author page.
  String? bio;

  /// The author's own website.
  String? website;

  /// Returns a shallow copy of this [Author]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Author copyWith({
    int? id,
    String? name,
    String? bio,
    String? website,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Author',
      if (id != null) 'id': id,
      'name': name,
      if (bio != null) 'bio': bio,
      if (website != null) 'website': website,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Author',
      if (id != null) 'id': id,
      'name': name,
      if (bio != null) 'bio': bio,
      if (website != null) 'website': website,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AuthorImpl extends Author {
  _AuthorImpl({
    int? id,
    required String name,
    String? bio,
    String? website,
  }) : super._(
         id: id,
         name: name,
         bio: bio,
         website: website,
       );

  /// Returns a shallow copy of this [Author]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Author copyWith({
    Object? id = _Undefined,
    String? name,
    Object? bio = _Undefined,
    Object? website = _Undefined,
  }) {
    return Author(
      id: id is int? ? id : this.id,
      name: name ?? this.name,
      bio: bio is String? ? bio : this.bio,
      website: website is String? ? website : this.website,
    );
  }
}
