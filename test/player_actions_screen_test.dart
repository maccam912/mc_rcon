import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mc_rcon/models/player.dart';
import 'package:mc_rcon/models/player_admin_status.dart';
import 'package:mc_rcon/providers/rcon_provider.dart';
import 'package:mc_rcon/screens/player_actions_screen.dart';
import 'package:mc_rcon/screens/players_screen.dart';
import 'package:mc_rcon/theme/app_theme.dart';

class _UiProvider extends RconProvider {
  List<Player> activePlayers = [Player(name: 'Alex')];
  List<PlayerTimerStatus> statuses = [];
  bool failKick = false;
  (String, String, int)? lastKick;
  (String, int, int)? lastPolicy;

  @override
  Future<void> loadSavedConnections() async {}
  @override
  bool get isConnected => true;
  @override
  bool get supportsPlayerTimers => true;
  @override
  List<Player> get players => activePlayers;
  @override
  List<PlayerTimerStatus> get timerStatuses => statuses;
  @override
  Future<void> refreshPlayers() async {}

  @override
  Future<String> kickPlayer(
    String name,
    String reason, {
    int lockoutMinutes = 0,
  }) async {
    lastKick = (name, reason, lockoutMinutes);
    if (failKick) throw const RconCommandException('Server refused the kick');
    activePlayers = activePlayers
        .where((player) => player.name != name)
        .toList();
    notifyListeners();
    return name.startsWith('[Bot]')
        ? 'Dismissed $name'
        : 'Kicked $name for $lockoutMinutes minutes';
  }

  @override
  Future<String> setPlayPolicy(
    String name,
    int playMinutes,
    int breakMinutes,
  ) async {
    lastPolicy = (name, playMinutes, breakMinutes);
    statuses = [
      PlayerTimerStatus(
        name: name,
        online: true,
        enabled: true,
        playedSeconds: 0,
        playSeconds: playMinutes * 60,
        breakSeconds: breakMinutes * 60,
      ),
    ];
    notifyListeners();
    return 'Saved play break for $name';
  }
}

Future<_UiProvider> _showPlayers(
  WidgetTester tester,
  Size size, {
  _UiProvider? provider,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final model = provider ?? _UiProvider();
  addTearDown(model.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<RconProvider>.value(
      value: model,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: PlayersScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return model;
}

Future<void> _openKick(WidgetTester tester, {bool bot = false}) async {
  final action = find.text(bot ? 'Dismiss bot' : 'Kick');
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
}

void main() {
  for (final size in [
    const Size(320, 760),
    const Size(360, 760),
    const Size(1200, 850),
  ]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('failed kick stays open; five-minute kick succeeds at $label', (
      tester,
    ) async {
      final model = await _showPlayers(tester, size);
      await tester.tap(find.text('Alex'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      model.failKick = true;
      await _openKick(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Kick'));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerActionsScreen), findsOneWidget);
      expect(find.text('Error: Server refused the kick'), findsOneWidget);
      model.failKick = false;
      await _openKick(tester);
      await tester.ensureVisible(find.text('5 min'));
      await tester.tap(find.text('5 min'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Kick'));
      await tester.pumpAndSettle();
      expect(model.lastKick, ('Alex', 'Time for a break!', 5));
      expect(find.byType(PlayerActionsScreen), findsNothing);
      expect(find.text('Kicked Alex for 5 minutes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'assistant bots have separate labels and dismiss action at $label',
      (tester) async {
        const owner = 'LongPlayerName16';
        const botName = '[Bot]$owner';
        final model = _UiProvider()
          ..activePlayers = [Player(name: botName, botOwner: owner)];
        await _showPlayers(tester, size, provider: model);
        expect(find.text('Assistant bots (1)'), findsOneWidget);
        expect(find.text('Bot for $owner'), findsOneWidget);
        expect(find.text('Players (0)'), findsOneWidget);
        await tester.tap(find.text(botName));
        await tester.pumpAndSettle();
        expect(find.text('Play breaks'), findsNothing);
        expect(tester.takeException(), isNull);
        await _openKick(tester, bot: true);
        expect(find.text('Block reconnecting (minutes)'), findsNothing);
        await tester.tap(find.widgetWithText(FilledButton, 'Dismiss bot'));
        await tester.pumpAndSettle();
        expect(model.lastKick?.$1, botName);
        expect(model.lastKick?.$3, 0);
        expect(find.byType(PlayerActionsScreen), findsNothing);
        expect(find.text('Dismissed $botName'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('saves a 60-minute play and 2-minute break policy at $label', (
      tester,
    ) async {
      final model = await _showPlayers(tester, size);
      await tester.tap(find.text('Alex'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Set play break'));
      await tester.tap(find.text('Set play break'));
      await tester.pumpAndSettle();
      expect(find.text('Play break for Alex'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), '60');
      await tester.enterText(fields.at(1), '2');
      await tester.tap(find.widgetWithText(FilledButton, 'Save policy'));
      await tester.pumpAndSettle();
      expect(model.lastPolicy, ('Alex', 60, 2));
      expect(find.byType(PlayerActionsScreen), findsOneWidget);
      expect(find.text('Saved play break for Alex'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'offline players with active timers remain accessible at $label',
      (tester) async {
        final model = _UiProvider()
          ..statuses = [
            const PlayerTimerStatus(
              name: 'OfflinePlayer',
              online: false,
              enabled: true,
              playedSeconds: 120,
              playSeconds: 3600,
              breakSeconds: 120,
            ),
          ];
        await _showPlayers(tester, size, provider: model);
        expect(find.text('Offline players with timers'), findsOneWidget);
        await tester.ensureVisible(find.text('OfflinePlayer'));
        await tester.tap(find.text('OfflinePlayer'));
        await tester.pumpAndSettle();
        expect(find.byType(PlayerActionsScreen), findsOneWidget);
        expect(find.text('Offline'), findsOneWidget);
        expect(find.text('Edit policy'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
