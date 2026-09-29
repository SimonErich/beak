@TestOn('linux || mac-os')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../support/beak_cli_internals.dart';
import 'package:test/test.dart';

/// The generated `bin/serve.dart`, run for real against a stand-in host.
///
/// A server that ignores SIGINT and SIGTERM is killed mid-request by a
/// deploy, and never gets to stop the outbox drain that the host runs while
/// it serves. The entrypoint is one statement of generated code, so the only
/// honest test of it is a process that receives the signal.
///
/// The stand-in `beakHost()` binds a real socket and records when the close of
/// its server finishes, which is all the entrypoint may depend on: closing the
/// server `BeakServeHost.serve` returns is what stops the outbox loop.
void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('beak_serve_entrypoint_');
    addTearDown(() => project.deleteSync(recursive: true));
    void write(String path, String contents) => File('${project.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(contents);

    write('.dart_tool/package_config.json', '''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "probe",
      "rootUri": "../",
      "packageUri": "lib/",
      "languageVersion": "3.11"
    },
    {
      "name": "beak",
      "rootUri": "../fake_beak/",
      "packageUri": "lib/",
      "languageVersion": "3.11"
    }
  ]
}
''');
    // The one thing the entrypoints take from `package:beak/server.dart`.
    write('fake_beak/lib/server.dart', '''
/// Stands in for the exception `package:beak/server.dart` exports.
final class BeakConfigurationException implements Exception {
  const BeakConfigurationException(this.message);

  final String message;
}
''');
    write('lib/beak/server.g.dart', '''
import 'dart:async';
import 'dart:io';

import 'package:beak/server.dart';

/// A real server that records having been closed, once the close finishes.
final class RecordingServer extends Stream<HttpRequest>
    implements HttpServer {
  RecordingServer(this._inner);

  final HttpServer _inner;

  @override
  StreamSubscription<HttpRequest> listen(
    void Function(HttpRequest event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _inner.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  InternetAddress get address => _inner.address;

  @override
  int get port => _inner.port;

  @override
  Future<void> close({bool force = false}) async {
    await _inner.close(force: force);
    File('closed').writeAsStringSync('closed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stands in for the generated `BeakServeHost`.
final class FakeHost {
  Future<HttpServer> serve() async {
    if (Platform.environment['PROBE_CONFIG_ERROR'] case final String message) {
      throw BeakConfigurationException(message);
    }
    return RecordingServer(
      await HttpServer.bind(
        '127.0.0.1',
        int.parse(Platform.environment['PORT']!),
      ),
    );
  }

  Future<int> runCli(List<String> args) async {
    if (Platform.environment['PROBE_CONFIG_ERROR'] case final String message) {
      throw BeakConfigurationException(message);
    }
    return int.parse(Platform.environment['PROBE_EXIT'] ?? '0');
  }
}

FakeHost beakHost() => FakeHost();
''');
    write('bin/serve.dart', BeakEmitters.serveEntrypoint('probe'));
    write('bin/migrate.dart', BeakEmitters.migrateEntrypoint('probe'));
  });

  /// Runs [entrypoint] to its end with [environment] added to the process's.
  Future<ProcessResult> run(
    String entrypoint,
    Map<String, String> environment, [
    List<String> arguments = const [],
  ]) => Process.run(
    Platform.resolvedExecutable,
    [entrypoint, ...arguments],
    workingDirectory: project.path,
    environment: environment,
  ).timeout(const Duration(seconds: 60));

  /// Starts the entrypoint and waits for it to say it is listening.
  Future<(Process, StringBuffer)> start() async {
    final Process server = await Process.start(
      Platform.resolvedExecutable,
      ['bin/serve.dart'],
      workingDirectory: project.path,
      environment: {'PORT': '${await _freePort()}'},
    );
    addTearDown(() => server.kill(ProcessSignal.sigkill));
    final output = StringBuffer();
    final listening = Completer<void>();
    for (final stream in [server.stdout, server.stderr]) {
      stream.transform(utf8.decoder).listen((chunk) {
        output.write(chunk);
        if (!listening.isCompleted && output.toString().contains('listening')) {
          listening.complete();
        }
      });
    }
    unawaited(
      server.exitCode.then((code) {
        if (!listening.isCompleted) {
          listening.completeError(StateError('exited $code:\n$output'));
        }
      }),
    );
    await listening.future.timeout(const Duration(seconds: 60));
    return (server, output);
  }

  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    test('$signal closes the server and exits cleanly', () async {
      final (Process server, StringBuffer output) = await start();

      server.kill(signal);
      final int code = await server.exitCode.timeout(
        const Duration(seconds: 30),
      );

      expect(code, 0, reason: '$output');
      expect(File('${project.path}/closed').existsSync(), isTrue);
      expect(output.toString(), contains('shutting down'));
    });
  }

  group('a configuration the host refuses', () {
    test(
      'ends bin/serve.dart with one line and exit 78, not a trace',
      () async {
        // A bad PORT, DATABASE_URL or storage variable used to end as
        // "Unhandled exception:" and a stack trace, exit 255.
        final ProcessResult result = await run('bin/serve.dart', {
          'PROBE_CONFIG_ERROR': 'PORT must be a number, got "abc"',
        });

        expect(result.exitCode, 78);
        expect(
          '${result.stderr}'.trim(),
          'error: PORT must be a number, got "abc"',
        );
        expect(result.stdout, isEmpty);
      },
    );

    test('ends bin/migrate.dart the same way', () async {
      final ProcessResult result = await run(
        'bin/migrate.dart',
        {'PROBE_CONFIG_ERROR': 'Unsupported DATABASE_URL scheme "ftp"'},
        const ['migrate'],
      );

      expect(result.exitCode, 78);
      expect(
        '${result.stderr}'.trim(),
        'error: Unsupported DATABASE_URL scheme "ftp"',
      );
    });

    test('leaves the exit code of a migration alone', () async {
      final ProcessResult result = await run(
        'bin/migrate.dart',
        {'PROBE_EXIT': '3'},
        const ['migrate'],
      );

      expect(result.exitCode, 3);
      expect(result.stderr, isEmpty);
    });
  });

  test('is formatted, so a project sees no diff on its first format', () {
    for (final source in [
      BeakEmitters.serveEntrypoint('probe'),
      BeakEmitters.migrateEntrypoint('probe'),
    ]) {
      final String formatted = BeakEmitters.format(source);

      expect(BeakEmitters.format(formatted), formatted);
    }
  });
}

/// A port nothing is listening on, released before it is handed over.
Future<int> _freePort() async {
  final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final int port = probe.port;
  await probe.close();
  return port;
}
