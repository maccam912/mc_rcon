import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mc_rcon/models/server_connection.dart';
import 'package:mc_rcon/providers/rcon_provider.dart';
import 'package:mc_rcon/screens/connection_screen.dart';
import 'package:mc_rcon/services/storage_service.dart';
import 'package:mc_rcon/theme/app_theme.dart';

class _EmptyStorage extends StorageService {
  @override
  Future<List<ServerConnection>> getConnections() async => [];
}

class _ConnectionProvider extends RconProvider {
  _ConnectionProvider([List<ServerConnection> initial = const []])
    : _saved = [...initial],
      super(storage: _EmptyStorage());

  final List<ServerConnection> _saved;
  final saves = <ServerConnection>[];
  final deletions = <String>[];
  final connectionRequests = <ServerConnection>[];
  final connectionResult = Completer<bool>();
  Completer<void>? saveGate;
  bool _connecting = false;

  @override
  List<ServerConnection> get savedConnections => List.unmodifiable(_saved);

  @override
  bool get isConnecting => _connecting;

  @override
  String? get lastError => 'Could not reach the server.';

  @override
  Future<void> saveConnection(ServerConnection connection) async {
    saves.add(connection);
    if (saveGate != null) await saveGate!.future;
    _saved.removeWhere((saved) => saved.id == connection.id);
    _saved.add(connection);
    notifyListeners();
  }

  @override
  Future<void> deleteConnection(String id) async {
    deletions.add(id);
    _saved.removeWhere((saved) => saved.id == id);
    notifyListeners();
  }

  @override
  Future<bool> connect(ServerConnection connection) async {
    connectionRequests.add(connection);
    _connecting = true;
    notifyListeners();
    final result = await connectionResult.future;
    _connecting = false;
    notifyListeners();
    return result;
  }
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

String _value(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;

Future<void> _showScreen(
  WidgetTester tester,
  _ConnectionProvider provider, {
  Size size = const Size(1200, 1000),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ChangeNotifierProvider<RconProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const ConnectionScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  final savedServer = ServerConnection(
    id: 'survival',
    name: 'Survival world',
    host: 'play.example.test',
    port: 25580,
    password: 'saved-password',
  );

  testWidgets('saved connection editing can be cancelled without saving', (
    tester,
  ) async {
    final provider = _ConnectionProvider([savedServer]);
    addTearDown(provider.dispose);
    await _showScreen(tester, provider);

    await _tapVisible(tester, find.byTooltip('Options for Survival world'));
    await _tapVisible(tester, find.text('Edit connection').last);

    expect(_value(tester, 'Server name (optional)'), 'Survival world');
    expect(_value(tester, 'Host / IP address'), 'play.example.test');
    expect(_value(tester, 'RCON port'), '25580');
    expect(_value(tester, 'RCON password'), 'saved-password');
    expect(find.text('Save & connect'), findsOneWidget);

    await tester.enterText(_field('Host / IP address'), 'changed.example.test');
    await _tapVisible(tester, find.text('Cancel edit'));

    expect(find.text('New connection'), findsOneWidget);
    expect(_value(tester, 'Server name (optional)'), isEmpty);
    expect(_value(tester, 'Host / IP address'), isEmpty);
    expect(_value(tester, 'RCON port'), '25575');
    expect(_value(tester, 'RCON password'), isEmpty);
    expect(provider.savedConnections.single.host, 'play.example.test');
    expect(provider.saves, isEmpty);
    expect(provider.connectionRequests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling server removal keeps its saved credentials', (
    tester,
  ) async {
    final provider = _ConnectionProvider([savedServer]);
    addTearDown(provider.dispose);
    await _showScreen(tester, provider);

    await _tapVisible(tester, find.byTooltip('Options for Survival world'));
    await _tapVisible(tester, find.text('Remove server'));
    expect(find.text('Remove saved server?'), findsOneWidget);
    await _tapVisible(tester, find.text('Cancel'));

    expect(provider.deletions, isEmpty);
    expect(provider.savedConnections.single.password, 'saved-password');
    expect(find.text('Survival world'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone form validates before saving or connecting', (
    tester,
  ) async {
    final provider = _ConnectionProvider();
    addTearDown(provider.dispose);
    await _showScreen(tester, provider, size: const Size(390, 844));

    await tester.enterText(_field('Host / IP address'), '   ');
    await tester.enterText(_field('RCON port'), '70000');
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Connect'));

    expect(
      find.text('Enter the server hostname or IP address'),
      findsOneWidget,
    );
    expect(find.text('Enter a port between 1 and 65535'), findsOneWidget);
    expect(find.text('Enter the RCON password'), findsOneWidget);
    expect(provider.saves, isEmpty);
    expect(provider.connectionRequests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving and connecting disable duplicate submissions', (
    tester,
  ) async {
    final provider = _ConnectionProvider()..saveGate = Completer<void>();
    addTearDown(provider.dispose);
    await _showScreen(tester, provider);
    await tester.enterText(_field('Host / IP address'), '  localhost  ');
    await tester.enterText(_field('RCON password'), 'secret');
    final connectButton = find.byType(FilledButton);
    await tester.ensureVisible(connectButton);
    await tester.pumpAndSettle();
    await tester.tap(connectButton);
    await tester.pump();

    expect(provider.saves, hasLength(1));
    expect(provider.connectionRequests, isEmpty);
    expect(tester.widget<FilledButton>(connectButton).onPressed, isNull);
    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .every((field) => field.enabled == false),
      isTrue,
    );
    await tester.tap(connectButton);
    await tester.pump();
    expect(provider.saves, hasLength(1));

    provider.saveGate!.complete();
    await tester.pump();
    expect(provider.connectionRequests, hasLength(1));
    expect(provider.connectionRequests.single.host, 'localhost');
    expect(provider.connectionRequests.single.name, 'localhost');
    expect(tester.widget<FilledButton>(connectButton).onPressed, isNull);
    await tester.tap(connectButton);
    await tester.pump();
    expect(provider.connectionRequests, hasLength(1));

    provider.connectionResult.complete(false);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(connectButton).onPressed, isNotNull);
    expect(find.text('Could not reach the server.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
