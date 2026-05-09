import 'dart:async';
import 'dart:convert';
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
  final int id;
  final int type;
  final String payload;

  RconPacket({required this.id, required this.type, required this.payload});

  Uint8List toBytes() {
    final payloadBytes = utf8.encode(payload);
    final length = 4 + 4 + payloadBytes.length + 2; // id + type + payload + 2 null bytes

    final buffer = ByteData(4 + length);
    buffer.setInt32(0, length, Endian.little);
    buffer.setInt32(4, id, Endian.little);
    buffer.setInt32(8, type, Endian.little);

    final bytes = buffer.buffer.asUint8List();
    bytes.setRange(12, 12 + payloadBytes.length, payloadBytes);
    bytes[12 + payloadBytes.length] = 0;
    bytes[12 + payloadBytes.length + 1] = 0;

    return bytes;
  }

  static RconPacket? fromBytes(Uint8List data) {
    if (data.length < 14) return null;

    final buffer = ByteData.sublistView(data);
    final id = buffer.getInt32(4, Endian.little);
    final type = buffer.getInt32(8, Endian.little);

    // Find the null terminator for the payload
    int payloadEnd = 12;
    while (payloadEnd < data.length - 1 && data[payloadEnd] != 0) {
      payloadEnd++;
    }

    final payload = utf8.decode(data.sublist(12, payloadEnd));

    return RconPacket(id: id, type: type, payload: payload);
  }
}

class RconClient {
  Socket? _socket;
  int _requestId = 0;
  bool _isAuthenticated = false;
  final Map<int, Completer<String>> _pendingRequests = {};
  final List<int> _buffer = [];

  String? host;
  int? port;

  bool get isConnected => _socket != null && _isAuthenticated;

  final StreamController<String> _responseController =
      StreamController<String>.broadcast();
  Stream<String> get responseStream => _responseController.stream;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  Future<bool> connect(String host, int port, String password) async {
    this.host = host;
    this.port = port;

    try {
      _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
      _socket!.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
      );

      // Send auth packet
      final authId = _getNextId();
      final authPacket = RconPacket(
        id: authId,
        type: RconPacketType.auth.value,
        payload: password,
      );

      final completer = Completer<String>();
      _pendingRequests[authId] = completer;

      _socket!.add(authPacket.toBytes());

      // Wait for auth response with timeout
      try {
        await completer.future.timeout(const Duration(seconds: 10));
        _isAuthenticated = true;
        _connectionController.add(true);
        return true;
      } catch (e) {
        await disconnect();
        return false;
      }
    } catch (e) {
      _connectionController.add(false);
      return false;
    }
  }

  void _onData(Uint8List data) {
    _buffer.addAll(data);

    // Process complete packets from buffer
    while (_buffer.length >= 4) {
      final lengthData = ByteData.sublistView(Uint8List.fromList(_buffer.sublist(0, 4)));
      final packetLength = lengthData.getInt32(0, Endian.little);

      if (_buffer.length >= packetLength + 4) {
        final packetData = Uint8List.fromList(_buffer.sublist(0, packetLength + 4));
        _buffer.removeRange(0, packetLength + 4);

        final packet = RconPacket.fromBytes(packetData);
        if (packet != null) {
          _handlePacket(packet);
        }
      } else {
        break;
      }
    }
  }

  void _handlePacket(RconPacket packet) {
    // Check if this is a response to a pending request
    if (_pendingRequests.containsKey(packet.id)) {
      _pendingRequests[packet.id]!.complete(packet.payload);
      _pendingRequests.remove(packet.id);
    }

    // Auth failed returns -1 id
    if (packet.id == -1) {
      _isAuthenticated = false;
      _connectionController.add(false);
    }

    // Broadcast the response
    if (packet.payload.isNotEmpty) {
      _responseController.add(packet.payload);
    }
  }

  void _onError(Object error) {
    _isAuthenticated = false;
    _connectionController.add(false);
    _pendingRequests.clear();
  }

  void _onDone() {
    _isAuthenticated = false;
    _connectionController.add(false);
    _pendingRequests.clear();
    _socket = null;
  }

  Future<void> disconnect() async {
    _isAuthenticated = false;
    await _socket?.close();
    _socket = null;
    _buffer.clear();
    _pendingRequests.clear();
    _connectionController.add(false);
  }

  Future<String> sendCommand(String command) async {
    if (!isConnected) {
      throw Exception('Not connected to RCON server');
    }

    final requestId = _getNextId();
    final packet = RconPacket(
      id: requestId,
      type: RconPacketType.command.value,
      payload: command,
    );

    final completer = Completer<String>();
    _pendingRequests[requestId] = completer;

    _socket!.add(packet.toBytes());

    try {
      return await completer.future.timeout(const Duration(seconds: 30));
    } catch (e) {
      _pendingRequests.remove(requestId);
      rethrow;
    }
  }

  int _getNextId() {
    _requestId++;
    if (_requestId > 2147483647) {
      _requestId = 1;
    }
    return _requestId;
  }

  void dispose() {
    disconnect();
    _responseController.close();
    _connectionController.close();
  }
}
