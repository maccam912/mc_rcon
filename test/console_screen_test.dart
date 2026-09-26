import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_rcon/providers/rcon_provider.dart';
import 'package:mc_rcon/screens/console_screen.dart';
import 'package:mc_rcon/theme/app_theme.dart';
import 'package:provider/provider.dart';

class _ConsoleProvider extends RconProvider {
  final List<String> sentCommands = [];
  final List<String> recentCommands = [];
  Completer<String>? pendingResponse;
  String response = 'There are 2 players online: Alex, Steve';

  @override
  Future<void> loadSavedConnections() async {}

  @override
  List<String> get commandHistory => List.unmodifiable(recentCommands);

  @override
  Future<String> sendCommand(String command) {
    sentCommands.add(command);
    recentCommands.insert(0, command);
    return pendingResponse?.future ?? Future.value(response);
  }
}

Future<_ConsoleProvider> _showConsole(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double keyboardHeight = 0,
  _ConsoleProvider? provider,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);
  final model = provider ?? _ConsoleProvider();
  addTearDown(model.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<RconProvider>.value(
      value: model,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          appBar: AppBar(title: const Text('Test server')),
          body: const ConsoleScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return model;
}

String _draft(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets(
    'composer stays visible above the phone keyboard and long output',
    (tester) async {
      final model = _ConsoleProvider()
        ..response = List.generate(
          80,
          (index) => 'Server output line $index',
        ).join('\n');
      await _showConsole(tester, keyboardHeight: 320, provider: model);
      final input = find.byType(TextField);
      final send = find.byTooltip('Send command');
      expect(input.hitTestable(), findsOneWidget);
      expect(send.hitTestable(), findsOneWidget);
      expect(tester.getRect(input).bottom, lessThanOrEqualTo(844 - 320));

      await tester.enterText(input, 'list');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(model.sentCommands, ['list']);
      expect(find.text(model.response, findRichText: true), findsOneWidget);
      expect(input.hitTestable(), findsOneWidget);
      expect(send.hitTestable(), findsOneWidget);
      expect(tester.getRect(input).bottom, lessThanOrEqualTo(844 - 320));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('history selection fills the draft without executing it', (
    tester,
  ) async {
    final model = _ConsoleProvider()
      ..recentCommands.addAll(['say Welcome back', 'list']);
    await _showConsole(tester, provider: model);

    await tester.tap(find.byTooltip('Command history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('say Welcome back'));
    await tester.pumpAndSettle();

    expect(_draft(tester), 'say Welcome back');
    expect(model.sentCommands, isEmpty);
    expect(find.text('Your server, at your command'), findsOneWidget);

    await tester.tap(find.byTooltip('Send command'));
    await tester.pumpAndSettle();
    expect(model.sentCommands, ['say Welcome back']);
    expect(find.text('> say Welcome back', findRichText: true), findsOneWidget);
    expect(find.text(model.response, findRichText: true), findsOneWidget);
    expect(_draft(tester), isEmpty);
  });

  testWidgets('desktop history arrows restore an unfinished draft', (
    tester,
  ) async {
    final model = _ConsoleProvider()..recentCommands.addAll(['list', 'help']);
    await _showConsole(tester, size: const Size(1200, 850), provider: model);
    await tester.enterText(find.byType(TextField), 'say hello');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_draft(tester), 'list');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_draft(tester), 'help');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_draft(tester), 'say hello');
    expect(model.sentCommands, isEmpty);

    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(model.sentCommands, ['say hello']);
    expect(find.text(model.response, findRichText: true), findsOneWidget);
  });

  testWidgets('pending commands cannot be sent twice and errors allow retry', (
    tester,
  ) async {
    final pending = Completer<String>();
    final model = _ConsoleProvider()..pendingResponse = pending;
    await _showConsole(tester, provider: model);
    await tester.enterText(find.byType(TextField), 'list');
    await tester.pump();
    await tester.tap(find.byTooltip('Send command'));
    await tester.pump();
    await tester.tap(find.byTooltip('Send command'));
    await tester.pump();

    expect(model.sentCommands, ['list']);
    expect(find.text('Running…'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.delete_sweep_outlined),
          )
          .onPressed,
      isNull,
    );

    pending.completeError(const RconCommandException('Server refused command'));
    await tester.pumpAndSettle();
    expect(
      find.text('Error: Server refused command', findRichText: true),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
    model.pendingResponse = null;
    await tester.enterText(find.byType(TextField), 'list');
    await tester.pump();
    await tester.tap(find.byTooltip('Send command'));
    await tester.pumpAndSettle();
    expect(model.sentCommands, ['list', 'list']);
    expect(find.text(model.response, findRichText: true), findsOneWidget);
  });

  testWidgets('copy exports the transcript and clear keeps history and draft', (
    tester,
  ) async {
    String? clipboard;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final model = await _showConsole(tester);
    await tester.enterText(find.byType(TextField), 'list');
    await tester.pump();
    await tester.tap(find.byTooltip('Send command'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'say next');
    await tester.pump();
    await tester.tap(find.byTooltip('Copy console output'));
    await tester.pumpAndSettle();
    expect(clipboard, '> list\n${model.response}');

    await tester.tap(find.byTooltip('Clear console output'));
    await tester.pumpAndSettle();
    expect(find.text('Your server, at your command'), findsOneWidget);
    expect(find.text('> list', findRichText: true), findsNothing);
    expect(find.text(model.response, findRichText: true), findsNothing);
    expect(_draft(tester), 'say next');
    expect(model.commandHistory, ['list']);
    expect(model.sentCommands, ['list']);
  });
}
