import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

enum RconPacketType {
  auth(3),
  authResponse(2),
  command(2),
  response(0);

  const RconPacketType(this.value);
  final int value;
}

class RconPacket {
  // Bound allocation even when a broken or unrelated service answers this port.
  static const maxLength = 4 * 1024 * 1024;

  final int id;
  final int type;
  final String payload;

  RconPacket({required this.id, required this.type, required this.payload});

  Uint8List toBytes() {
    if (payload.contains('\u0000')) {
      throw const FormatException('RCON payloads cannot contain null bytes');
    }
    final payloadBytes = utf8.encode(payload);
    final length = 10 + payloadBytes.length;
    if (length > maxLength) {
      throw const FormatException('RCON packet is too large');
    }
    final buffer = ByteData(4 + length);
    buffer.setInt32(0, length, Endian.little);
    buffer.setInt32(4, id, Endian.little);
    buffer.setInt32(8, type, Endian.little);
    final bytes = buffer.buffer.asUint8List();
    bytes.setRange(12, 12 + payloadBytes.length, payloadBytes);
    return bytes;
  }

  static RconPacket? fromBytes(Uint8List data) {
    if (data.length < 4) return null;
    final buffer = ByteData.sublistView(data);
    final length = buffer.getInt32(0, Endian.little);
    if (length < 10 || length > maxLength) {
      throw FormatException('Invalid RCON packet length: $length');
    }
    if (data.length < length + 4) return null;
    if (data.length != length + 4 ||
        data[data.length - 2] != 0 ||
        data[data.length - 1] != 0) {
      throw const FormatException('Invalid RCON packet framing');
    }
    final payload = data.sublist(12, data.length - 2);
    if (payload.contains(0)) {
      throw const FormatException('Invalid RCON payload terminator');
    }
    return RconPacket(
      id: buffer.getInt32(4, Endian.little),
      type: buffer.getInt32(8, Endian.little),
      payload: utf8.decode(payload),
    );
  }
}

class RconAuthenticationException implements Exception {
  const RconAuthenticationException();

  @override
  String toString() => 'RCON authentication failed. Check the server password.';
}

class _PendingCommand {
  _PendingCommand(this.id, this.endId);

  final int id;
  final int endId;
  final completer = Completer<String>();
  final response = StringBuffer();
  bool probeSent = false;
}

class RconClient {
  RconClient({
    this.connectTimeout = const Duration(seconds: 10),
    this.authTimeout = const Duration(seconds: 10),
    this.commandTimeout = const Duration(seconds: 30),
  });

  final Duration connectTimeout;
  final Duration authTimeout;
  final Duration commandTimeout;
  Socket? _socket;
  int _requestId = 0;
  int _generation = 0;
  bool _isAuthenticated = false;
  bool _disposed = false;
  Object? _lastError;
  Completer<void>? _authentication;
  int? _authId;
  _PendingCommand? _pendingCommand;
  Future<void> _commandQueue = Future<void>.value();
  final List<int> _buffer = [];

  String? host;
  int? port;

  bool get isConnected => _socket != null && _isAuthenticated;
  Object? get lastError => _lastError;

  final StreamController<String> _responseController =
      StreamController<String>.broadcast();
  Stream<String> get responseStream => _responseController.stream;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  void _emitConnectionState(bool connected) {
    if (!_connectionController.isClosed) {
      _connectionController.add(connected);
    }
  }

  Future<bool> connect(String host, int port, String password) async {
    if (_disposed) throw StateError('RCON client has been disposed');
    _closeConnection(const SocketException('RCON connection replaced'));
    final generation = _generation;
    this.host = host;
    this.port = port;
    _lastError = null;
    developer.log('Connecting to $host:$port', name: 'RconClient');

    final Socket socket;
    try {
      socket = await Socket.connect(host, port, timeout: connectTimeout);
    } catch (error) {
      if (generation != _generation) return false;
      _lastError = error;
      _emitConnectionState(false);
      rethrow;
    }
    // A cancelled/replaced connection may still finish opening its TCP socket.
    if (_disposed || generation != _generation) {
      socket.destroy();
      return false;
    }
    _socket = socket;
    socket.setOption(SocketOption.tcpNoDelay, true);
    socket.listen(
      (data) {
        if (generation == _generation) _onData(data);
      },
      onError: (Object error) {
        if (generation == _generation) _closeConnection(error);
      },
      onDone: () {
        if (generation == _generation) {
          _closeConnection(
            const SocketException('RCON server closed the connection'),
          );
        }
      },
    );

    final authentication = Completer<void>();
    _authentication = authentication;
    _authId = _getNextId();
    try {
      try {
        socket.add(
          RconPacket(
            id: _authId!,
            type: RconPacketType.auth.value,
            payload: password,
          ).toBytes(),
        );
      } catch (error) {
        _closeConnection(error);
      }
      // Await even a synchronous write failure so its completer error always
      // has a listener, rather than escaping as an unhandled asynchronous error.
      await authentication.future.timeout(authTimeout);
      if (generation != _generation || _disposed) return false;
      _authentication = null;
      _authId = null;
      _isAuthenticated = true;
      _lastError = null;
      _emitConnectionState(true);
      return true;
    } catch (error) {
      if (generation == _generation) _closeConnection(error);
      return false;
    }
  }

  void _onData(Uint8List data) {
    _buffer.addAll(data);
    try {
      while (_buffer.length >= 4) {
        final packetLength = ByteData.sublistView(
          Uint8List.fromList(_buffer.sublist(0, 4)),
        ).getInt32(0, Endian.little);
        if (packetLength < 10 || packetLength > RconPacket.maxLength) {
          throw FormatException('Invalid RCON packet length: $packetLength');
        }
        if (_buffer.length < packetLength + 4) return;
        final packetData = Uint8List.fromList(
          _buffer.sublist(0, packetLength + 4),
        );
        _buffer.removeRange(0, packetLength + 4);
        _handlePacket(RconPacket.fromBytes(packetData)!);
        if (_socket == null) return;
      }
    } catch (error) {
      _closeConnection(error);
    }
  }

  void _handlePacket(RconPacket packet) {
    if (packet.id == -1 && packet.type == RconPacketType.authResponse.value) {
      _closeConnection(const RconAuthenticationException());
      return;
    }
    final authentication = _authentication;
    if (authentication != null) {
      // Some servers send an empty response packet before the real auth reply.
      // A matching ID alone does not establish authentication.
      if (packet.id == _authId &&
          packet.type == RconPacketType.authResponse.value &&
          !authentication.isCompleted) {
        authentication.complete();
      }
      return;
    }
    if (packet.type != RconPacketType.response.value) {
      throw const FormatException('Unexpected RCON response packet type');
    }
    final pending = _pendingCommand;
    if (pending == null) return;
    if (packet.id == pending.id) {
      pending.response.write(packet.payload);
      if (!pending.probeSent) {
        pending.probeSent = true;
        // Minecraft processes commands in order. The reply to an empty command
        // marks the end of this response, including every split response packet.
        // Send it only after the first reply: some Minecraft servers cannot read
        // multiple request packets coalesced into the same socket read.
        _socket!.add(
          RconPacket(
            id: pending.endId,
            type: RconPacketType.command.value,
            payload: '',
          ).toBytes(),
        );
      }
    } else if (packet.id == pending.endId && pending.probeSent) {
      _pendingCommand = null;
      final response = pending.response.toString();
      pending.completer.complete(response);
      if (response.isNotEmpty && !_responseController.isClosed) {
        _responseController.add(response);
      }
    }
  }

  void _closeConnection(Object error) {
    final wasOpen = _socket != null || _isAuthenticated;
    _generation++;
    _isAuthenticated = false;
    _lastError = error;
    final socket = _socket;
    _socket = null;
    socket?.destroy();
    _buffer.clear();
    final authentication = _authentication;
    _authentication = null;
    _authId = null;
    if (authentication != null && !authentication.isCompleted) {
      authentication.completeError(error);
    }
    final pending = _pendingCommand;
    _pendingCommand = null;
    if (pending != null && !pending.completer.isCompleted) {
      pending.completer.completeError(error);
    }
    if (wasOpen) {
      developer.log('RCON connection closed', name: 'RconClient', error: error);
      _emitConnectionState(false);
    }
  }

  Future<void> disconnect() async {
    _closeConnection(const SocketException('RCON connection disconnected'));
  }

  Future<String> sendCommand(String command) {
    if (!isConnected) {
      return Future<String>.error(
        const SocketException('Not connected to RCON server'),
      );
    }
    final generation = _generation;
    // A queued command belongs to this connection. Never replay it after a
    // reconnect: an interrupted command may already have changed the server.
    final result = _commandQueue.then((_) => _sendCommand(command, generation));
    _commandQueue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<String> _sendCommand(String command, int generation) async {
    if (!isConnected || generation != _generation) {
      throw const SocketException(
        'RCON disconnected before the command was sent',
      );
    }
    final pending = _PendingCommand(_getNextId(), _getNextId());
    // Validate the payload before registering a request that needs completion.
    final bytes = RconPacket(
      id: pending.id,
      type: RconPacketType.command.value,
      payload: command,
    ).toBytes();
    _pendingCommand = pending;
    try {
      try {
        _socket!.add(bytes);
      } catch (error) {
        _closeConnection(error);
      }
      return await pending.completer.future.timeout(commandTimeout);
    } catch (error) {
      // A timeout means the connection is no longer trustworthy. Invalidate it
      // and all queued commands so the UI can reconnect and report uncertainty.
      if (generation == _generation) _closeConnection(error);
      rethrow;
    }
  }

  int _getNextId() {
    _requestId = _requestId >= 2147483647 ? 1 : _requestId + 1;
    return _requestId;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _closeConnection(const SocketException('RCON client disposed'));
    _responseController.close();
    _connectionController.close();
  }
}
