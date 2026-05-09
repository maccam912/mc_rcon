class Player {
  final String name;
  final String? uuid;

  Player({
    required this.name,
    this.uuid,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Player && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

enum GameMode {
  survival('survival', 'Survival', 'Default survival mode'),
  creative('creative', 'Creative', 'Unlimited resources and flying'),
  adventure('adventure', 'Adventure', 'Cannot break or place blocks'),
  spectator('spectator', 'Spectator', 'Invisible, can fly through blocks');

  const GameMode(this.command, this.displayName, this.description);
  final String command;
  final String displayName;
  final String description;
}
