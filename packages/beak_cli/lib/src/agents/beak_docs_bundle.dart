import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'beak_package_config.dart';
import 'beak_workspace.dart';

/// What happened to the materialized docs.
enum BeakDocsStatus {
  /// The copy was already current; nothing was written.
  unchanged,

  /// The bundle was copied into the workspace.
  written,

  /// A dry run: the copy is missing or out of date, and was left alone.
  pending,
}

/// The outcome of [materializeDocs].
sealed class BeakDocsResult {
  const BeakDocsResult();
}

/// The docs of the resolved Beak version, in the workspace.
final class BeakDocsReady extends BeakDocsResult {
  /// Creates a result for the bundle at [directory].
  const BeakDocsReady({
    required this.status,
    required this.version,
    required this.pages,
    required this.directory,
    required this.source,
  });

  /// Whether anything was written.
  final BeakDocsStatus status;

  /// The Beak version the bundle documents.
  final String version;

  /// How many pages it holds.
  final int pages;

  /// Where the bundle is (or, for [BeakDocsStatus.pending], will be)
  /// materialized.
  final Directory directory;

  /// The `doc/agent-docs` directory of the resolved `beak_core` it was
  /// copied from.
  final Directory source;

  /// The page an agent reads first.
  File get indexFile => File(p.join(directory.path, 'ai-index.md'));
}

/// The docs cannot be materialized, and why.
///
/// Never a failure of the command that asked: a project that has not run
/// `pub get` yet, or whose Beak predates the bundle, is simply not ready.
final class BeakDocsUnavailable extends BeakDocsResult {
  /// Creates a result explaining [reason].
  const BeakDocsUnavailable(this.reason);

  /// What is missing and what to run about it.
  final String reason;
}

/// Copies the docs bundle of the resolved `beak_core` into the workspace.
///
/// The bundle ships in `beak_core` at `doc/agent-docs/`, which puts it in
/// the pub cache, outside the project. Agents read files by path and their
/// tools skip what is outside the project, so it is copied to
/// `<workspace>/.dart_tool/beak/docs/`, one copy per workspace.
///
/// The copy is current when its `manifest.json` has the same bytes as the
/// source's, which is one small read. Otherwise the bundle is copied to a
/// sibling directory, every file is checked against the manifest's sha256,
/// and only then does it replace the old copy, so a failure part-way leaves
/// the previous docs intact. Beak owns the target directory outright.
///
/// With [dryRun] nothing is written and a copy that is missing or stale is
/// reported as [BeakDocsStatus.pending]. [packages] is the workspace's
/// resolved packages when the caller has read them already.
///
/// ```dart
/// final result = materializeDocs(BeakWorkspace.locate(Directory.current));
/// if (result case BeakDocsReady(:final indexFile)) {
///   print(indexFile.path);
/// }
/// ```
BeakDocsResult materializeDocs(
  BeakWorkspace workspace, {
  BeakPackageConfig? packages,
  bool dryRun = false,
}) {
  const String pubGet = 'run `flutter pub get`';
  final BeakPackageConfig? config =
      packages ?? BeakPackageConfig.read(workspace.packageConfigFile);
  if (config == null) {
    return BeakDocsUnavailable(
      '${p.join('.dart_tool', 'package_config.json')} not found; $pubGet first',
    );
  }
  final BeakResolvedPackage? core = config.core;
  if (core == null) {
    return const BeakDocsUnavailable(
      'beak_core is not among the resolved packages; add beak to '
      'pubspec.yaml and $pubGet',
    );
  }
  final source = Directory(p.join(core.root.path, 'doc', 'agent-docs'));
  final manifestFile = File(p.join(source.path, 'manifest.json'));
  if (!manifestFile.existsSync()) {
    return BeakDocsUnavailable(
      'beak_core ${core.version ?? ''} ships no doc/agent-docs bundle; '
      'upgrade Beak and $pubGet',
    );
  }
  final List<int> manifestBytes = manifestFile.readAsBytesSync();
  final _Manifest? manifest = _Manifest.parse(manifestBytes);
  if (manifest == null) {
    return BeakDocsUnavailable(
      'the manifest of ${source.path} is not a docs manifest',
    );
  }

  final Directory target = workspace.docsDirectory;
  BeakDocsReady ready(BeakDocsStatus status) => BeakDocsReady(
    status: status,
    version: manifest.version,
    pages: manifest.pages,
    directory: target,
    source: source,
  );

  final targetManifest = File(p.join(target.path, 'manifest.json'));
  if (targetManifest.existsSync() &&
      _sameBytes(targetManifest.readAsBytesSync(), manifestBytes)) {
    return ready(BeakDocsStatus.unchanged);
  }
  if (dryRun) {
    return ready(BeakDocsStatus.pending);
  }

  final staging = Directory('${target.path}.tmp');
  try {
    if (staging.existsSync()) {
      staging.deleteSync(recursive: true);
    }
    staging.createSync(recursive: true);
    for (final entry in manifest.files.entries) {
      final String relative = entry.key;
      final String destination = p.join(staging.path, relative);
      if (!p.isWithin(staging.path, destination)) {
        staging.deleteSync(recursive: true);
        return BeakDocsUnavailable(
          'the manifest lists $relative, which is outside the bundle',
        );
      }
      final originFile = File(p.join(source.path, relative));
      if (!originFile.existsSync()) {
        staging.deleteSync(recursive: true);
        return BeakDocsUnavailable(
          'the manifest lists $relative, which the bundle does not contain',
        );
      }
      final List<int> bytes = originFile.readAsBytesSync();
      if (sha256.convert(bytes).toString() != entry.value) {
        staging.deleteSync(recursive: true);
        return BeakDocsUnavailable(
          '$relative does not match the checksum in the manifest of '
          '${source.path}',
        );
      }
      File(destination)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    }
    File(p.join(staging.path, 'manifest.json')).writeAsBytesSync(manifestBytes);
    if (target.existsSync()) {
      target.deleteSync(recursive: true);
    }
    staging.renameSync(target.path);
  } on FileSystemException catch (error) {
    if (staging.existsSync()) {
      staging.deleteSync(recursive: true);
    }
    return BeakDocsUnavailable(
      'could not write ${target.path}: ${error.message}',
    );
  }
  return ready(BeakDocsStatus.written);
}

/// The parts of a docs `manifest.json` the copy needs.
final class _Manifest {
  const _Manifest(this.version, this.pages, this.files);

  /// Reads [bytes], or returns `null` when they are not a docs manifest.
  static _Manifest? parse(List<int> bytes) {
    final Object? document;
    try {
      document = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
    if (document is! Map<String, Object?>) {
      return null;
    }
    final Object? files = document['files'];
    if (files is! Map<String, Object?>) {
      return null;
    }
    return _Manifest(
      switch (document['beak']) {
        final String version => version,
        _ => '',
      },
      switch (document['pages']) {
        final int pages => pages,
        _ => files.length,
      },
      {
        for (final entry in files.entries)
          if (entry.value case final String hash) entry.key: hash,
      },
    );
  }

  /// The Beak version.
  final String version;

  /// The page count.
  final int pages;

  /// The sha256 of each file, by path relative to the bundle.
  final Map<String, String> files;
}

/// Whether [a] and [b] hold the same bytes.
bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}
