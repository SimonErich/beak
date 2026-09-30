import 'dart:io';

import 'package:beak_core/beak_core.dart';
import 'package:beak_core/io.dart';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Serves the files [driver] wrote, under the path of its public base URL.
///
/// The local-disk driver hands out URLs like
/// `http://localhost:8080/uploads/products/a3f9.webp`; without this nothing
/// answers them, so an upload succeeded and its URL 404'd. Mounting it means
/// `beak create` gives you working uploads with no S3, no MinIO and no
/// reverse proxy — the same posture as the default SQLite database.
///
/// Read-only, and confined to the driver's root: a key that climbs out of it
/// is a 404, not a file.
///
/// A real deployment usually puts a CDN or the web server in front instead —
/// point `BEAK_LOCAL_PUBLIC_BASE_URL` at that and this route simply stops
/// being used.
Router beakLocalUploadsRouter(BeakLocalDiskStorageDriver driver) {
  final String prefix = _prefixOf(driver.publicBaseUrl);
  return Router()..get('$prefix/<key|.*>', (Request request, String key) async {
    final String? name = _storedName(key);
    final File? file = name == null ? null : _resolve(driver.rootDir, name);
    if (file == null || !file.existsSync()) {
      throw BeakNotFoundException('No stored file at "$key".');
    }
    final String mimeType =
        lookupMimeType(file.path) ?? 'application/octet-stream';
    return Response.ok(
      file.openRead(),
      headers: {
        'content-type': mimeType,
        'content-length': '${file.lengthSync()}',
        ..._containment(mimeType),
      },
    );
  });
}

/// The headers that keep an upload from running as a page in the origin that
/// serves it: a browser must not guess a different type, and a type that can
/// carry script (HTML, SVG, XML) is downloaded and, if it is opened anyway,
/// sandboxed. Images shown through `<img>` are unaffected.
Map<String, String> _containment(String mimeType) => {
  'x-content-type-options': 'nosniff',
  'content-security-policy': "default-src 'none'; sandbox",
  if (_activeTypes.contains(mimeType)) 'content-disposition': 'attachment',
};

const Set<String> _activeTypes = {
  'text/html',
  'application/xhtml+xml',
  'image/svg+xml',
  'text/xml',
  'application/xml',
  'text/javascript',
  'application/javascript',
};

/// The storage key a request path names, or null when it names none.
///
/// The driver percent-encodes the segments of a key into its URL, and the
/// router hands the path over as it arrived, so it is decoded here, and only
/// then held to the rules every key obeys (no `..`, no backslash, no control
/// character: a NUL byte would end the file name at the operating system).
String? _storedName(String key) {
  try {
    final String decoded = Uri.decodeComponent(key);
    BeakStorageKeys.validate(decoded);
    return decoded;
  } on FormatException {
    return null;
  } on BeakStorageException {
    return null;
  }
}

/// The path [publicBaseUrl] serves from, without a trailing slash.
String _prefixOf(Uri publicBaseUrl) {
  final String path = publicBaseUrl.path.replaceAll(RegExp(r'/+$'), '');
  return path.startsWith('/') ? path : '/$path';
}

/// The file [key] names under [rootDir], or null when it escapes the root,
/// whether by `..` segments or by a symbolic link that leads out of it.
///
/// A file that does not exist is returned as is, so the caller answers 404.
File? _resolve(String rootDir, String key) {
  final Directory root = Directory(rootDir).absolute;
  final String rootPath = root.uri.normalizePath().toFilePath();
  final String filePath = File(
    '${root.path}/$key',
  ).absolute.uri.normalizePath().toFilePath();
  if (!filePath.startsWith(rootPath)) {
    return null;
  }
  final File candidate = File(filePath);
  if (!candidate.existsSync()) {
    return candidate;
  }
  final String realRoot = '${root.resolveSymbolicLinksSync()}/';
  return candidate.resolveSymbolicLinksSync().startsWith(realRoot)
      ? candidate
      : null;
}
