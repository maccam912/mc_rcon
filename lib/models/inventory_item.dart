class InventoryItem {
  final String id;
  final int count;
  final int slot;
  final String? tag; // For NBT data

  InventoryItem({
    required this.id,
    required this.count,
    required this.slot,
    this.tag,
  });

  factory InventoryItem.fromNbt(Map<String, dynamic> nbt) {
    return InventoryItem(
      id: nbt['id'] ?? 'minecraft:air',
      count: _integer(nbt['count'] ?? nbt['Count'], 1),
      slot: _integer(nbt['Slot'] ?? nbt['slot'], -1),
      tag: (nbt['components'] ?? nbt['tag'])?.toString(),
    );
  }

  static int _integer(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.replaceFirst(RegExp(r'[bBsSlL]$'), '')) ??
          fallback;
    }
    return fallback;
  }

  String get displayName {
    // Basic formatting: minecraft:diamond_sword -> Diamond Sword
    String name = id.split(':').last;
    name = name.replaceAll('_', ' ');
    return name
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }
}
