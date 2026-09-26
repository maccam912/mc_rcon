class PlayerTimerStatus {
  final String name;
  final String? uuid;
  final bool online;
  final bool enabled;
  final int playedSeconds;
  final int playSeconds;
  final int breakSeconds;
  final DateTime? blockedUntil;

  const PlayerTimerStatus({
    required this.name,
    this.uuid,
    required this.online,
    required this.enabled,
    required this.playedSeconds,
    required this.playSeconds,
    required this.breakSeconds,
    this.blockedUntil,
  });

  factory PlayerTimerStatus.fromJson(Map<String, dynamic> json) {
    final until = json['blockedUntil'] as num?;
    return PlayerTimerStatus(
      name: json['name'] as String,
      uuid: json['uuid'] as String?,
      online: json['online'] == true,
      enabled: json['enabled'] == true,
      playedSeconds: (json['playedSeconds'] as num?)?.toInt() ?? 0,
      playSeconds: (json['playSeconds'] as num?)?.toInt() ?? 3600,
      breakSeconds: (json['breakSeconds'] as num?)?.toInt() ?? 120,
      blockedUntil: until == null || until <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(until.toInt()),
    );
  }

  Duration get remainingBreak {
    final remaining = blockedUntil?.difference(DateTime.now()) ?? Duration.zero;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

String formatPlayDuration(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m ${seconds % 60}s';
  return '${minutes ~/ 60}h ${minutes % 60}m';
}
