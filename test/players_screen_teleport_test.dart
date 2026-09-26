import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_rcon/models/player.dart';
import 'package:mc_rcon/models/player_admin_status.dart';
import 'package:mc_rcon/providers/rcon_provider.dart';
import 'package:mc_rcon/screens/player_actions_screen.dart';
import 'package:mc_rcon/screens/players_screen.dart';
import 'package:mc_rcon/theme/app_theme.dart';
import 'package:provider/provider.dart';

class _TeleportProvider extends RconProvider {
  List<Player> activePlayers = [Player(name: 'Alex'), Player(name: 'Steve')];
  List<PlayerTimerStatus> statuses = [];
  final commands = <String>[];
  String reply = 'Moved Alex to Steve';
  Future<String> Function(String)? commandHandler;

  @override
  Future<void> loadSavedConnections() async {}

  @override
  bool get isConnected => true;

  @override
  List<Player> get players => activePlayers;

  @override
  List<PlayerTimerStatus> get timerStatuses => statuses;

  @override
  Future<void> refreshPlayers() async {}

  @override
  Future<String> sendCommand(String command) async {
    commands.add(command);
    return commandHandler == null ? reply : await commandHandler!(command);
  }

  void updatePlayers(List<Player> players) {
    activePlayers = players;
    notifyListeners();
  }
}

Future<_TeleportProvider> _showPlayers(
  WidgetTester tester, {
  _TeleportProvider? provider,
  Size size = const Size(1000, 900),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final model = provider ?? _TeleportProvider();
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

Finder _card(String player) => find.byKey(ValueKey(player));

Finder _buttonsFor(String player) => find.descendant(
  of: _card(player),
  matching: find.byWidgetPredicate((widget) => widget is TextButton),
);

Finder _destination(String from, String to) => find.ancestor(
  of: find.descendant(of: _card(from), matching: find.text(to)),
  matching: find.byWidgetPredicate((widget) => widget is TextButton),
);

void main() {
  testWidgets(
    'teleport shortcuts move the card player without opening a page',
    (tester) async {
      final model = await _showPlayers(tester);

      expect(find.text('Teleport to'), findsNWidgets(2));
      expect(find.text('Heal'), findsNothing);
      expect(find.text('Feed'), findsNothing);
      expect(find.text('Invincible'), findsNothing);
      expect(find.byTooltip('Teleport Alex to Steve'), findsOneWidget);
      expect(_destination('Alex', 'Alex'), findsNothing);

      await tester.tap(_destination('Alex', 'Steve'));
      await tester.pumpAndSettle();

      expect(model.commands, ['tp Alex Steve']);
      expect(find.text('Moved Alex to Steve'), findsOneWidget);
      expect(find.byType(PlayerActionsScreen), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(PlayersScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'targets include all online players regardless of search and update live',
    (tester) async {
      const botName = '[Bot]Steve';
      final model = _TeleportProvider()
        ..activePlayers = [
          Player(name: 'Alex'),
          Player(name: 'Steve'),
          Player(name: botName, botOwner: 'Steve'),
        ]
        ..statuses = [
          const PlayerTimerStatus(
            name: 'OfflinePlayer',
            online: false,
            enabled: true,
            playedSeconds: 0,
            playSeconds: 3600,
            breakSeconds: 120,
          ),
        ];
      await _showPlayers(tester, provider: model);

      expect(_buttonsFor(botName), findsNothing);
      expect(_buttonsFor('OfflinePlayer'), findsNothing);
      expect(_destination('Alex', 'OfflinePlayer'), findsNothing);
      expect(_destination('Alex', 'Alex'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Alex');
      await tester.pumpAndSettle();

      expect(_card('Steve'), findsNothing);
      expect(_card(botName), findsNothing);
      expect(_destination('Alex', 'Steve'), findsOneWidget);
      expect(_destination('Alex', botName), findsOneWidget);
      await tester.tap(_destination('Alex', botName));
      await tester.pumpAndSettle();
      expect(model.commands, ['tp Alex @a[name="[Bot]Steve",limit=1]']);

      model.updatePlayers([Player(name: 'Alex'), Player(name: 'NewPlayer')]);
      await tester.pumpAndSettle();

      expect(_destination('Alex', 'Steve'), findsNothing);
      expect(_destination('Alex', botName), findsNothing);
      expect(_destination('Alex', 'NewPlayer'), findsOneWidget);
      expect(_destination('Alex', 'OfflinePlayer'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('self destinations are excluded regardless of name casing', (
    tester,
  ) async {
    final model = _TeleportProvider()
      ..activePlayers = [
        Player(name: 'Alex'),
        Player(name: 'aLeX'),
        Player(name: 'Steve'),
      ];
    await _showPlayers(tester, provider: model);

    expect(_destination('Alex', 'Alex'), findsNothing);
    expect(_destination('Alex', 'aLeX'), findsNothing);
    expect(_destination('aLeX', 'Alex'), findsNothing);
    expect(_destination('Alex', 'Steve'), findsOneWidget);
    expect(_destination('aLeX', 'Steve'), findsOneWidget);
  });

  testWidgets('a lone player has no teleport targets', (tester) async {
    final model = _TeleportProvider()..activePlayers = [Player(name: 'Alex')];
    await _showPlayers(tester, provider: model);

    expect(find.text('No other players online'), findsOneWidget);
    expect(_buttonsFor('Alex'), findsNothing);
    expect(model.commands, isEmpty);

    model.updatePlayers([Player(name: 'Alex'), Player(name: 'Steve')]);
    await tester.pumpAndSettle();
    expect(find.text('No other players online'), findsNothing);
    expect(_destination('Alex', 'Steve'), findsOneWidget);
  });

  testWidgets('pending moves suppress duplicates and recover after an error', (
    tester,
  ) async {
    final pending = Completer<String>();
    final model = _TeleportProvider()
      ..activePlayers = [
        Player(name: 'Alex'),
        Player(name: 'Steve'),
        Player(name: 'Sam'),
      ]
      ..commandHandler = (_) => pending.future;
    await _showPlayers(tester, provider: model);

    // Tap twice before rebuilding to also exercise the handler's busy guard.
    await tester.tap(_destination('Alex', 'Steve'));
    await tester.tap(_destination('Alex', 'Steve'));
    await tester.pump();

    expect(model.commands, ['tp Alex Steve']);
    for (final button in tester.widgetList<TextButton>(_buttonsFor('Alex'))) {
      expect(button.onPressed, isNull);
    }
    expect(
      tester.widget<TextButton>(_destination('Steve', 'Alex')).onPressed,
      isNotNull,
    );
    await tester.tap(_destination('Alex', 'Sam'));
    await tester.pump();
    expect(model.commands, ['tp Alex Steve']);
    expect(find.byType(PlayerActionsScreen), findsNothing);
    expect(find.byType(PlayersScreen), findsOneWidget);

    pending.completeError(
      const RconCommandException('Server refused teleport'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Server refused teleport'), findsOneWidget);
    for (final button in tester.widgetList<TextButton>(_buttonsFor('Alex'))) {
      expect(button.onPressed, isNotNull);
    }
    final context = tester.element(_card('Alex'));
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    model.commandHandler = null;
    model.reply = '';
    await tester.tap(_destination('Alex', 'Sam'));
    await tester.pumpAndSettle();

    expect(model.commands, ['tp Alex Steve', 'tp Alex Sam']);
    expect(find.text('Teleported Alex to Sam'), findsOneWidget);
    expect(find.byType(PlayerActionsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long destination names remain usable on a compact screen', (
    tester,
  ) async {
    const source = 'LongPlayerName16';
    const botOwner = 'OtherPlayerName2';
    const botName = '[Bot]$botOwner';
    final model = _TeleportProvider()
      ..activePlayers = [
        Player(name: source),
        Player(name: 'OtherPlayerName1'),
        Player(name: botName, botOwner: botOwner),
        Player(name: 'OtherPlayerName3'),
      ];
    await _showPlayers(tester, provider: model, size: const Size(320, 760));

    expect(_buttonsFor(source), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(_destination(source, botName));
    await tester.pumpAndSettle();
    await tester.tap(_destination(source, botName));
    await tester.pumpAndSettle();

    expect(model.commands, ['tp $source @a[name="$botName",limit=1]']);
    expect(find.byType(PlayerActionsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
