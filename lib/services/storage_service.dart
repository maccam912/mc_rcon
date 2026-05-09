import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_connection.dart';

class StorageService {
  static const String _connectionsKey = 'server_connections';
  static const String _lastConnectionKey = 'last_connection_id';

  Future<List<ServerConnection>> getConnections() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_connectionsKey);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList
        .map((json) => ServerConnection.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveConnection(ServerConnection connection) async {
    final connections = await getConnections();
    final existingIndex = connections.indexWhere((c) => c.id == connection.id);

    if (existingIndex >= 0) {
      connections[existingIndex] = connection;
    } else {
      connections.add(connection);
    }

    await _saveConnections(connections);
  }

  Future<void> deleteConnection(String id) async {
    final connections = await getConnections();
    connections.removeWhere((c) => c.id == id);
    await _saveConnections(connections);
  }

  Future<void> _saveConnections(List<ServerConnection> connections) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(connections.map((c) => c.toJson()).toList());
    await prefs.setString(_connectionsKey, jsonString);
  }

  Future<void> setLastConnectionId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastConnectionKey, id);
  }

  Future<String?> getLastConnectionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastConnectionKey);
  }

  Future<ServerConnection?> getLastConnection() async {
    final lastId = await getLastConnectionId();
    if (lastId == null) return null;

    final connections = await getConnections();
    try {
      return connections.firstWhere((c) => c.id == lastId);
    } catch (e) {
      return null;
    }
  }
}
