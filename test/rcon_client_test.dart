import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_rcon/services/rcon_client.dart';

class _RconServer {
  _RconServer(this.server);

  final ServerSocket server;
  final List<Socket> sockets = [];
  late Future<void> Function(Socket, RconPacket) onPacket;

  static Future<_RconServer> start() async {
    final fixture = _RconServer(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    );
    fixture.server.listen((socket) {
      fixture.sockets.add(socket);
      final buffer = <int>[];
      var queue = Future<void>.value();
      socket.listen((bytes) {
        buffer.addAll(bytes);
        while (buffer.length >= 4) {
          final length = ByteData.sublistView(
            Uint8List.fromList(buffer),
          ).getInt32(0, Endian.little);
          if (buffer.length < length + 4) break;
          final packet = RconPacket.fromBytes(
            Uint8List.fromList(buffer.sublist(0, length + 4)),
          )!;
          buffer.removeRange(0, length + 4);
          queue = queue.then((_) => fixture.onPacket(socket, packet));
        }
      }, onError: (Object error) {});
    });
    fixture.onPacket = (socket, packet) async {
      fixture.reply(socket, packet, packet.type == 3 ? '' : 'OK');
    };
    return fixture;
  }

  void reply(
    Socket socket,
    RconPacket request,
    String text, {
    int? id,
    int? type,
  }) {
    socket.add(
      RconPacket(
        id: id ?? request.id,
        type: type ?? (request.type == 3 ? 2 : 0),
        payload: text,
      ).toBytes(),
    );
  }

  Future<bool> connect(RconClient client) =>
      client.connect('127.0.0.1', server.port, 'secret');

  Future<void> close() async {
    for (final socket in sockets) {
      socket.destroy();
    }
    await server.close();
  }
}

void main() {
  group('RCON framing', () {
    test('round trips UTF-8 and waits for a complete packet', () {
      final bytes = RconPacket(id: 7, type: 0, payload: 'Hello 🌎').toBytes();
      expect(
        RconPacket.fromBytes(Uint8List.sublistView(bytes, 0, bytes.length - 1)),
        isNull,
      );
      final parsed = RconPacket.fromBytes(bytes)!;
      expect(parsed.id, 7);
      expect(parsed.type, 0);
      expect(parsed.payload, 'Hello 🌎');
    });

    test('rejects invalid lengths, terminators and embedded nulls', () {
      for (final length in [-10, 0, 9, RconPacket.maxLength + 1]) {
        final bytes = ByteData(4)..setInt32(0, length, Endian.little);
        expect(
          () => RconPacket.fromBytes(bytes.buffer.asUint8List()),
          throwsFormatException,
        );
      }
      final bytes = RconPacket(id: 1, type: 0, payload: 'hello').toBytes();
      bytes[bytes.length - 1] = 1;
      expect(() => RconPacket.fromBytes(bytes), throwsFormatException);
      expect(
        () => RconPacket(id: 1, type: 2, payload: 'one\u0000two').toBytes(),
        throwsFormatException,
      );
    });
  });

  group('RCON transport', () {
    late _RconServer server;
    late RconClient client;

    setUp(() async {
      server = await _RconServer.start();
      client = RconClient(
        authTimeout: const Duration(seconds: 1),
        commandTimeout: const Duration(seconds: 2),
      );
    });

    tearDown(() async {
      client.dispose();
      await server.close();
    });

    test(
      'requires an auth response, even after a matching empty response',
      () async {
        final receivedAuth = Completer<void>();
        final sendAuthResponse = Completer<void>();
        server.onPacket = (socket, packet) async {
          server.reply(socket, packet, '', type: 0);
          receivedAuth.complete();
          await sendAuthResponse.future;
          final bytes = RconPacket(
            id: packet.id,
            type: 2,
            payload: '',
          ).toBytes();
          socket.add(bytes.sublist(0, 3));
          await socket.flush();
          await Future<void>.delayed(const Duration(milliseconds: 10));
          socket.add(bytes.sublist(3));
        };
        final connecting = server.connect(client);
        await receivedAuth.future;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(client.isConnected, isFalse);
        sendAuthResponse.complete();
        expect(await connecting, isTrue);
        expect(client.isConnected, isTrue);
      },
    );

    test('reports a rejected password immediately', () async {
      server.onPacket = (socket, packet) async {
        server.reply(socket, packet, '', id: -1, type: 2);
      };
      expect(
        await server.connect(client).timeout(const Duration(milliseconds: 500)),
        isFalse,
      );
      expect(client.lastError, isA<RconAuthenticationException>());
      expect(client.isConnected, isFalse);
    });

    test('rejects malformed input during authentication', () async {
      server.onPacket = (socket, packet) async {
        socket.add(
          (ByteData(4)..setInt32(0, -1, Endian.little)).buffer.asUint8List(),
        );
      };
      expect(await server.connect(client), isFalse);
      expect(client.lastError, isA<FormatException>());
    });

    test(
      'invalid auth payload fails without an unhandled completer error',
      () async {
        expect(
          await client.connect(
            '127.0.0.1',
            server.server.port,
            'bad\u0000password',
          ),
          isFalse,
        );
        expect(client.lastError, isA<FormatException>());
        expect(client.isConnected, isFalse);
      },
    );

    test('auth timeout closes the socket and explains the failure', () async {
      client.dispose();
      client = RconClient(authTimeout: const Duration(milliseconds: 50));
      server.onPacket = (socket, packet) async {};
      expect(await server.connect(client), isFalse);
      expect(client.lastError, isA<TimeoutException>());
      expect(client.isConnected, isFalse);
    });

    test(
      'aggregates delayed and fragmented response packets before completing',
      () async {
        server.onPacket = (socket, packet) async {
          if (packet.type == 3 || packet.payload.isEmpty) {
            server.reply(socket, packet, '');
            return;
          }
          server.reply(socket, packet, 'first ');
          await socket.flush();
          await Future<void>.delayed(const Duration(milliseconds: 70));
          final second = RconPacket(
            id: packet.id,
            type: 0,
            payload: 'second ',
          ).toBytes();
          final third = RconPacket(
            id: packet.id,
            type: 0,
            payload: 'third',
          ).toBytes();
          socket.add(second.sublist(0, 6));
          await socket.flush();
          await Future<void>.delayed(const Duration(milliseconds: 10));
          socket.add([...second.sublist(6), ...third]);
        };
        expect(await server.connect(client), isTrue);
        final broadcast = client.responseStream.first;
        expect(await client.sendCommand('long response'), 'first second third');
        expect(await broadcast, 'first second third');
      },
    );

    test(
      'returns an empty successful response and serializes concurrent commands',
      () async {
        final received = <String>[];
        server.onPacket = (socket, packet) async {
          if (packet.type == 3) {
            server.reply(socket, packet, '');
            return;
          }
          received.add(packet.payload);
          server.reply(
            socket,
            packet,
            packet.payload == 'quiet' ? '' : packet.payload,
          );
        };
        expect(await server.connect(client), isTrue);
        expect(
          await Future.wait([
            client.sendCommand('quiet'),
            client.sendCommand('next'),
          ]),
          ['', 'next'],
        );
        expect(received, ['quiet', '', 'next', '']);
      },
    );

    test(
      'server close fails outstanding commands without waiting for timeout',
      () async {
        server.onPacket = (socket, packet) async {
          if (packet.type == 3) {
            server.reply(socket, packet, '');
          } else {
            socket.destroy();
          }
        };
        expect(await server.connect(client), isTrue);
        final disconnected = client.connectionStream.firstWhere(
          (state) => !state,
        );
        await expectLater(
          client.sendCommand('list').timeout(const Duration(milliseconds: 500)),
          throwsA(isA<SocketException>()),
        );
        await disconnected;
        expect(client.isConnected, isFalse);
      },
    );

    test(
      'malformed command responses disconnect and report their error',
      () async {
        server.onPacket = (socket, packet) async {
          if (packet.type == 3) {
            server.reply(socket, packet, '');
          } else {
            final bytes = RconPacket(
              id: packet.id,
              type: 0,
              payload: 'bad',
            ).toBytes();
            bytes[bytes.length - 2] = 42;
            socket.add(bytes);
          }
        };
        expect(await server.connect(client), isTrue);
        await expectLater(client.sendCommand('list'), throwsFormatException);
        expect(client.isConnected, isFalse);
      },
    );

    test(
      'timeout invalidates the connection and does not replay queued commands',
      () async {
        client.dispose();
        client = RconClient(commandTimeout: const Duration(milliseconds: 60));
        final received = <String>[];
        server.onPacket = (socket, packet) async {
          if (packet.type == 3) {
            server.reply(socket, packet, '');
          } else {
            received.add(packet.payload);
          }
        };
        expect(await server.connect(client), isTrue);
        final first = expectLater(
          client.sendCommand('first'),
          throwsA(isA<TimeoutException>()),
        );
        final second = expectLater(
          client.sendCommand('second'),
          throwsA(isA<SocketException>()),
        );
        await Future.wait([first, second]);
        expect(client.isConnected, isFalse);
        expect(received, ['first']);
        expect(await server.connect(client), isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(client.isConnected, isTrue);
        expect(received, ['first']);
      },
    );

    test(
      'disconnect fails pending work and old callbacks cannot break reconnect',
      () async {
        final commandReceived = Completer<void>();
        server.onPacket = (socket, packet) async {
          if (packet.type == 3 ||
              packet.payload.isEmpty ||
              packet.payload == 'next') {
            server.reply(socket, packet, packet.payload);
          } else {
            commandReceived.complete();
          }
        };
        expect(await server.connect(client), isTrue);
        final pending = expectLater(
          client.sendCommand('waiting'),
          throwsA(isA<SocketException>()),
        );
        await commandReceived.future;
        await client.disconnect();
        expect(await server.connect(client), isTrue);
        await pending;
        expect(await client.sendCommand('next'), 'next');
        expect(client.isConnected, isTrue);
      },
    );

    test(
      'replacing an authenticating socket cannot authenticate the new socket',
      () async {
        final firstAuth = Completer<void>();
        var attempts = 0;
        server.onPacket = (socket, packet) async {
          if (packet.type == 3) {
            attempts++;
            if (attempts == 1) {
              firstAuth.complete();
              return;
            }
          }
          server.reply(socket, packet, '');
        };
        final first = server.connect(client);
        await firstAuth.future;
        expect(await server.connect(client), isTrue);
        expect(await first, isFalse);
        expect(client.isConnected, isTrue);
        expect(await client.sendCommand('list'), '');
      },
    );

    test('disposing completes a pending command with an error', () async {
      final commandReceived = Completer<void>();
      server.onPacket = (socket, packet) async {
        if (packet.type == 3) {
          server.reply(socket, packet, '');
        } else {
          commandReceived.complete();
        }
      };
      expect(await server.connect(client), isTrue);
      final pending = expectLater(
        client.sendCommand('waiting'),
        throwsA(isA<SocketException>()),
      );
      await commandReceived.future;
      client.dispose();
      await pending;
      expect(client.isConnected, isFalse);
    });
  });
}
