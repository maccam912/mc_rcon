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
      count: (nbt['count'] ?? 1).toInt(),
      slot: (nbt['Slot'] ?? 0).toInt(),
      tag: nbt['tag']?.toString(),
    );
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
