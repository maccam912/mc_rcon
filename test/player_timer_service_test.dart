import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_rcon/services/player_timer_service.dart';

class _Fixture {
  DateTime now = DateTime.utc(2026, 9, 26);
  final saved = <String, String>{};
  final bans = <String, String>{};
  final commands = <String>[];
  final errors = <String>[];
  final notices = <String>[];
  bool loseNextBanReply = false;
  bool loseNextPardonReply = false;
  bool failWrites = false;
  bool failPardons = false;
  bool concatenateBans = false;

  PlayerTimerService service() => PlayerTimerService(
    command: command,
    clock: () => now,
    readState: (key) async => saved[key],
    writeState: (key, value) async {
      if (failWrites) throw StateError('Disk unavailable');
      saved[key] = value;
    },
    onNotice: notices.add,
    onError: errors.add,
  );

  Future<String> command(String command) async {
    commands.add(command);
    if (command == 'banlist players') {
      if (bans.isEmpty) return 'There are no bans';
      return 'There are ${bans.length} ban(s):\n${bans.entries.map((e) => '${e.key} was banned by Rcon: ${e.value}').join(concatenateBans ? '' : '\n')}';
    }
    if (command.startsWith('ban ')) {
      final match = RegExp(r'^ban (\w+) (.+)$').firstMatch(command)!;
      final name = match.group(1)!;
      if (bans.containsKey(name)) {
        return 'Nothing changed. That player is already banned';
      }
      bans[name] = match.group(2)!;
      if (loseNextBanReply) {
        loseNextBanReply = false;
        throw TimeoutException('Ban reply lost');
      }
      return 'Banned $name: ${bans[name]}';
    }
    if (command.startsWith('pardon ')) {
      if (failPardons) throw TimeoutException('Server unavailable');
      final name = command.substring(7);
      bans.remove(name);
      if (loseNextPardonReply) {
        loseNextPardonReply = false;
        throw TimeoutException('Pardon reply lost');
      }
      return 'Unbanned $name';
    }
    if (command.startsWith('kick ')) return 'Kicked ${command.substring(5)}';
    throw StateError('Unexpected command: $command');
  }

  void advance(int seconds) => now = now.add(Duration(seconds: seconds));
}

void main() {
  test(
    'manual lockout persists before ban and releases after expiry',
    () async {
      final f = _Fixture();
      final service = f.service();
      await service.load('example:25575');
      await service.kick('Alice', 'Break time', 5);
      expect(f.bans['Alice'], contains('[mc_rcon:'));
      expect(
        service.status.single.blockedUntil,
        f.now.add(const Duration(minutes: 5)),
      );
      f.advance(299);
      await service.observePlayers([]);
      expect(f.bans, contains('Alice'));
      f.advance(1);
      await service.observePlayers([]);
      expect(f.bans, isEmpty);
      expect(service.status.single.blockedUntil, isNull);
    },
  );

  test('existing foreign bans are never changed or pardoned', () async {
    final f = _Fixture()..bans['Alice'] = 'Existing administrator ban';
    final service = f.service();
    await service.load('example:25575');
    await expectLater(service.kick('Alice', 'Break', 5), throwsStateError);
    await service.release('Alice');
    expect(
      f.commands.where((c) => c.startsWith('ban ') || c.startsWith('pardon ')),
      isEmpty,
    );
    expect(f.bans['Alice'], 'Existing administrator ban');
  });

  test('a replaced ban is not released after the original deadline', () async {
    final f = _Fixture();
    final service = f.service();
    await service.load('example:25575');
    await service.kick('Alice', 'Break', 1);
    f.bans['Alice'] = 'Different administrator ban';
    f.advance(61);
    await service.observePlayers([]);
    expect(f.bans['Alice'], 'Different administrator ban');
    expect(f.commands.where((c) => c.startsWith('pardon ')), isEmpty);
    expect(f.errors.single, contains('not removed'));
  });

  test(
    'lost ban response is recovered after restarting without duplicate ban',
    () async {
      final f = _Fixture()..loseNextBanReply = true;
      final service = f.service();
      await service.load('example:25575');
      await expectLater(
        service.kick('Alice', 'Break', 1),
        throwsA(isA<TimeoutException>()),
      );
      expect(f.bans, contains('Alice'));
      final restored = f.service();
      await restored.load('EXAMPLE:25575');
      await restored.observePlayers([]);
      expect(f.commands.where((c) => c.startsWith('ban ')).length, 1);
      f.advance(60);
      await restored.observePlayers([]);
      expect(f.bans, isEmpty);
    },
  );

  test('overdue releases catch up after restart', () async {
    final f = _Fixture();
    final service = f.service();
    await service.load('example:25575');
    await service.kick('Alice', 'Break', 1);
    f.advance(3600);
    final restored = f.service();
    await restored.load('example:25575');
    await restored.observePlayers([]);
    expect(f.bans, isEmpty);
    expect(restored.status.single.blockedUntil, isNull);
  });

  test(
    'lost pardon reply leaves recoverable record and never pardons twice',
    () async {
      final f = _Fixture();
      final service = f.service();
      await service.load('example:25575');
      await service.kick('Alice', 'Break', 1);
      f.advance(60);
      f.loseNextPardonReply = true;
      await service.observePlayers([]);
      expect(f.bans, isEmpty);
      expect(service.status.single.blockedUntil, isNotNull);
      await service.observePlayers([]);
      expect(service.status.single.blockedUntil, isNull);
      expect(f.commands.where((c) => c.startsWith('pardon ')).length, 1);
    },
  );

  test(
    'failed releases keep their deadline and retry on later polls',
    () async {
      final f = _Fixture();
      final service = f.service();
      await service.load('example:25575');
      await service.kick('Alice', 'Break', 1);
      f.advance(60);
      f.failPardons = true;
      await service.observePlayers([]);
      expect(service.status.single.blockedUntil, isNotNull);
      expect(f.bans, contains('Alice'));
      f.failPardons = false;
      await service.observePlayers([]);
      expect(f.bans, isEmpty);
    },
  );

  test(
    'only selected player reaches automatic break; reconnects do not reset',
    () async {
      final f = _Fixture();
      final service = f.service();
      await service.load('example:25575');
      await service.observePlayers(['Alice', 'Bob', '[Bot]Alice']);
      await service.setPolicy('Alice', 1, 2);
      for (var i = 0; i < 3; i++) {
        f.advance(10);
        await service.observePlayers(['Alice', 'Bob']);
      }
      await service.observePlayers(['Bob']);
      f.advance(10);
      await service.observePlayers(['Bob']);
      await service.observePlayers(['Alice', 'Bob']);
      for (var i = 0; i < 3; i++) {
        f.advance(10);
        await service.observePlayers(['Alice', 'Bob']);
      }
      expect(f.bans.keys, ['Alice']);
      expect(service.status.map((s) => s.name), ['Alice', 'Bob']);
      expect(service.status.first.playedSeconds, 0);
      expect(service.status.first.breakSeconds, 120);
    },
  );

  test(
    'long polling gaps and explicit suspension do not count offline app time',
    () async {
      final f = _Fixture();
      final service = f.service();
      await service.load('example:25575');
      await service.observePlayers(['Alice']);
      await service.setPolicy('Alice', 1, 2);
      f.advance(3600);
      await service.observePlayers(['Alice']);
      expect(service.status.single.playedSeconds, 0);
      service.suspend();
      f.advance(10);
      await service.observePlayers(['Alice']);
      expect(service.status.single.playedSeconds, 0);
      f.advance(10);
      await service.observePlayers(['Alice']);
      expect(service.status.single.playedSeconds, 10);
    },
  );

  test('elapsed play survives restart without counting downtime', () async {
    final f = _Fixture();
    final service = f.service();
    await service.load('example:25575');
    await service.observePlayers(['Alice']);
    await service.setPolicy('Alice', 1, 2);
    f.advance(30);
    await service.observePlayers(['Alice']);
    final restored = f.service();
    f.advance(1000);
    await restored.load('example:25575');
    await restored.observePlayers(['Alice']);
    expect(restored.status.single.playedSeconds, 30);
    f.advance(30);
    await restored.observePlayers(['Alice']);
    expect(f.bans, contains('Alice'));
  });

  test('disable preserves cooldown while release preserves policy', () async {
    final f = _Fixture();
    final service = f.service();
    await service.load('example:25575');
    await service.setPolicy('Alice', 1, 2);
    await service.kick('Alice', 'Break', 2);
    await service.disablePolicy('Alice');
    expect(f.bans, contains('Alice'));
    expect(service.status.single.enabled, isFalse);
    await service.setPolicy('Alice', 2, 1);
    await service.release('Alice');
    expect(service.status.single.enabled, isTrue);
    expect(f.bans, isEmpty);
  });

  test('failed durable intent save prevents issuing a ban', () async {
    final f = _Fixture();
    final service = f.service();
    await service.load('example:25575');
    f.failWrites = true;
    await expectLater(service.kick('Alice', 'Break', 1), throwsStateError);
    expect(f.commands.where((c) => c.startsWith('ban ')), isEmpty);
    expect(service.status.single.blockedUntil, isNull);
  });

  test(
    'server isolation prevents releasing one server’s ban on another',
    () async {
      final f = _Fixture();
      final service = f.service();
      await service.load('first:25575');
      await service.kick('Alice', 'Break', 1);
      await service.load('second:25575');
      f.advance(60);
      await service.observePlayers([]);
      expect(service.status, isEmpty);
      expect(f.bans, contains('Alice'));
      expect(f.commands.where((c) => c.startsWith('pardon ')), isEmpty);
    },
  );

  test(
    'parallel mutations are serialized and extend a single owned ban',
    () async {
      final f = _Fixture();
      final service = f.service();
      await service.load('example:25575');
      await Future.wait([
        service.kick('Alice', 'Break', 1),
        service.kick('Alice', 'Longer break', 5),
      ]);
      expect(f.commands.where((c) => c.startsWith('ban ')).length, 1);
      expect(
        service.status.single.blockedUntil,
        f.now.add(const Duration(minutes: 5)),
      );
    },
  );

  test(
    'ban list handles vanilla concatenation and fails closed on unknown formats',
    () {
      expect(
        PlayerTimerService.parseBanList(
          'There are 2 ban(s):Alice was banned by Rcon: Reason.Bob was banned by Admin: Other.',
        ),
        {'alice': 'Reason.', 'bob': 'Other.'},
      );
      expect(
        () => PlayerTimerService.parseBanList('Unknown command'),
        throwsFormatException,
      );
      expect(
        () => PlayerTimerService.parseBanList(
          'There are 2 ban(s):Alice was banned by Rcon: Only one',
        ),
        throwsFormatException,
      );
    },
  );
  test('first enabling policy preserves already observed play time', () async {
    final f = _Fixture();
    final service = f.service();
    await service.load('example:25575');
    await service.observePlayers(['Alice']);
    f.advance(30);
    await service.observePlayers(['Alice']);
    await service.setPolicy('Alice', 1, 2);
    expect(service.status.single.playedSeconds, 30);
  });

  test(
    'owned ban after concatenated alphanumeric reason is released',
    () async {
      for (final reason in [
        'griefing',
        'averylongreasonendingwithlettersandnospaces',
      ]) {
        final f = _Fixture()..concatenateBans = true;
        f.bans['Steve'] = reason;
        final service = f.service();
        await service.load('example:25575');
        await service.kick('Alex', 'Take a break', 1);
        f.advance(60);
        await service.observePlayers([]);
        expect(f.bans, {'Steve': reason});
        expect(service.status.single.blockedUntil, isNull);
        expect(f.commands, contains('pardon Alex'));
      }
    },
  );

  test('ambiguous suffixed player names preserve release intent', () async {
    final f = _Fixture()..concatenateBans = true;
    final service = f.service();
    await service.load('example:25575');
    await service.kick('Alex', 'Break', 1);
    f.bans['BigAlex'] = 'Another ban';
    f.advance(60);
    await service.observePlayers([]);
    expect(f.bans.keys, containsAll(['Alex', 'BigAlex']));
    expect(service.status.single.blockedUntil, isNotNull);
    expect(f.commands.where((c) => c.startsWith('pardon ')), isEmpty);
    expect(f.errors.single, contains('Ambiguous'));
  });

  test(
    'similarly suffixed existing name conservatively prevents new lock',
    () async {
      final f = _Fixture()..bans['BigAlex'] = 'Existing ban';
      final service = f.service();
      await service.load('example:25575');
      await expectLater(service.kick('Alex', 'Break', 1), throwsStateError);
      expect(f.commands.where((c) => c.startsWith('ban ')), isEmpty);
      expect(f.bans, {'BigAlex': 'Existing ban'});
    },
  );

  test('checkpoint write failure does not prevent overdue pardon', () async {
    final f = _Fixture();
    final service = f.service();
    await service.load('example:25575');
    await service.kick('Alice', 'Break', 1);
    f.advance(60);
    f.failWrites = true;
    await expectLater(service.observePlayers([]), throwsStateError);
    expect(f.bans, isEmpty);
    expect(service.status.single.blockedUntil, isNotNull);
    f.failWrites = false;
    await service.observePlayers([]);
    expect(service.status.single.blockedUntil, isNull);
  });

  test('case-insensitive duplicate ban entries fail closed', () {
    expect(
      () => PlayerTimerService.parseBanList(
        'There are 2 ban(s):Alice was banned by Rcon: A.\nALICE was banned by Rcon: B.',
      ),
      throwsFormatException,
    );
  });

  test('ban reason cannot spoof a second ban-list entry', () async {
    final f = _Fixture()..concatenateBans = true;
    final service = f.service();
    await service.load('example:25575');
    await service.kick(
      'Alex',
      'Other was ban§aned by Server: malicious text',
      1,
    );
    f.advance(60);
    await service.observePlayers([]);
    expect(f.bans, isEmpty);
    expect(service.status.single.blockedUntil, isNull);
  });
  test(
    'multiple owned bans with one-word reasons all release when concatenated',
    () async {
      final f = _Fixture()..concatenateBans = true;
      final service = f.service();
      await service.load('example:25575');
      await service.kick('Alice', 'Break', 1);
      await service.kick('Bob', 'Break', 1);
      await service.kick('Charlie', 'Break', 1);
      f.advance(60);
      await service.observePlayers([]);
      expect(f.bans, isEmpty);
      expect(service.status.every((s) => s.blockedUntil == null), isTrue);
      expect(f.errors, isEmpty);
    },
  );
}
