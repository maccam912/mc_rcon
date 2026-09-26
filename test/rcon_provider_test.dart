import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mc_rcon/models/server_connection.dart';
import 'package:mc_rcon/providers/rcon_provider.dart';
import 'package:mc_rcon/services/rcon_client.dart';
import 'package:mc_rcon/services/storage_service.dart';

class _MemoryStorage extends StorageService {
  @override
  Future<List<ServerConnection>> getConnections() async => [];

  @override
  Future<void> setLastConnectionId(String id) async {}
}

class _FakeRconClient extends RconClient {
  bool connected = false;
  bool botPresent = false;
  final Map<String, String> bans = {};
  int connectCount = 0;
  final commands = <String>[];
  final connectionEvents = StreamController<bool>.broadcast();
  Future<String> Function(String)? commandHandler;
  Future<bool> Function(int)? connectHandler;
  void Function()? onConnect;

  @override
  bool get isConnected => connected;

  @override
  Stream<bool> get connectionStream => connectionEvents.stream;

  @override
  Future<bool> connect(String host, int port, String password) async {
    connectCount++;
    final attempt = connectCount;
    final success = await (connectHandler?.call(attempt) ?? Future.value(true));
    if (attempt != connectCount || !success) return false;
    connected = true;
    connectionEvents.add(true);
    onConnect?.call();
    return true;
  }

  void dropConnection() {
    connected = false;
    connectionEvents.add(false);
  }

  @override
  Future<void> disconnect() async {
    if (connected) dropConnection();
  }

  @override
  Future<String> sendCommand(String command) async {
    if (!connected) throw const SocketException('Disconnected');
    commands.add(command);
    if (commandHandler != null) return commandHandler!(command);
    return defaultResponse(command);
  }

  String defaultResponse(String command) {
    if (command == 'list') {
      if (bans.containsKey('Alex')) {
        return 'There are 0 of a max of 20 players online:';
      }
      return botPresent
          ? 'There are 2 of a max of 20 players online: Alex, [Bot]Alex'
          : 'There are 1 of a max of 20 players online: Alex';
    }
    if (command == 'banlist players') {
      if (bans.isEmpty) return 'There are no bans';
      final entries = bans.entries
          .map((entry) => '${entry.key} was banned by Rcon: ${entry.value}')
          .join('\n');
      return 'There are ${bans.length} ban(s):$entries';
    }
    if (command.startsWith('ban ')) {
      final parts = command.split(' ');
      bans[parts[1]] = parts.skip(2).join(' ');
      return 'Banned ${parts[1]}';
    }
    if (command.startsWith('pardon ')) {
      bans.remove(command.substring(7));
      return 'Unbanned ${command.substring(7)}';
    }
    return 'Done';
  }

  @override
  void dispose() {
    connected = false;
    connectionEvents.close();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final connection = ServerConnection(
    id: 'one',
    name: 'Test server',
    host: 'localhost',
    port: 25575,
    password: 'secret',
  );

  late _FakeRconClient client;
  late RconProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _FakeRconClient();
    provider = RconProvider(
      client: client,
      storage: _MemoryStorage(),
      pollInterval: const Duration(hours: 1),
    );
  });

  tearDown(() => provider.dispose());

  test(
    'local policy and timed kick persist and release through standard RCON',
    () async {
      expect(await provider.connect(connection), isTrue);
      expect(provider.supportsPlayerTimers, isTrue);
      await provider.setPlayPolicy('Alex', 60, 2);
      expect(provider.timerStatusFor('Alex')?.enabled, isTrue);
      expect(provider.timerStatusFor('Alex')?.playSeconds, 3600);
      expect(provider.timerStatusFor('Alex')?.breakSeconds, 120);
      await provider.kickPlayer('Alex', 'Take five', lockoutMinutes: 5);
      expect(client.bans['Alex'], contains('[mc_rcon:'));
      expect(
        provider.timerStatusFor('Alex')?.remainingBreak.inMinutes,
        inInclusiveRange(4, 5),
      );
      await provider.disconnect();
      expect(await provider.connect(connection), isTrue);
      expect(provider.timerStatusFor('Alex')?.enabled, isTrue);
      expect(provider.timerStatusFor('Alex')?.blockedUntil, isNotNull);
      await provider.releasePlayer('Alex');
      expect(client.bans, isEmpty);
      expect(provider.timerStatusFor('Alex')?.blockedUntil, isNull);
      expect(
        client.commands.any((command) => command.startsWith('assistantadmin ')),
        isFalse,
      );
    },
  );

  test(
    'a replaced connection attempt cannot clear the newly selected server',
    () async {
      final firstStarted = Completer<void>();
      final finishFirst = Completer<bool>();
      client.connectHandler = (attempt) async {
        if (attempt == 1) {
          firstStarted.complete();
          return finishFirst.future;
        }
        return true;
      };
      final first = provider.connect(connection);
      await firstStarted.future;
      final secondConnection = connection.copyWith(
        id: 'two',
        name: 'Second server',
      );
      expect(await provider.connect(secondConnection), isTrue);
      finishFirst.complete(false);
      expect(await first, isFalse);
      expect(provider.currentConnection, secondConnection);
      expect(provider.isConnected, isTrue);
      expect(provider.lastError, isNull);
    },
  );

  test('a stale command error cannot overwrite a new server state', () async {
    expect(await provider.connect(connection), isTrue);
    final commandStarted = Completer<void>();
    final commandResponse = Completer<String>();
    client.commandHandler = (command) async {
      if (command == 'give Alex minecraft:stone 1') {
        commandStarted.complete();
        return commandResponse.future;
      }
      return client.defaultResponse(command);
    };
    final pending = expectLater(
      provider.giveItem('Alex', 'minecraft:stone', 1),
      throwsA(isA<RconCommandException>()),
    );
    await commandStarted.future;
    final secondConnection = connection.copyWith(
      id: 'two',
      name: 'Second server',
    );
    expect(await provider.connect(secondConnection), isTrue);
    commandResponse.completeError(const SocketException('Old socket closed'));
    await pending;
    expect(provider.currentConnection, secondConnection);
    expect(provider.lastError, isNull);
  });

  test(
    'refresh reconnects a lost idle connection and retains player list',
    () async {
      expect(await provider.connect(connection), isTrue);
      expect(provider.players.single.name, 'Alex');
      client.dropConnection();
      await provider.refreshPlayers();
      expect(client.connectCount, 2);
      expect(provider.isConnected, isTrue);
      expect(provider.players.single.name, 'Alex');
      expect(provider.lastError, isNull);
    },
  );

  test('periodic monitoring reconnects without a user action', () async {
    provider.dispose();
    client = _FakeRconClient();
    provider = RconProvider(
      client: client,
      storage: _MemoryStorage(),
      pollInterval: const Duration(milliseconds: 20),
    );
    expect(await provider.connect(connection), isTrue);
    final reconnected = Completer<void>();
    client.onConnect = () {
      if (!reconnected.isCompleted) reconnected.complete();
    };
    client.dropConnection();
    await reconnected.future.timeout(const Duration(seconds: 1));
    expect(client.connectCount, 2);
    expect(provider.isConnected, isTrue);
  });

  test(
    'server command errors throw and are exposed in provider state',
    () async {
      expect(await provider.connect(connection), isTrue);
      client.commandHandler = (command) async =>
          command == 'give Alex missing_item 1'
          ? 'Unknown item missing_item<--[HERE]'
          : client.defaultResponse(command);
      await expectLater(
        provider.giveItem('Alex', 'missing_item', 1),
        throwsA(isA<RconCommandException>()),
      );
      expect(provider.lastError, contains('Unknown item'));
      expect(provider.isConnected, isTrue);
    },
  );

  test(
    'interrupted mutations report uncertainty and are never replayed',
    () async {
      expect(await provider.connect(connection), isTrue);
      client.commandHandler = (command) async {
        if (command == 'give Alex minecraft:diamond 1') {
          client.dropConnection();
          throw const SocketException('The socket closed after writing');
        }
        return client.defaultResponse(command);
      };
      await expectLater(
        provider.giveItem('Alex', 'minecraft:diamond', 1),
        throwsA(isA<RconCommandException>()),
      );
      expect(provider.lastError, contains('Check the result before retrying'));
      await provider.refreshPlayers();
      expect(
        client.commands.where(
          (command) => command == 'give Alex minecraft:diamond 1',
        ),
        hasLength(1),
      );
      expect(provider.isConnected, isTrue);
    },
  );

  test(
    'legacy assistant bots are dismissed and their removal is verified',
    () async {
      client.botPresent = true;
      client.commandHandler = (command) async {
        if (command == 'assistant Alex dismiss') {
          client.botPresent = false;
          return '';
        }
        return client.defaultResponse(command);
      };
      expect(await provider.connect(connection), isTrue);
      expect(provider.players.last.isBot, isTrue);
      expect(await provider.kickPlayer('[Bot]Alex', ''), 'Dismissed [Bot]Alex');
      expect(client.commands, contains('assistant Alex dismiss'));
      expect(
        client.commands.any((command) => command.startsWith('kick ')),
        isFalse,
      );
      expect(provider.players, hasLength(1));
    },
  );

  test(
    'legacy bot dismissal cannot falsely report success when bot remains',
    () async {
      client.botPresent = true;
      expect(await provider.connect(connection), isTrue);
      await expectLater(
        provider.kickPlayer('[Bot]Alex', ''),
        throwsA(isA<RconCommandException>()),
      );
    },
  );

  test(
    'invalid commands and selectors are rejected before touching server',
    () async {
      expect(await provider.connect(connection), isTrue);
      final initialCommands = client.commands.length;
      await expectLater(
        provider.sendCommand('list\nkick Alex'),
        throwsA(isA<RconCommandException>()),
      );
      expect(
        () => provider.giveItem('@a', 'minecraft:stone', 1),
        throwsA(isA<RconCommandException>()),
      );
      expect(
        () => provider.giveItem('Alex', 'stone 1', 1),
        throwsA(isA<RconCommandException>()),
      );
      expect(client.commands, hasLength(initialCommands));
    },
  );
}
