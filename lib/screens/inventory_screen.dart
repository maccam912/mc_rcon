import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_item.dart';
import '../models/player.dart';
import '../providers/rcon_provider.dart';
import '../theme/app_theme.dart';

class InventoryScreen extends StatefulWidget {
  final Player player;

  const InventoryScreen({super.key, required this.player});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<InventoryItem> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // Mapping for slot display
  // Minecraft slots from 'data get' are:
  // 0-8: Hotbar
  // 9-35: Main Inventory
  // 100: Feet, 101: Legs, 102: Chest, 103: Head
  // -106: Offhand

  @override
  void initState() {
    super.initState();
    _refreshInventory();
  }

  Future<void> _refreshInventory() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<RconProvider>();
      final data = await provider.getPlayerInventory(widget.player.name);
      setState(() {
        _items = data.map((nbt) => InventoryItem.fromNbt(nbt)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching inventory: $e'),
            backgroundColor: AppTheme.redstone,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.player.name}\'s Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshInventory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildArmorAndOffhand(),
                        const SizedBox(height: 24),
                        _buildMainInventory(),
                        const SizedBox(height: 12),
                        _buildHotbar(),
                      ],
                    ),
                  ),
                ),
                _buildAddItemSection(),
              ],
            ),
    );
  }

  Widget _buildArmorAndOffhand() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Armor
        Column(
          children: [
            _buildSlot(103, Icons.face, 'Head'),
            const SizedBox(height: 4),
            _buildSlot(102, Icons.accessibility, 'Chest'),
            const SizedBox(height: 4),
            _buildSlot(101, Icons.airline_seat_legroom_extra, 'Legs'),
            const SizedBox(height: 4),
            _buildSlot(100, Icons.roller_skating, 'Feet'),
          ],
        ),
        const SizedBox(width: 24),
        // Offhand
        Column(
          children: [
            const Text(
              'Offhand',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            _buildSlot(-106, Icons.front_hand, 'Offhand'),
          ],
        ),
        const Expanded(child: SizedBox()),
        // Player Info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.person, size: 48, color: AppTheme.grassGreen),
                const SizedBox(height: 8),
                Text(
                  widget.player.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainInventory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Main Inventory',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 9,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: 27,
          itemBuilder: (context, index) {
            return _buildSlot(index + 9);
          },
        ),
      ],
    );
  }

  Widget _buildHotbar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hotbar',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 9,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            return _buildSlot(index);
          },
        ),
      ],
    );
  }

  Widget _buildSlot(int slotId, [IconData? emptyIcon, String? label]) {
    final item = _items.where((i) => i.slot == slotId).firstOrNull;

    return GestureDetector(
      onTap: () => _onSlotTap(slotId, item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[800],
          border: Border.all(color: Colors.grey[700]!, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            if (item == null)
              Center(
                child: Icon(
                  emptyIcon ?? Icons.inventory_2_outlined,
                  color: Colors.grey[600],
                  size: 20,
                ),
              )
            else
              Center(
                child: Tooltip(
                  message:
                      '${item.displayName}\n${item.id}\nAmount: ${item.count}',
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: _getItemIcon(item),
                  ),
                ),
              ),
            if (item != null && item.count > 1)
              Positioned(
                bottom: 2,
                right: 2,
                child: Text(
                  '${item.count}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _getItemIcon(InventoryItem item) {
    // We don't have item textures, so we use icons based on item type
    IconData icon = Icons.help_outline;
    Color color = Colors.white;

    final id = item.id.toLowerCase();
    if (id.contains('sword')) {
      icon = Icons.sports_martial_arts;
      color = Colors.blue[200]!;
    } else if (id.contains('pickaxe')) {
      icon = Icons.hardware;
      color = Colors.blue[200]!;
    } else if (id.contains('axe')) {
      icon = Icons.handyman;
      color = Colors.blue[200]!;
    } else if (id.contains('shovel')) {
      icon = Icons.agriculture;
      color = Colors.blue[200]!;
    } else if (id.contains('hoe')) {
      icon = Icons.grass;
      color = Colors.blue[200]!;
    } else if (id.contains('helmet') || id.contains('cap')) {
      icon = Icons.face;
      color = Colors.grey;
    } else if (id.contains('chestplate') || id.contains('tunic')) {
      icon = Icons.accessibility;
      color = Colors.grey;
    } else if (id.contains('leggings') || id.contains('pants')) {
      icon = Icons.airline_seat_legroom_extra;
      color = Colors.grey;
    } else if (id.contains('boots')) {
      icon = Icons.roller_skating;
      color = Colors.grey;
    } else if (id.contains('apple') ||
        id.contains('beef') ||
        id.contains('pork') ||
        id.contains('bread')) {
      icon = Icons.restaurant;
      color = Colors.orange;
    } else if (id.contains('potion')) {
      icon = Icons.science;
      color = Colors.purple;
    } else if (id.contains('block') ||
        id.contains('stone') ||
        id.contains('dirt') ||
        id.contains('planks')) {
      icon = Icons.square;
      color = Colors.brown;
    } else if (id.contains('ore') ||
        id.contains('diamond') ||
        id.contains('iron') ||
        id.contains('gold')) {
      icon = Icons.monetization_on;
      color = Colors.yellow;
    } else if (id.contains('torch')) {
      icon = Icons.light_mode;
      color = Colors.yellow;
    } else if (id.contains('bed')) {
      icon = Icons.bed;
      color = Colors.red;
    } else if (id.contains('book')) {
      icon = Icons.book;
      color = Colors.blue;
    }

    return Icon(icon, color: color, size: 24);
  }

  void _onSlotTap(int slotId, InventoryItem? item) {
    if (item == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.displayName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(item.id, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.redstone),
              title: const Text('Remove Item'),
              onTap: () {
                Navigator.pop(context);
                _removeItem(slotId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeItem(int slotId) async {
    final provider = context.read<RconProvider>();
    String target = 'container.$slotId';

    // Map special slots
    if (slotId == 100) {
      target = 'armor.feet';
    } else if (slotId == 101) {
      target = 'armor.legs';
    } else if (slotId == 102) {
      target = 'armor.chest';
    } else if (slotId == 103) {
      target = 'armor.head';
    } else if (slotId == -106) {
      target = 'weapon.offhand';
    }

    try {
      await provider.sendCommand(
        'item replace entity ${widget.player.name} $target with minecraft:air',
      );
      _refreshInventory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.redstone,
          ),
        );
      }
    }
  }

  Widget _buildAddItemSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: const Border(top: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search items (e.g. diamond_sword)...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          if (_searchQuery.isNotEmpty)
            Container(
              height: 200,
              margin: const EdgeInsets.only(top: 8),
              child: _buildItemResults(),
            ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _showGiveCustomDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Custom/Modded Item'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemResults() {
    // A small subset of items for the demo/example.
    // In a real app, this would be a much larger list.
    final allItems = [
      'minecraft:diamond_sword',
      'minecraft:diamond_pickaxe',
      'minecraft:diamond_axe',
      'minecraft:diamond_shovel',
      'minecraft:diamond_hoe',
      'minecraft:iron_sword',
      'minecraft:iron_pickaxe',
      'minecraft:iron_axe',
      'minecraft:iron_shovel',
      'minecraft:iron_hoe',
      'minecraft:golden_sword',
      'minecraft:golden_pickaxe',
      'minecraft:golden_axe',
      'minecraft:golden_shovel',
      'minecraft:golden_hoe',
      'minecraft:stone_sword',
      'minecraft:stone_pickaxe',
      'minecraft:stone_axe',
      'minecraft:stone_shovel',
      'minecraft:stone_hoe',
      'minecraft:wooden_sword',
      'minecraft:wooden_pickaxe',
      'minecraft:wooden_axe',
      'minecraft:wooden_shovel',
      'minecraft:wooden_hoe',
      'minecraft:netherite_sword',
      'minecraft:netherite_pickaxe',
      'minecraft:netherite_axe',
      'minecraft:netherite_shovel',
      'minecraft:netherite_hoe',
      'minecraft:diamond_helmet',
      'minecraft:diamond_chestplate',
      'minecraft:diamond_leggings',
      'minecraft:diamond_boots',
      'minecraft:iron_helmet',
      'minecraft:iron_chestplate',
      'minecraft:iron_leggings',
      'minecraft:iron_boots',
      'minecraft:golden_helmet',
      'minecraft:golden_chestplate',
      'minecraft:golden_leggings',
      'minecraft:golden_boots',
      'minecraft:chainmail_helmet',
      'minecraft:chainmail_chestplate',
      'minecraft:chainmail_leggings',
      'minecraft:chainmail_boots',
      'minecraft:netherite_helmet',
      'minecraft:netherite_chestplate',
      'minecraft:netherite_leggings',
      'minecraft:netherite_boots',
      'minecraft:stone',
      'minecraft:granite',
      'minecraft:diorite',
      'minecraft:andesite',
      'minecraft:grass_block',
      'minecraft:dirt',
      'minecraft:coarse_dirt',
      'minecraft:cobblestone',
      'minecraft:oak_planks',
      'minecraft:spruce_planks',
      'minecraft:birch_planks',
      'minecraft:jungle_planks',
      'minecraft:acacia_planks',
      'minecraft:dark_oak_planks',
      'minecraft:oak_log',
      'minecraft:spruce_log',
      'minecraft:birch_log',
      'minecraft:jungle_log',
      'minecraft:acacia_log',
      'minecraft:dark_oak_log',
      'minecraft:glass',
      'minecraft:sand',
      'minecraft:gravel',
      'minecraft:gold_ore',
      'minecraft:iron_ore',
      'minecraft:coal_ore',
      'minecraft:diamond_ore',
      'minecraft:lapis_ore',
      'minecraft:emerald_ore',
      'minecraft:redstone_ore',
      'minecraft:torch',
      'minecraft:lantern',
      'minecraft:campfire',
      'minecraft:chest',
      'minecraft:crafting_table',
      'minecraft:furnace',
      'minecraft:ladder',
      'minecraft:cooked_beef',
      'minecraft:cooked_porkchop',
      'minecraft:cooked_chicken',
      'minecraft:cooked_mutton',
      'minecraft:cooked_rabbit',
      'minecraft:cooked_cod',
      'minecraft:cooked_salmon',
      'minecraft:apple',
      'minecraft:golden_apple',
      'minecraft:enchanted_golden_apple',
      'minecraft:bread',
      'minecraft:baked_potato',
      'minecraft:carrot',
      'minecraft:melon_slice',
      'minecraft:diamond',
      'minecraft:iron_ingot',
      'minecraft:gold_ingot',
      'minecraft:netherite_ingot',
      'minecraft:coal',
      'minecraft:charcoal',
      'minecraft:emerald',
      'minecraft:lapis_lazuli',
      'minecraft:redstone',
      'minecraft:stick',
      'minecraft:string',
      'minecraft:feather',
      'minecraft:gunpowder',
      'minecraft:leather',
      'minecraft:paper',
      'minecraft:sugar',
      'minecraft:slime_ball',
      'minecraft:magma_cream',
      'minecraft:ender_pearl',
      'minecraft:blaze_rod',
      'minecraft:ghast_tear',
      'minecraft:shulker_shell',
      'minecraft:bow',
      'minecraft:crossbow',
      'minecraft:arrow',
      'minecraft:shield',
      'minecraft:elytra',
      'minecraft:trident',
      'minecraft:totem_of_undying',
      'minecraft:firework_rocket',
      'minecraft:water_bucket',
      'minecraft:lava_bucket',
      'minecraft:milk_bucket',
      'minecraft:potion',
      'minecraft:splash_potion',
      'minecraft:lingering_potion',
      'minecraft:white_bed',
      'minecraft:red_bed',
      'minecraft:black_bed',
      'minecraft:blue_bed',
    ];

    final filtered = allItems
        .where((i) => i.contains(_searchQuery.toLowerCase()))
        .toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text('No common items found. Try "Add Custom".'),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final id = filtered[index];
        return ListTile(
          title: Text(id.split(':').last.replaceAll('_', ' ')),
          subtitle: Text(id),
          trailing: const Icon(Icons.add),
          onTap: () => _showAddItemDialog(id),
        );
      },
    );
  }

  Future<void> _showAddItemDialog(String itemId) async {
    final amountController = TextEditingController(text: '1');
    final slotController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $itemId'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: slotController,
              decoration: const InputDecoration(
                labelText: 'Slot (Optional)',
                hintText: 'Leave empty for next available',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _addItem(
                itemId,
                int.tryParse(amountController.text) ?? 1,
                int.tryParse(slotController.text),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showGiveCustomDialog() async {
    final idController = TextEditingController();
    final amountController = TextEditingController(text: '1');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: 'Item ID',
                hintText: 'mod:item_id',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _addItem(
                idController.text,
                int.tryParse(amountController.text) ?? 1,
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem(String itemId, int amount, [int? slot]) async {
    final provider = context.read<RconProvider>();
    try {
      if (slot != null) {
        String target = 'container.$slot';
        if (slot == 100) {
          target = 'armor.feet';
        } else if (slot == 101) {
          target = 'armor.legs';
        } else if (slot == 102) {
          target = 'armor.chest';
        } else if (slot == 103) {
          target = 'armor.head';
        } else if (slot == -106) {
          target = 'weapon.offhand';
        }

        await provider.sendCommand(
          'item replace entity ${widget.player.name} $target with $itemId $amount',
        );
      } else {
        await provider.giveItem(widget.player.name, itemId, amount);
      }
      _refreshInventory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.redstone,
          ),
        );
      }
    }
  }
}
