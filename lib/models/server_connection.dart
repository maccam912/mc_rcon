import 'dart:convert';

class ServerConnection {
  final String id;
  final String name;
  final String host;
  final int port;
  final String password;

  ServerConnection({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.password,
  });

  ServerConnection copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? password,
  }) {
    return ServerConnection(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'password': password,
    };
  }

  factory ServerConnection.fromJson(Map<String, dynamic> json) {
    return ServerConnection(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      password: json['password'] as String,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ServerConnection.fromJsonString(String jsonString) {
    return ServerConnection.fromJson(jsonDecode(jsonString));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServerConnection && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
