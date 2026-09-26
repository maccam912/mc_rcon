import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_admin_status.dart';

typedef TimerStateReader = Future<String?> Function(String key);
typedef TimerStateWriter = Future<void> Function(String key, String value);

/// App-owned play counters and temporary bans. A ban is released only while its
/// unique marker still appears in the server's ban list, never by name alone.
class PlayerTimerService {
  final Future<String> Function(String command) _command;
  final DateTime Function() _clock;
  final TimerStateReader _readState;
  final TimerStateWriter _writeState;
  final void Function(String message)? onNotice;
  final void Function(String message)? onError;
  final Map<String, _TimerEntry> _entries = {};
  Future<void> _queue = Future<void>.value();
  String? _storageKey;
  DateTime? _lastObserved;
  Set<String> _online = {};

  PlayerTimerService({
    required Future<String> Function(String command) command,
    DateTime Function()? clock,
    TimerStateReader? readState,
    TimerStateWriter? writeState,
    this.onNotice,
    this.onError,
  }) : _command = command,
       _clock = clock ?? DateTime.now,
       _readState = readState ?? _readPreferences,
       _writeState = writeState ?? _writePreferences;

  static Future<String?> _readPreferences(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  static Future<void> _writePreferences(String key, String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw StateError('Could not save player timers. No new ban was issued.');
    }
  }

  List<PlayerTimerStatus> get status => List.unmodifiable(
    _entries.entries.map(
      (entry) => PlayerTimerStatus(
        name: entry.value.name,
        online: _online.contains(entry.key),
        enabled: entry.value.enabled,
        playedSeconds: entry.value.playedMillis ~/ 1000,
        playSeconds: entry.value.playSeconds,
        breakSeconds: entry.value.breakSeconds,
        // Retain an overdue deadline until its ban was actually removed. The
        // app can show that an unlock is pending after a connection failure.
        blockedUntil: entry.value.blockedUntil,
      ),
    ),
  );

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  /// Use normalized host:port, so editing/duplicating a connection profile does
  /// not lose the release record for a ban on the same server.
  Future<void> load(String serverKey) => _serialized(() async {
    final key =
        'player_timers_v1:${base64Url.encode(utf8.encode(serverKey.toLowerCase()))}';
    final source = await _readState(key);
    final entries = <String, _TimerEntry>{};
    if (source != null) {
      final json = jsonDecode(source) as Map<String, dynamic>;
      if (json['version'] != 1 || json['players'] is! List) {
        throw const FormatException('Unsupported saved player timer data.');
      }
      for (final value in json['players'] as List) {
        final entry = _TimerEntry.fromJson(value as Map<String, dynamic>);
        entries[entry.name.toLowerCase()] = entry;
      }
    }
    _entries
      ..clear()
      ..addAll(entries);
    _storageKey = key;
    suspend();
  });

  /// Call when disconnected or suspended. Offline app time is never counted.
  void suspend() {
    _lastObserved = null;
    _online = {};
  }

  Future<void> _save() async {
    final key = _storageKey;
    if (key == null) {
      throw StateError('Player timers have not loaded a server.');
    }
    await _writeState(
      key,
      jsonEncode({
        'version': 1,
        'players': _entries.values.map((e) => e.toJson()).toList(),
      }),
    );
  }

  _TimerEntry _player(String name) {
    if (!RegExp(r'^[A-Za-z0-9_]{1,16}$').hasMatch(name)) {
      throw ArgumentError('Choose a human Minecraft player for play timers.');
    }
    return _entries.putIfAbsent(name.toLowerCase(), () => _TimerEntry(name));
  }

  /// Poll with successfully refreshed human player names about every 10 seconds.
  /// Rejoins retain their allowance; missing/long polling gaps never add time.
  Future<void> observePlayers(List<String> names) => _serialized(() async {
    if (_storageKey == null) {
      throw StateError('Player timers have not loaded a server.');
    }
    final now = _clock();
    final online = names
        .where((n) => RegExp(r'^[A-Za-z0-9_]{1,16}$').hasMatch(n))
        .map((n) => n.toLowerCase())
        .toSet();
    for (final name in names) {
      if (online.contains(name.toLowerCase())) _player(name).name = name;
    }
    final previous = _lastObserved;
    final gap = previous == null ? Duration.zero : now.difference(previous);
    if (previous != null &&
        !gap.isNegative &&
        gap <= const Duration(seconds: 30)) {
      for (final key in online.intersection(_online)) {
        final entry = _entries[key]!;
        if (entry.blockedUntil != null) continue;
        final after = entry.countAfter;
        final start = after != null && after.isAfter(previous)
            ? after
            : previous;
        final elapsed = now.difference(start).inMilliseconds;
        if (elapsed > 0) entry.playedMillis += elapsed;
      }
    }
    _online = online;
    _lastObserved = now;
    // Process expired records before automatic breaks, including players who
    // cannot appear in list because their temporary ban is still active.
    for (final entry in _entries.values.toList()) {
      if (entry.blockedUntil == null) continue;
      try {
        await _reconcile(entry, now);
      } catch (error) {
        onError?.call('Could not check/release ${entry.name}: $error');
      }
    }
    // Release existing bans even if writing a new counter checkpoint fails.
    await _save();
    for (final key in online) {
      final entry = _entries[key]!;
      if (!entry.enabled ||
          entry.blockedUntil != null ||
          entry.playedMillis < entry.playSeconds * 1000) {
        continue;
      }
      try {
        await _lock(entry, entry.breakSeconds, 'Time for a play break.');
        onNotice?.call(
          '${entry.name} is taking a ${formatPlayDuration(entry.breakSeconds)} break.',
        );
      } catch (error) {
        onError?.call('Could not start ${entry.name}’s play break: $error');
      }
    }
  });

  Future<String> setPolicy(String name, int playMinutes, int breakMinutes) =>
      _serialized(() async {
        _validateMinutes(playMinutes);
        _validateMinutes(breakMinutes);
        final entry = _player(name);
        final before = entry.toJson();
        entry.enabled = true;
        entry.playSeconds = playMinutes * 60;
        entry.breakSeconds = breakMinutes * 60;
        entry.countAfter = _clock();
        try {
          await _save();
        } catch (_) {
          _entries[name.toLowerCase()] = _TimerEntry.fromJson(before);
          rethrow;
        }
        return 'Play breaks enabled for ${entry.name}.';
      });

  Future<String> disablePolicy(String name) => _serialized(() async {
    final entry = _player(name);
    final enabled = entry.enabled;
    entry.enabled = false;
    try {
      await _save();
    } catch (_) {
      entry.enabled = enabled;
      rethrow;
    }
    return 'Automatic play breaks disabled for ${entry.name}. Existing breaks continue.';
  });

  Future<String> kick(
    String name,
    String reason,
    int lockoutMinutes,
  ) => _serialized(() async {
    if (lockoutMinutes < 0 || lockoutMinutes > 1440) {
      throw ArgumentError('Reconnect delay must be 0–1440 minutes.');
    }
    final entry = _player(name);
    if (lockoutMinutes == 0) {
      final response = await _command('kick ${entry.name} ${_reason(reason)}');
      if (!response.trimLeft().startsWith('Kicked ')) {
        throw StateError(
          response.isEmpty ? 'Kick was not confirmed by the server.' : response,
        );
      }
      return response;
    }
    await _lock(entry, lockoutMinutes * 60, reason);
    return '${entry.name} was kicked. Reconnection is blocked until ${entry.blockedUntil!.toLocal()}. Keep this app connected to release the ban.';
  });

  Future<String> release(String name) => _serialized(() async {
    final entry = _player(name);
    if (entry.blockedUntil == null) {
      final before = entry.toJson();
      entry.playedMillis = 0;
      entry.countAfter = _clock();
      try {
        await _save();
      } catch (_) {
        _entries[name.toLowerCase()] = _TimerEntry.fromJson(before);
        rethrow;
      }
      return '${entry.name} has no app-managed reconnect delay. Play timer reset.';
    }
    await _reconcile(entry, _clock(), forceRelease: true);
    return '${entry.name}’s app-managed reconnect delay has ended.';
  });

  static void _validateMinutes(int minutes) {
    if (minutes < 1 || minutes > 1440) {
      throw ArgumentError('Duration must be 1–1440 minutes.');
    }
  }

  static String _reason(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[\r\n\x00]'), ' ')
        .replaceAll(RegExp(r'§.'), '')
        .replaceAll(' was banned by ', ' was banned by: ')
        .trim();
    final reason = cleaned.isEmpty ? 'Take a short break.' : cleaned;
    return reason.length <= 200 ? reason : reason.substring(0, 200);
  }

  static String _newMarker() {
    final random = Random.secure();
    final token = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return '[mc_rcon:$token]';
  }

  Future<void> _lock(_TimerEntry entry, int seconds, String reason) async {
    final bans = await _banList();
    final existing = _lookupBan(bans, entry.name);
    if (existing != null && !_owns(entry, existing)) {
      throw StateError(
        '${entry.name} already has a ban not owned by this timer. It will not be changed or automatically removed.',
      );
    }
    final before = entry.toJson();
    final until = _clock().add(Duration(seconds: seconds));
    if (entry.blockedUntil == null || until.isAfter(entry.blockedUntil!)) {
      entry.blockedUntil = until;
    }
    entry.marker ??= _newMarker();
    entry.pending = existing == null;
    entry.reason = _reason(reason);
    // Durable intent comes first. Even a lost command response can be recovered
    // using the exact marker after an app restart.
    try {
      await _save();
    } catch (_) {
      _entries[entry.name.toLowerCase()] = _TimerEntry.fromJson(before);
      rethrow;
    }
    if (existing == null) await _applyBan(entry);
    entry.pending = false;
    entry.playedMillis = 0;
    await _save();
  }

  Future<void> _applyBan(_TimerEntry entry) async {
    await _command('ban ${entry.name} ${entry.marker} ${entry.reason}');
    final bans = await _banList();
    final actual = _lookupBan(bans, entry.name);
    if (actual == null || !_owns(entry, actual)) {
      throw StateError(
        'The server did not confirm the temporary ban for ${entry.name}.',
      );
    }
  }

  bool _owns(_TimerEntry entry, String reason) =>
      entry.marker != null &&
      (reason.trim() == entry.marker ||
          reason.trimLeft().startsWith('${entry.marker} '));

  Future<void> _reconcile(
    _TimerEntry entry,
    DateTime now, {
    bool forceRelease = false,
  }) async {
    final bans = await _banList();
    final actual = _lookupBan(bans, entry.name);
    final due = forceRelease || !entry.blockedUntil!.isAfter(now);
    if (actual == null) {
      if (!due && entry.pending) {
        // The persisted intent never reached the server (or its response was
        // lost). Preflight still shows no existing ban, so this is safe to retry.
        await _applyBan(entry);
        entry.pending = false;
        entry.playedMillis = 0;
        await _save();
      } else {
        await _clearLock(entry);
      }
      return;
    }
    if (!_owns(entry, actual)) {
      await _clearLock(entry);
      throw StateError(
        '${entry.name}’s ban was changed by another administrator. It was not removed.',
      );
    }
    if (!due) {
      if (entry.pending) {
        entry.pending = false;
        entry.playedMillis = 0;
        await _save();
      }
      return;
    }
    await _command('pardon ${entry.name}');
    final remaining = _lookupBan(await _banList(), entry.name);
    if (remaining != null) {
      throw StateError(
        'The server has not confirmed release of ${entry.name}. It will be checked again.',
      );
    }
    await _clearLock(entry);
    onNotice?.call('${entry.name}’s break is over; they may reconnect.');
  }

  Future<void> _clearLock(_TimerEntry entry) async {
    final before = entry.toJson();
    entry.blockedUntil = null;
    entry.marker = null;
    entry.pending = false;
    entry.playedMillis = 0;
    entry.countAfter = _clock();
    try {
      await _save();
    } catch (_) {
      _entries[entry.name.toLowerCase()] = _TimerEntry.fromJson(before);
      rethrow;
    }
  }

  // RCON concatenates ban-list messages. A preceding reason ending in letters
  // can become part of the next parsed name, e.g. "griefingAlex". Match the
  // tracked target as a suffix, conservatively treating "BigAlex" as a possible
  // Alex ban too. Multiple candidates are ambiguous: retain the release record
  // and require operator attention instead of dropping a possibly active ban.
  static String? _lookupBan(Map<String, String> bans, String player) {
    final target = player.toLowerCase();
    final candidates = bans.entries
        .where((e) => e.key.endsWith(target))
        .toList();
    if (candidates.length > 1) {
      throw FormatException(
        'Ambiguous ban entries for $player. The release record was kept; no ban was changed.',
      );
    }
    return candidates.isEmpty ? null : candidates.single.value;
  }

  Future<Map<String, String>> _banList() async =>
      parseBanList(await _command('banlist players'));

  /// Vanilla RCON can concatenate individual messages without newlines. Validate
  /// the announced count so unfamiliar/localized/plugin output fails closed.
  static Map<String, String> parseBanList(String response) {
    final text = response.replaceAll(RegExp(r'§.'), '').trim();
    if (text == 'There are no bans' || text == 'There are no bans.') return {};
    final header = RegExp(
      r'^There are (\d+) ban(?:\(s\)|s)\s*:\s*',
    ).firstMatch(text);
    if (header == null) {
      throw const FormatException(
        'Could not verify the server ban list. No bans will be changed.',
      );
    }
    final body = text.substring(header.end);
    final starts = RegExp(
      r'([A-Za-z0-9_]{1,16}) was banned by [^:\r\n]+:\s*',
    ).allMatches(body).toList();
    if (starts.length != int.parse(header.group(1)!) ||
        (starts.isNotEmpty && starts.first.start != 0)) {
      throw const FormatException(
        'Incomplete ban list; refusing to change bans.',
      );
    }
    final bans = <String, String>{};
    for (var i = 0; i < starts.length; i++) {
      final end = i + 1 < starts.length ? starts[i + 1].start : body.length;
      final name = starts[i].group(1)!.toLowerCase();
      if (bans.containsKey(name)) {
        throw const FormatException('Ambiguous ban list.');
      }
      bans[name] = body.substring(starts[i].end, end).trim();
    }
    return bans;
  }
}

class _TimerEntry {
  String name;
  bool enabled = false;
  int playedMillis = 0;
  int playSeconds = 3600;
  int breakSeconds = 120;
  DateTime? blockedUntil;
  String? marker;
  bool pending = false;
  String reason = 'Take a short break.';
  DateTime? countAfter;

  _TimerEntry(this.name);

  Map<String, dynamic> toJson() => {
    'name': name,
    'enabled': enabled,
    'playedMillis': playedMillis,
    'playSeconds': playSeconds,
    'breakSeconds': breakSeconds,
    'blockedUntil': blockedUntil?.millisecondsSinceEpoch,
    'marker': marker,
    'pending': pending,
    'reason': reason,
  };

  factory _TimerEntry.fromJson(Map<String, dynamic> json) {
    final entry = _TimerEntry(json['name'] as String)
      ..enabled = json['enabled'] as bool
      ..playedMillis = json['playedMillis'] as int
      ..playSeconds = json['playSeconds'] as int
      ..breakSeconds = json['breakSeconds'] as int
      ..marker = json['marker'] as String?
      ..pending = json['pending'] as bool
      ..reason = json['reason'] as String;
    final until = json['blockedUntil'] as int?;
    if (until != null) {
      entry.blockedUntil = DateTime.fromMillisecondsSinceEpoch(until);
    }
    if (!RegExp(r'^[A-Za-z0-9_]{1,16}$').hasMatch(entry.name) ||
        entry.playedMillis < 0 ||
        entry.playSeconds < 60 ||
        entry.playSeconds > 86400 ||
        entry.breakSeconds < 60 ||
        entry.breakSeconds > 86400 ||
        ((entry.blockedUntil == null) != (entry.marker == null)) ||
        (entry.marker != null &&
            !RegExp(r'^\[mc_rcon:[0-9a-f]{32}\]$').hasMatch(entry.marker!))) {
      throw const FormatException(
        'Invalid saved player timer; original data was preserved.',
      );
    }
    return entry;
  }
}
