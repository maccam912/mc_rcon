import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/player.dart';
import '../models/server_connection.dart';
import '../services/rcon_client.dart';
import '../services/storage_service.dart';

class RconProvider extends ChangeNotifier {
  final RconClient _client = RconClient();
  final StorageService _storage = StorageService();

  List<ServerConnection> _savedConnections = [];
  ServerConnection? _currentConnection;
  List<Player> _players = [];
  List<String> _commandHistory = [];
  bool _isConnecting = false;
  String? _lastError;

  // Getters
  List<ServerConnection> get savedConnections => _savedConnections;
  ServerConnection? get currentConnection => _currentConnection;
  List<Player> get players => _players;
  List<String> get commandHistory => _commandHistory;
  bool get isConnected => _client.isConnected;
  bool get isConnecting => _isConnecting;
  String? get lastError => _lastError;
  Stream<String> get responseStream => _client.responseStream;
  Stream<bool> get connectionStream => _client.connectionStream;

  RconProvider() {
    _init();
    _client.connectionStream.listen((connected) {
      notifyListeners();
    });
  }

  Future<void> _init() async {
    await loadSavedConnections();
  }

  Future<void> loadSavedConnections() async {
    _savedConnections = await _storage.getConnections();
    notifyListeners();
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
    _isConnecting = true;
    _lastError = null;
    notifyListeners();

    try {
      final success = await _client.connect(
        connection.host,
        connection.port,
        connection.password,
      );

      if (success) {
        _currentConnection = connection;
        await _storage.setLastConnectionId(connection.id);
        await refreshPlayers();
      } else {
        _lastError = 'Failed to authenticate. Check your password.';
      }

      _isConnecting = false;
      notifyListeners();
      return success;
    } catch (e) {
      _lastError = 'Connection failed: ${e.toString()}';
      _isConnecting = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    await _client.disconnect();
    _currentConnection = null;
    _players = [];
    notifyListeners();
  }

  Future<String> sendCommand(String command) async {
    if (!isConnected) {
      throw Exception('Not connected');
    }

    _commandHistory.insert(0, command);
    if (_commandHistory.length > 100) {
      _commandHistory = _commandHistory.sublist(0, 100);
    }

    final response = await _client.sendCommand(command);
    notifyListeners();
    return response;
  }

  Future<void> refreshPlayers() async {
    if (!isConnected) return;

    try {
      final response = await _client.sendCommand('list');
      _players = _parsePlayerList(response);
      notifyListeners();
    } catch (e) {
      // Silent fail for player refresh
    }
  }

  List<Player> _parsePlayerList(String response) {
    // Response format: "There are X of a max of Y players online: player1, player2, player3"
    // Or: "There are 0 of a max of Y players online:"
    final players = <Player>[];

    final colonIndex = response.indexOf(':');
    if (colonIndex == -1 || colonIndex == response.length - 1) {
      return players;
    }

    final playerPart = response.substring(colonIndex + 1).trim();
    if (playerPart.isEmpty) {
      return players;
    }

    final names = playerPart
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    for (final name in names) {
      players.add(Player(name: name));
    }

    return players;
  }

  // Quick commands for dad admin
  Future<String> setGameMode(String playerName, GameMode mode) async {
    return sendCommand('gamemode ${mode.command} $playerName');
  }

  Future<String> teleportPlayerTo(String from, String to) async {
    return sendCommand('tp $from $to');
  }

  Future<String> giveInvincibility(String playerName, int seconds) async {
    // Resistance 255 makes the player invulnerable
    return sendCommand(
      'effect give $playerName minecraft:resistance $seconds 255',
    );
  }

  Future<String> healPlayer(String playerName) async {
    // Instant health effect
    return sendCommand('effect give $playerName minecraft:instant_health 1 10');
  }

  Future<String> feedPlayer(String playerName) async {
    // Saturation effect for instant food
    return sendCommand('effect give $playerName minecraft:saturation 1 20');
  }

  Future<String> clearEffects(String playerName) async {
    return sendCommand('effect clear $playerName');
  }

  Future<String> setTime(String time) async {
    // time can be: day, night, noon, midnight, or a number
    return sendCommand('time set $time');
  }

  Future<String> setWeather(String weather) async {
    // weather can be: clear, rain, thunder
    return sendCommand('weather $weather');
  }

  Future<String> giveItem(String playerName, String item, int amount) async {
    return sendCommand('give $playerName $item $amount');
  }

  Future<String> kickPlayer(String playerName, String reason) async {
    return sendCommand('kick $playerName $reason');
  }

  Future<String> messagePlayer(String playerName, String message) async {
    return sendCommand('tell $playerName $message');
  }

  Future<String> broadcastMessage(String message) async {
    return sendCommand('say $message');
  }

  Future<String> setSpawnPoint(String playerName) async {
    return sendCommand('spawnpoint $playerName ~ ~ ~');
  }

  Future<String> killPlayer(String playerName) async {
    return sendCommand('kill $playerName');
  }

  Future<String> clearInventory(String playerName) async {
    return sendCommand('clear $playerName');
  }

  Future<List<Map<String, dynamic>>> getPlayerInventory(
    String playerName,
  ) async {
    final response = await sendCommand('data get entity $playerName Inventory');
    return _parseInventoryResponse(response);
  }

  List<Map<String, dynamic>> _parseInventoryResponse(String response) {
    // Response format: "PlayerName has the following entity data: [{Slot: 0b, id: "minecraft:stone", count: 64b}, ...]"
    try {
      final startIndex = response.indexOf('[');
      if (startIndex == -1) return [];

      String snbt = response.substring(startIndex);

      // Basic SNBT to JSON conversion for simple inventory items
      // 1. Remove type suffixes: 0b, 10s, 100L, 1.0f, 1.0d
      snbt = snbt.replaceAllMapped(RegExp(r'(\d+)[bsL]'), (m) => m.group(1)!);
      snbt = snbt.replaceAllMapped(
        RegExp(r'(\d+\.\d+)[fd]'),
        (m) => m.group(1)!,
      );

      // 2. Ensure keys are quoted
      snbt = snbt.replaceAllMapped(
        RegExp(r'([{,]\s*)([a-zA-Z0-9_]+)\s*:'),
        (m) => '${m.group(1)}"${m.group(2)}":',
      );

      final decoded = jsonDecode(snbt);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      }
    } catch (e) {
      developer.log('Error parsing inventory response', error: e);
    }
    return [];
  }

  Future<String> removeItem(String playerName, int slot) async {
    // In modern Minecraft, we can use /item replace
    return sendCommand(
      'item replace entity $playerName container.$slot with minecraft:air',
    );
  }

  Future<String> setItem(
    String playerName,
    int slot,
    String itemId,
    int amount,
  ) async {
    return sendCommand(
      'item replace entity $playerName container.$slot with $itemId $amount',
    );
  }

  Future<String> giveXp(String playerName, int amount) async {
    return sendCommand('xp add $playerName $amount points');
  }

  Future<String> setXpLevel(String playerName, int level) async {
    return sendCommand('xp set $playerName $level levels');
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }
}
