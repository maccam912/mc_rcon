import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_rcon/models/player.dart';
import 'package:mc_rcon/providers/rcon_provider.dart';
import 'package:mc_rcon/screens/inventory_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InventoryProvider extends RconProvider {
  final commands = <String>[];
  Object? giveError;
  Completer<List<Map<String, dynamic>>>? inventoryRequest;

  @override
  Future<List<Map<String, dynamic>>> getPlayerInventory(
    String playerName,
  ) async {
    if (inventoryRequest != null) return inventoryRequest!.future;
    return [];
  }

  @override
  Future<String> giveItem(String playerName, String item, int amount) async {
    if (giveError != null) throw giveError!;
    commands.add('give $playerName $item $amount');
    return 'Gave $amount $item to $playerName';
  }

  @override
  Future<String> setItem(
    String playerName,
    int slot,
    String itemId,
    int amount,
  ) async {
    commands.add('set $playerName $slot $itemId $amount');
    return 'Replaced slot';
  }
}

Future<void> _load(
  WidgetTester tester,
  _InventoryProvider provider,
  Size size,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider<RconProvider>.value(
      value: provider,
      child: MaterialApp(
        home: InventoryScreen(player: Player(name: 'Alex')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in [const Size(360, 760), const Size(1200, 850)]) {
    testWidgets('search, select quantity and give with feedback at $size', (
      tester,
    ) async {
      final provider = _InventoryProvider();
      addTearDown(provider.dispose);
      await _load(tester, provider, size);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Give items'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search by name or item ID'),
        'diamond sword',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Diamond Sword'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '16'));
      await tester.pump();
      await tester.tap(find.text('Give 16 items'));
      await tester.pumpAndSettle();
      expect(provider.commands, ['give Alex minecraft:diamond_sword 16']);
      expect(find.text('Gave 16 × Diamond Sword to Alex.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'custom namespace and server failure remain visible with quantity preserved',
    (tester) async {
      final provider = _InventoryProvider()
        ..giveError = StateError('Unknown item');
      addTearDown(provider.dispose);
      await _load(tester, provider, const Size(360, 760));
      await tester.tap(find.text('Give items'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search by name or item ID'),
        'example:wand',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use custom ID: example:wand'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Give 1 item'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Unknown item'), findsOneWidget);
      expect(find.text('example:wand'), findsOneWidget);
      expect(find.text('Give 1 item'), findsOneWidget);
      expect(provider.commands, isEmpty);
    },
  );

  testWidgets('phone keyboard keeps both search and amount layouts usable', (
    tester,
  ) async {
    final provider = _InventoryProvider();
    addTearDown(provider.dispose);
    await _load(tester, provider, const Size(320, 640));
    await tester.tap(find.text('Give items'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search by name or item ID'),
      'torch',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Torch').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(TextField, 'Amount'));
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '64');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Give 64 items'), findsOneWidget);
  });

  testWidgets('late inventory response does not update a disposed screen', (
    tester,
  ) async {
    final provider = _InventoryProvider()..inventoryRequest = Completer();
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<RconProvider>.value(
        value: provider,
        child: MaterialApp(
          home: InventoryScreen(player: Player(name: 'Alex')),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    provider.inventoryRequest!.complete([]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
