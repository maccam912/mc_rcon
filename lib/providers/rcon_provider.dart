import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/player.dart';
import '../models/player_admin_status.dart';
import '../models/server_connection.dart';
import '../services/inventory_parser.dart';
import '../services/rcon_client.dart';
import '../services/player_timer_service.dart';
import '../services/storage_service.dart';

class RconCommandException implements Exception {
  final String message;
  const RconCommandException(this.message);
  @override
  String toString() => message;
}

class RconProvider extends ChangeNotifier with WidgetsBindingObserver {
  final RconClient _client;
  final StorageService _storage;
  final Duration pollInterval;
  late final StreamSubscription<bool> _connectionSubscription;
  Timer? _monitor;
  Future<bool>? _connecting;
  Future<void>? _refreshing;
  int _generation = 0;
  bool _disposed = false;
  DateTime? _lastHealthy;

  List<ServerConnection> _savedConnections = [];
  ServerConnection? _currentConnection;
  List<Player> _players = [];
  final List<String> _commandHistory = [];
  bool _isConnecting = false;
  String? _lastError;
  PlayerTimerService? _timers;
  String? _timerError;
  final StreamController<String> _noticeController =
      StreamController<String>.broadcast();

  List<ServerConnection> get savedConnections =>
      List.unmodifiable(_savedConnections);
  ServerConnection? get currentConnection => _currentConnection;
  List<Player> get players => List.unmodifiable(_players);
  List<String> get commandHistory => List.unmodifiable(_commandHistory);
  bool get isConnected => _client.isConnected;
  bool get isConnecting => _isConnecting;
  String? get lastError => _lastError;
  List<PlayerTimerStatus> get timerStatuses => _timers?.status ?? [];
  PlayerTimerStatus? timerStatusFor(String name) {
    for (final status in timerStatuses) {
      if (status.name.toLowerCase() == name.toLowerCase()) return status;
    }
    return null;
  }

  String? get timerError => _timerError;
  bool get supportsPlayerTimers => _timers != null;
  Stream<String> get notices => _noticeController.stream;
  Stream<String> get responseStream => _client.responseStream;
  Stream<bool> get connectionStream => _client.connectionStream;

  RconProvider({
    RconClient? client,
    StorageService? storage,
    this.pollInterval = const Duration(seconds: 10),
  }) : _client = client ?? RconClient(),
       _storage = storage ?? StorageService() {
    WidgetsBinding.instance.addObserver(this);
    _connectionSubscription = _client.connectionStream.listen((connected) {
      if (!connected && _currentConnection != null) {
        _lastHealthy = null;
        _timers?.suspend();
        _lastError = 'Connection lost. Reconnecting automatically…';
      }
      _notify();
    });
    unawaited(loadSavedConnections());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _timers?.suspend();
    }
    if (state == AppLifecycleState.resumed && _currentConnection != null) {
      _timers?.suspend();
      _lastHealthy = null;
      unawaited(refreshPlayers());
    }
  }

  Future<void> loadSavedConnections() async {
    try {
      _savedConnections = await _storage.getConnections();
    } catch (error) {
      _lastError = 'Could not load saved servers: $error';
    }
    _notify();
  }

  Future<void> saveConnection(ServerConnection connection) async {
    await _storage.saveConnection(connection);
    await loadSavedConnections();
  }

  Future<void> deleteConnection(String id) async {
    await _storage.deleteConnection(id);
    await loadSavedConnections();
  }

  Future<bool> connect(ServerConnection connection) async {
    final disconnecting = disconnect();
    final generation = _generation;
    await disconnecting;
    if (_disposed || generation != _generation) return false;
    _currentConnection = connection;
    final success = await _ensureConnected();
    if (_disposed || generation != _generation) return false;
    if (success) {
      try {
        await _storage.setLastConnectionId(connection.id);
      } catch (error) {
        if (!_disposed && generation == _generation) {
          _lastError = 'Connected, but could not save the last server: $error';
        }
      }
      if (_disposed || generation != _generation) return false;
      await _loadTimers(connection, generation);
      if (_disposed || generation != _generation) return false;
      _monitor = Timer.periodic(
        pollInterval,
        (_) => unawaited(refreshPlayers()),
      );
      await refreshPlayers();
    } else {
      _currentConnection = null;
    }
    if (_disposed || generation != _generation) return false;
    _notify();
    // Once authenticated, show the home screen even if its first refresh lost
    // the connection. The monitor and visible reconnect banner handle recovery.
    return success;
  }

  Future<void> _loadTimers(ServerConnection connection, int generation) async {
    final timers = PlayerTimerService(
      command: (command) {
        _checkConnectionGeneration(generation);
        return sendCommand(command);
      },
      onNotice: (message) {
        if (!_disposed && generation == _generation) {
          _noticeController.add(message);
        }
      },
      onError: (error) {
        if (!_disposed && generation == _generation) {
          _timerError = error;
          _notify();
        }
      },
    );
    try {
      await timers.load(
        '${connection.host.trim().toLowerCase()}:${connection.port}',
      );
      if (_disposed || generation != _generation) return;
      _timers = timers;
      _timerError = null;
    } catch (error) {
      if (generation == _generation) {
        _timerError = 'Could not load saved timers: $error';
      }
    }
  }

  Future<bool> _ensureConnected() async {
    if (_connecting != null) return _connecting!;
    if (isConnected) return true;
    final connection = _currentConnection;
    if (connection == null || _disposed) return false;
    final generation = _generation;
    _isConnecting = true;
    _notify();
    final attempt = () async {
      try {
        final success = await _client.connect(
          connection.host,
          connection.port,
          connection.password,
        );
        if (_disposed || generation != _generation) return false;
        if (!success) {
          _lastError =
              '${_client.lastError ?? 'Could not connect to the RCON server.'}';
          return false;
        }
        _lastError = null;
        _lastHealthy = DateTime.now();
        return true;
      } catch (error) {
        if (generation == _generation) _lastError = 'Connection failed: $error';
        return false;
      } finally {
        if (generation == _generation) {
          _isConnecting = false;
          _notify();
        }
      }
    }();
    _connecting = attempt;
    try {
      return await attempt;
    } finally {
      if (identical(_connecting, attempt)) _connecting = null;
    }
  }

  Future<void> disconnect() async {
    _generation++;
    _monitor?.cancel();
    _monitor = null;
    _currentConnection = null;
    _players = [];
    _timers?.suspend();
    _timers = null;
    _timerError = null;
    _lastHealthy = null;
    _lastError = null;
    _isConnecting = false;
    _connecting = null;
    _refreshing = null;
    await _client.disconnect();
    _notify();
  }

  /// Verify idle sockets before a mutation; only the harmless probe is retried.
  Future<void> _readyForCommand() async {
    final generation = _generation;
    if (!await _ensureConnected()) {
      throw RconCommandException(_lastError ?? 'Not connected to a server.');
    }
    _checkConnectionGeneration(generation);
    if (_lastHealthy == null ||
        DateTime.now().difference(_lastHealthy!) > const Duration(seconds: 5)) {
      try {
        await _client.sendCommand('list');
        _checkConnectionGeneration(generation);
        _lastHealthy = DateTime.now();
      } catch (_) {
        _checkConnectionGeneration(generation);
        await _client.disconnect();
        _checkConnectionGeneration(generation);
        if (!await _ensureConnected()) {
          throw RconCommandException(_lastError ?? 'Unable to reconnect.');
        }
        _checkConnectionGeneration(generation);
      }
    }
  }

  void _checkConnectionGeneration(int generation) {
    if (_disposed || generation != _generation) {
      throw const RconCommandException(
        'The server connection changed. Try again.',
      );
    }
  }

  Future<String> sendCommand(String command) async {
    command = command.trim();
    if (command.startsWith('/')) command = command.substring(1);
    if (command.isEmpty || command.contains(RegExp(r'[\r\n\x00]'))) {
      throw const RconCommandException('Enter one non-empty command.');
    }
    final generation = _generation;
    await _readyForCommand();
    if (_disposed || generation != _generation) {
      throw const RconCommandException(
        'The server connection changed. Try again.',
      );
    }
    _commandHistory.insert(0, command);
    if (_commandHistory.length > 100) _commandHistory.removeLast();
    try {
      final response = await _client.sendCommand(command);
      _checkConnectionGeneration(generation);
      _lastHealthy = DateTime.now();
      _throwIfCommandFailed(response);
      _lastError = null;
      _notify();
      return response;
    } catch (error) {
      if (_disposed || generation != _generation) {
        throw const RconCommandException(
          'The server connection changed before confirmation. Check the result before retrying.',
        );
      }
      _lastError = isConnected
          ? '$error'
          : 'Connection lost before confirmation. Check the result before retrying. Reconnecting automatically…';
      _notify();
      throw RconCommandException(_lastError!);
    }
  }

  static void _throwIfCommandFailed(String response) {
    final plain = response.replaceAll(RegExp(r'§.'), '').trim();
    if (RegExp(
          r'^(Unknown or incomplete command|Unknown command|Incorrect argument|Invalid |Expected |No player was found|No entity was found|No players were found|No entities were found|Only players|Player not found|That player does not exist|You do not have permission|You don.t have permission|Failed to |Error:|Cannot |Can.t |Not a valid|Unable to |Nothing changed|No items were found|No matching elements|Found no elements)',
          caseSensitive: false,
        ).hasMatch(plain) ||
        plain.contains('<--[HERE]')) {
      throw RconCommandException(plain);
    }
  }

  Future<void> refreshPlayers() async {
    if (_currentConnection == null || _disposed) return;
    if (_refreshing != null) return _refreshing!;
    final refresh = _refreshPlayers();
    _refreshing = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_refreshing, refresh)) _refreshing = null;
    }
  }

  Future<void> _refreshPlayers() async {
    final generation = _generation;
    try {
      if (!await _ensureConnected()) return;
      if (_disposed || generation != _generation) return;
      final response = await _client.sendCommand('list');
      if (_disposed || generation != _generation) return;
      _throwIfCommandFailed(response);
      _players = parsePlayerList(response);
      _lastHealthy = DateTime.now();
      _lastError = null;
      if (_timers == null) {
        await _loadTimers(_currentConnection!, generation);
      }
      if (_disposed || generation != _generation) return;
      if (_timers != null) _timerError = null;
      await _timers?.observePlayers(
        _players.where((p) => !p.isBot).map((p) => p.name).toList(),
      );
    } catch (error) {
      if (generation == _generation) {
        _timers?.suspend();
        _lastError =
            'Could not refresh players or timers: $error. Retrying automatically…';
      }
    } finally {
      if (generation == _generation) _notify();
    }
  }

  static List<Player> parsePlayerList(String response) {
    final plain = response.replaceAll(RegExp(r'§.'), '').trim();
    final colon = plain.indexOf(':');
    if (colon < 0) throw FormatException('Unrecognized player list: $plain');
    return plain
        .substring(colon + 1)
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((name) {
          final bot = RegExp(r'^\[Bot\]([A-Za-z0-9_]{1,16})$').firstMatch(name);
          return Player(name: name, botOwner: bot?.group(1));
        })
        .toList();
  }

  String _playerArgument(String name) {
    if (!RegExp(r'^(?:\[Bot\])?[A-Za-z0-9_]{1,16}$').hasMatch(name)) {
      throw const RconCommandException('Invalid player name.');
    }
    return name.startsWith('[Bot]') ? '@a[name="$name",limit=1]' : name;
  }

  Future<String> _timerAction(
    Future<String> Function(PlayerTimerService) action,
  ) async {
    final timers = _timers;
    if (timers == null) {
      throw RconCommandException(
        _timerError ?? 'Player timers are still loading.',
      );
    }
    final generation = _generation;
    try {
      final message = await action(timers);
      _checkConnectionGeneration(generation);
      _timerError = null;
      _notify();
      await refreshPlayers();
      return message;
    } catch (error) {
      if (!_disposed && generation == _generation) {
        _timerError = '$error';
        _notify();
      }
      rethrow;
    }
  }

  Future<String> setPlayPolicy(
    String player,
    int playMinutes,
    int breakMinutes,
  ) => _timerAction(
    (timers) => timers.setPolicy(player, playMinutes, breakMinutes),
  );

  Future<String> disablePlayPolicy(String player) =>
      _timerAction((timers) => timers.disablePolicy(player));

  Future<String> releasePlayer(String player) =>
      _timerAction((timers) => timers.release(player));

  Future<String> setGameMode(String playerName, GameMode mode) =>
      sendCommand('gamemode ${mode.command} ${_playerArgument(playerName)}');
  Future<String> teleportPlayerTo(String from, String to) =>
      sendCommand('tp ${_playerArgument(from)} ${_playerArgument(to)}');
  Future<String> giveInvincibility(
    String playerName,
    int seconds,
  ) => sendCommand(
    'effect give ${_playerArgument(playerName)} minecraft:resistance $seconds 255',
  );
  Future<String> healPlayer(String playerName) => sendCommand(
    'effect give ${_playerArgument(playerName)} minecraft:instant_health 1 10',
  );
  Future<String> feedPlayer(String playerName) => sendCommand(
    'effect give ${_playerArgument(playerName)} minecraft:saturation 1 20',
  );
  Future<String> clearEffects(String playerName) =>
      sendCommand('effect clear ${_playerArgument(playerName)}');
  Future<String> setTime(String time) => sendCommand('time set $time');
  Future<String> setWeather(String weather) => sendCommand('weather $weather');

  Future<String> giveItem(String playerName, String item, int amount) {
    _validateItem(item, amount);
    return sendCommand('give ${_playerArgument(playerName)} $item $amount');
  }

  Future<String> kickPlayer(
    String playerName,
    String reason, {
    int lockoutMinutes = 0,
  }) async {
    _playerArgument(playerName);
    final bot = RegExp(r'^\[Bot\]([A-Za-z0-9_]{1,16})$').firstMatch(playerName);
    if (bot != null) {
      await sendCommand('assistant ${bot.group(1)} dismiss');
      // Older mod sends feedback to the owner, so confirm the actor disappeared.
      final response = await sendCommand('list');
      _players = parsePlayerList(response);
      _notify();
      if (_players.any((p) => p.name == playerName)) {
        throw const RconCommandException(
          'Bot is still present. Its owner must be online for the assistant mod to dismiss it.',
        );
      }
      return 'Dismissed $playerName';
    }
    if (lockoutMinutes < 0 || lockoutMinutes > 1440) {
      throw const RconCommandException(
        'Use a lockout between 0 and 1440 minutes.',
      );
    }
    if (lockoutMinutes > 0) {
      return _timerAction(
        (timers) => timers.kick(playerName, reason, lockoutMinutes),
      );
    }
    final response = await sendCommand('kick $playerName ${reason.trim()}');
    await refreshPlayers();
    return response;
  }

  Future<String> messagePlayer(String playerName, String message) =>
      sendCommand('tell ${_playerArgument(playerName)} $message');
  Future<String> setSpawnPoint(String playerName) => sendCommand(
    'execute at ${_playerArgument(playerName)} run spawnpoint ${_playerArgument(playerName)} ~ ~ ~',
  );
  Future<String> killPlayer(String playerName) =>
      sendCommand('kill ${_playerArgument(playerName)}');
  Future<String> clearInventory(String playerName) =>
      sendCommand('clear ${_playerArgument(playerName)}');

  Future<List<Map<String, dynamic>>> getPlayerInventory(
    String playerName,
  ) async => InventoryParser.parse(
    await sendCommand(
      'data get entity ${_playerArgument(playerName)} Inventory',
    ),
  );

  static String inventorySlot(int slot) => switch (slot) {
    >= 0 && <= 35 => 'container.$slot',
    100 => 'armor.feet',
    101 => 'armor.legs',
    102 => 'armor.chest',
    103 => 'armor.head',
    -106 => 'weapon.offhand',
    _ => throw const RconCommandException('Unsupported inventory slot.'),
  };

  void _validateItem(String item, int amount) {
    if (!RegExp(r'^(?:[a-z0-9_.-]+:)?[a-z0-9_./-]+$').hasMatch(item)) {
      throw const RconCommandException(
        'Enter a valid item ID, such as minecraft:stone.',
      );
    }
    if (amount < 1 || amount > 2304) {
      throw const RconCommandException('Use an item count between 1 and 2304.');
    }
  }

  Future<String> removeItem(String playerName, int slot) => sendCommand(
    'item replace entity ${_playerArgument(playerName)} ${inventorySlot(slot)} with minecraft:air',
  );
  Future<String> setItem(
    String playerName,
    int slot,
    String itemId,
    int amount,
  ) {
    _validateItem(itemId, amount);
    return sendCommand(
      'item replace entity ${_playerArgument(playerName)} ${inventorySlot(slot)} with $itemId $amount',
    );
  }

  Future<String> giveXp(String playerName, int amount) =>
      sendCommand('xp add ${_playerArgument(playerName)} $amount points');
  Future<String> setXpLevel(String playerName, int level) =>
      sendCommand('xp set ${_playerArgument(playerName)} $level levels');

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _monitor?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _connectionSubscription.cancel();
    _timers?.suspend();
    _noticeController.close();
    _client.dispose();
    super.dispose();
  }
}
