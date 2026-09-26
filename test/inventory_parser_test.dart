import 'package:flutter_test/flutter_test.dart';
import 'package:mc_rcon/models/inventory_item.dart';
import 'package:mc_rcon/models/item_catalog.dart';
import 'package:mc_rcon/services/inventory_parser.dart';

void main() {
  test('bot name brackets are not mistaken for the inventory list', () {
    final data = InventoryParser.parse(
      '[Bot]Alex has the following entity data: [{Slot: 0b, id: "minecraft:stone", count: 64}]',
    );
    expect(data.single['id'], 'minecraft:stone');
    expect(data.single['count'], 64);
  });

  test('reads modern components without corrupting numbers inside strings', () {
    final data = InventoryParser.parse(
      r'''Alex has the following entity data: [{Slot: 0b, id: "minecraft:diamond_sword", count: 1, components: {"minecraft:custom_name": '{"text":"Sword 10s, [rare]"}', "minecraft:custom_data": {bytes: [B; 1b, -2b], uuid: [I; 1, 2, 3, 4], energy: 1.5d, enabled: true}}}, {Slot: -106b, id: "minecraft:torch", count: 64}]''',
    );
    expect(data.length, 2);
    final components = data.first['components'] as Map;
    expect(components['minecraft:custom_name'], '{"text":"Sword 10s, [rare]"}');
    expect(components['minecraft:custom_data']['bytes'], [1, -2]);
    expect(components['minecraft:custom_data']['energy'], 1.5);
    final offhand = InventoryItem.fromNbt(data.last);
    expect(offhand.slot, -106);
    expect(offhand.count, 64);
  });

  test(
    'reads legacy Count, nested tag data, escaped quotes and namespaced ID',
    () {
      final data = InventoryParser.parse(
        r'''Alex has the following entity data: [{Slot: 103b, id: 'mod:magic_hat', Count: 2b, tag: {display: {Name: 'The \'best\' hat'}, values: [L; -1L, 99L]}}]''',
      );
      final item = InventoryItem.fromNbt(data.single);
      expect(item.id, 'mod:magic_hat');
      expect(item.count, 2);
      expect(item.slot, 103);
      expect(data.single['tag']['display']['Name'], "The 'best' hat");
    },
  );

  test('empty inventory is distinct from an error or truncated response', () {
    expect(
      InventoryParser.parse('Alex has the following entity data: []'),
      isEmpty,
    );
    for (final response in [
      'No entity was found',
      '[{Slot:0b, id:"minecraft:stone", count:2',
      '[{Slot:0b, id:"minecraft:stone", count:2}] trailing',
      '[42]',
      '[{Slot:0b}]',
    ]) {
      expect(() => InventoryParser.parse(response), throwsFormatException);
    }
  });

  test('search accepts human names and IDs and preserves mod namespaces', () {
    expect(
      ItemCatalog.search('diamond sword').first,
      'minecraft:diamond_sword',
    );
    expect(
      ItemCatalog.search('minecraft:diamond_sword').first,
      'minecraft:diamond_sword',
    );
    expect(ItemCatalog.normalizeId('example:magic_wand'), 'example:magic_wand');
    expect(ItemCatalog.normalizeId('Diamond Sword'), 'minecraft:diamond_sword');
    expect(ItemCatalog.normalizeId('example:item\n/kick Alex'), isNull);
    expect(ItemCatalog.normalizeId('minecraft:example:item'), isNull);
    expect(ItemCatalog.normalizeId('stone[foo=bar]'), isNull);
  });

  test(
    'catalog suggests real names and categories instead of invented variants',
    () {
      expect(
        ItemCatalog.ids,
        containsAll([
          'minecraft:beef',
          'minecraft:bamboo_raft',
          'minecraft:stone_brick_stairs',
        ]),
      );
      expect(ItemCatalog.ids, isNot(contains('minecraft:raw_beef')));
      expect(ItemCatalog.ids, isNot(contains('minecraft:crimson_boat')));
      expect(ItemCatalog.ids, isNot(contains('minecraft:stone_bricks_stairs')));
      expect(
        ItemCatalog.search('beef', selectedCategory: 'Food'),
        contains('minecraft:cooked_beef'),
      );
    },
  );
}
