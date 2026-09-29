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
    }
  ]
}
''');
    write('lib/beak/server.g.dart', '''
import 'dart:async';
import 'dart:io';

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
  Future<HttpServer> serve() async => RecordingServer(
    await HttpServer.bind(
      '127.0.0.1',
      int.parse(Platform.environment['PORT']!),
    ),
  );
}

FakeHost beakHost() => FakeHost();
''');
    write('bin/serve.dart', BeakEmitters.serveEntrypoint('probe'));
  });

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

  test('is formatted, so a project sees no diff on its first format', () {
    final String source = BeakEmitters.format(
      BeakEmitters.serveEntrypoint('probe'),
    );

    expect(BeakEmitters.format(source), source);
  });
}

/// A port nothing is listening on, released before it is handed over.
Future<int> _freePort() async {
  final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final int port = probe.port;
  await probe.close();
  return port;
}
