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
    final File? file = _resolve(driver.rootDir, key);
    if (file == null || !file.existsSync()) {
      throw BeakNotFoundException('No stored file at "$key".');
    }
    return Response.ok(
      file.openRead(),
      headers: {
        'content-type': lookupMimeType(file.path) ?? 'application/octet-stream',
        'content-length': '${file.lengthSync()}',
      },
    );
  });
}

/// The path [publicBaseUrl] serves from, without a trailing slash.
String _prefixOf(Uri publicBaseUrl) {
  final String path = publicBaseUrl.path.replaceAll(RegExp(r'/+$'), '');
  return path.startsWith('/') ? path : '/$path';
}

/// The file [key] names under [rootDir], or null when it escapes the root.
File? _resolve(String rootDir, String key) {
  final Directory root = Directory(rootDir).absolute;
  final File file = File('${root.path}/$key').absolute;
  final String rootPath = root.uri.normalizePath().toFilePath();
  final String filePath = file.uri.normalizePath().toFilePath();
  return filePath.startsWith(rootPath) ? File(filePath) : null;
}
