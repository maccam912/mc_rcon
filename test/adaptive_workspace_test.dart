import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_rcon/models/player.dart';
import 'package:mc_rcon/models/server_connection.dart';
import 'package:mc_rcon/providers/rcon_provider.dart';
import 'package:mc_rcon/screens/home_screen.dart';
import 'package:mc_rcon/theme/app_theme.dart';
import 'package:provider/provider.dart';

class _WorkspaceProvider extends RconProvider {
  @override
  Future<void> loadSavedConnections() async {}
  @override
  bool get isConnected => true;
  @override
  ServerConnection get currentConnection => ServerConnection(
    id: 'test',
    name: 'A very long server name to verify compact layouts',
    host: 'localhost',
    port: 25575,
    password: 'test',
  );
  @override
  List<Player> get players => [Player(name: 'Alex'), Player(name: 'Steve')];
  @override
  Future<void> refreshPlayers() async {}
  @override
  Future<String> sendCommand(String command) async => 'Reply to $command';
}

Future<void> _mount(
  WidgetTester tester,
  Size size, {
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final provider = _WorkspaceProvider();
  addTearDown(provider.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<RconProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _nav(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets(
    'draft, output and player search survive tab switches and resize',
    (tester) async {
      await _mount(tester, const Size(1200, 850));
      expect(find.byType(NavigationBar), findsNothing);
      await tester.enterText(find.byType(TextField), 'Alex');
      await tester.tap(find.widgetWithText(ListTile, 'Console'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'list');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Send'));
      await tester.pumpAndSettle();
      expect(find.text('Reply to list', findRichText: true), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'time query daytime');
      await tester.tap(find.widgetWithText(ListTile, 'Players'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Alex',
      );
      tester.view.physicalSize = const Size(360, 760);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(_nav('Console'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'time query daytime',
      );
      expect(find.text('Reply to list', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 1.4]) {
    testWidgets('phone workspace handles text scale $scale and keyboard', (
      tester,
    ) async {
      await _mount(tester, const Size(320, 640), textScale: scale);
      expect(tester.takeException(), isNull);
      await tester.tap(_nav('Quick actions'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(_nav('Console'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byType(TextField), 'list');
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Send command').hitTestable(), findsOneWidget);
    });
  }
}
