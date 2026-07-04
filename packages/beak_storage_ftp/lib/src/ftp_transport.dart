import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';

/// Raised by [FtpTransport] implementations when the server answers with an
/// unexpected reply, carrying the FTP [replyCode] so callers can distinguish
/// missing files (`550`) from other failures.
final class FtpProtocolException implements Exception {
  /// Creates an exception for [replyCode] with the server's reply [message].
  const FtpProtocolException(this.replyCode, this.message);

  /// The three-digit FTP reply code; `0` when the connection died before a
  /// reply arrived.
  final int replyCode;

  /// The full reply (or failure description).
  final String message;

  @override
  String toString() => 'FtpProtocolException($replyCode): $message';
}

/// The thin seam between [FtpStorageDriver] logic and the FTP wire protocol,
/// so driver behavior is unit-testable against a fake.
///
/// Keys are validated, `/`-separated storage keys; implementations resolve
/// them under the configured base directory. Failures surface as
/// [FtpProtocolException]s (or raw socket errors); the driver maps them to
/// [BeakStorageException]. The production implementation is
/// [SocketFtpTransport]; a test supplies its own via the `FtpStorageDriver`
/// `transport` parameter.
///
/// ```dart
/// final class FakeFtpTransport implements FtpTransport {
///   final Map<String, Uint8List> files = {};
///   // ... implement store/retrieve/remove/exists against `files`,
///   //     throwing FtpProtocolException(550, ...) for a missing key.
/// }
///
/// final driver = FtpStorageDriver(config, transport: FakeFtpTransport());
/// ```
abstract interface class FtpTransport {
  /// Uploads [bytes] under [key], creating missing parent directories.
  Future<void> store(String key, Uint8List bytes);

  /// Downloads the file stored under [key].
  Future<Uint8List> retrieve(String key);

  /// Deletes the file stored under [key].
  Future<void> remove(String key);

  /// Whether a file is stored under [key].
  Future<bool> exists(String key);
}

/// The production [FtpTransport]: a minimal RFC 959 client over `dart:io`
/// sockets (binary type, passive mode), opening one fresh, cleanly closed
/// control connection per operation.
///
/// Each call connects, logs in ([BeakFtpConfig.user]/[BeakFtpConfig.password]),
/// switches to binary type, runs the operation under [BeakFtpConfig.baseDir]
/// and tears the connection down — there is no pooling or persistent session.
/// [FtpStorageDriver] builds one of these from its config; application code
/// rarely instantiates it directly.
///
/// ```dart
/// final transport = SocketFtpTransport(config);
/// await transport.store('products/42/photo.jpg', bytes);
/// final exists = await transport.exists('products/42/photo.jpg');
/// ```
final class SocketFtpTransport implements FtpTransport {
  /// Creates a transport connecting per [config].
  SocketFtpTransport(BeakFtpConfig config)
    : _config = config,
      _baseDir = config.baseDir.replaceAll(RegExp(r'/+$'), '');

  static const Duration _connectTimeout = Duration(seconds: 10);

  final BeakFtpConfig _config;
  final String _baseDir;

  @override
  Future<void> store(String key, Uint8List bytes) {
    return _withSession((session) async {
      await _ensureParentDirectories(session, key);
      final Socket data = await _openDataConnection(session);
      try {
        await session.command(
          'STOR ${_remotePathFor(key)}',
          expecting: const {125, 150},
        );
        data.add(bytes);
        await data.flush();
      } finally {
        await data.close();
        data.destroy();
      }
      await session.readExpecting(const {226, 250});
    });
  }

  @override
  Future<Uint8List> retrieve(String key) {
    return _withSession((session) async {
      final Socket data = await _openDataConnection(session);
      try {
        await session.command(
          'RETR ${_remotePathFor(key)}',
          expecting: const {125, 150},
        );
        final BytesBuilder builder = BytesBuilder(copy: false);
        await data.forEach(builder.add);
        await session.readExpecting(const {226, 250});
        return builder.takeBytes();
      } finally {
        data.destroy();
      }
    });
  }

  @override
  Future<void> remove(String key) {
    return _withSession((session) async {
      await session.command(
        'DELE ${_remotePathFor(key)}',
        expecting: const {250},
      );
    });
  }

  @override
  Future<bool> exists(String key) {
    return _withSession((session) async {
      try {
        await session.command(
          'SIZE ${_remotePathFor(key)}',
          expecting: const {213},
        );
        return true;
      } on FtpProtocolException catch (error) {
        if (error.replyCode == 550) {
          return false;
        }
        rethrow;
      }
    });
  }

  String _remotePathFor(String key) => '$_baseDir/$key';

  /// Connects, logs in, switches to binary type, runs [body], and always
  /// tears the control connection down.
  Future<T> _withSession<T>(Future<T> Function(_FtpSession) body) async {
    final Socket socket = await Socket.connect(
      _config.host,
      _config.port,
      timeout: _connectTimeout,
    );
    final session = _FtpSession(socket);
    try {
      await session.readExpecting(const {220});
      final reply = await session.command(
        'USER ${_config.user}',
        expecting: const {230, 331},
      );
      if (reply.code == 331) {
        await session.command(
          'PASS ${_config.password}',
          expecting: const {230},
        );
      }
      await session.command('TYPE I', expecting: const {200});
      final T result = await body(session);
      await session.quit();
      return result;
    } finally {
      socket.destroy();
    }
  }

  /// Creates the base directory and the key's parent chain with MKD;
  /// already-existing directories reply `550` and are skipped. A directory
  /// that truly cannot be created fails the subsequent STOR instead.
  ///
  /// The MKD targets share [_remotePathFor]'s rooting — absolute when the
  /// base directory is absolute (or empty), relative otherwise — so the
  /// directories created are exactly the ones STOR/RETR resolve against,
  /// including on non-chrooted servers whose login directory is not the
  /// filesystem root.
  Future<void> _ensureParentDirectories(_FtpSession session, String key) async {
    final segments = [
      ..._baseDir.split('/').where((segment) => segment.isNotEmpty),
      ...key.split('/')..removeLast(),
    ];
    final bool absolute = _baseDir.isEmpty || _baseDir.startsWith('/');
    var path = '';
    for (final segment in segments) {
      path = path.isEmpty
          ? (absolute ? '/$segment' : segment)
          : '$path/$segment';
      try {
        await session.command('MKD $path', expecting: const {257});
      } on FtpProtocolException {
        // Existing directories are expected here; anything else surfaces
        // when the transfer itself is attempted.
      }
    }
  }

  /// Enters passive mode and opens the announced data connection (to the
  /// configured host — the address in the reply is not trusted across NAT).
  Future<Socket> _openDataConnection(_FtpSession session) async {
    final reply = await session.command('PASV', expecting: const {227});
    final match = RegExp(
      r'\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)',
    ).firstMatch(reply.text);
    if (match == null) {
      throw FtpProtocolException(227, 'Malformed PASV reply: ${reply.text}');
    }
    final int port =
        int.parse(match.group(5)!) * 256 + int.parse(match.group(6)!);
    return Socket.connect(_config.host, port, timeout: _connectTimeout);
  }
}

/// One logged-in FTP control connection: sends commands and parses
/// (possibly multi-line) replies.
final class _FtpSession {
  _FtpSession(this._socket);

  final Socket _socket;
  late final StreamIterator<String> _lines = StreamIterator(
    const LineSplitter().bind(utf8.decoder.bind(_socket)),
  );

  /// Sends [command] and returns the reply, requiring one of [expecting].
  Future<_FtpReply> command(String command, {required Set<int> expecting}) {
    _socket.write('$command\r\n');
    return readExpecting(expecting);
  }

  /// Reads the next reply, requiring one of [expecting].
  Future<_FtpReply> readExpecting(Set<int> expecting) async {
    final reply = await _read();
    if (!expecting.contains(reply.code)) {
      throw FtpProtocolException(reply.code, reply.text);
    }
    return reply;
  }

  Future<_FtpReply> _read() async {
    final lines = <String>[];
    while (await _lines.moveNext()) {
      final line = _lines.current;
      lines.add(line);
      final match = RegExp(r'^(\d{3})(?: |$)').firstMatch(line);
      if (match != null) {
        return _FtpReply(int.parse(match.group(1)!), lines.join('\n'));
      }
    }
    throw const FtpProtocolException(
      0,
      'The control connection closed before a reply arrived.',
    );
  }

  /// Says goodbye; the session is torn down regardless of the outcome.
  Future<void> quit() async {
    try {
      await command('QUIT', expecting: const {221});
    } on Object {
      // Best-effort courtesy only — the socket is destroyed either way.
    }
  }
}

/// A parsed FTP reply: the final [code] plus the full [text].
final class _FtpReply {
  const _FtpReply(this.code, this.text);

  final int code;
  final String text;
}
