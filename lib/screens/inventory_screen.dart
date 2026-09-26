import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/item_catalog.dart';
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
  bool _isMutating = false;
  String? _loadError;

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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final data = await context.read<RconProvider>().getPlayerInventory(
        widget.player.name,
      );
      if (!mounted) return;
      setState(() => _items = data.map(InventoryItem.fromNbt).toList());
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Could not load inventory: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = !_isLoading && !_isMutating && _loadError == null;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.player.name}\'s Inventory'),
        actions: [
          IconButton(
            tooltip: 'Refresh inventory',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading || _isMutating ? null : _refreshInventory,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading || _isMutating)
            const LinearProgressIndicator(minHeight: 2),
          if (_loadError != null)
            MaterialBanner(
              content: Text(_loadError!),
              actions: [
                TextButton(
                  onPressed: _isLoading ? null : _refreshInventory,
                  child: const Text('Retry'),
                ),
              ],
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Inventory & equipment',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLoading
                            ? 'Reading inventory from the server…'
                            : '${_items.length} occupied slots · Select a slot to make a change.',
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _inventoryHeading(
                                'Equipment',
                                'Armor & offhand',
                                Icons.shield_outlined,
                              ),
                              const SizedBox(height: 16),
                              _buildArmorAndOffhand(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildMainInventory(),
                      const SizedBox(height: 24),
                      _buildHotbar(),
                      const SizedBox(height: 20),
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            color: AppTheme.muted,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tap an empty slot to fill it, or an item to replace or remove it.',
                              style: TextStyle(
                                color: AppTheme.muted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.all(16),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: canEdit ? () => _showItemPicker() : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Give items'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inventoryHeading(String title, String detail, IconData icon) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Icon(icon, size: 20, color: AppTheme.gold),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              detail,
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildArmorAndOffhand() {
    const slots = {
      103: Icons.face_outlined,
      102: Icons.accessibility,
      101: Icons.airline_seat_legroom_extra,
      100: Icons.roller_skating,
      -106: Icons.front_hand_outlined,
    };
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: slots.entries
          .map(
            (entry) => Column(
              children: [
                _buildSlot(entry.key, entry.value),
                const SizedBox(height: 6),
                Text(
                  _slotLabel(entry.key),
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  Widget _buildMainInventory() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _inventoryHeading('Main Inventory', '27 slots', Icons.grid_view),
      const SizedBox(height: 12),
      _slotGrid(27, 9),
    ],
  );

  Widget _buildHotbar() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _inventoryHeading('Hotbar', '9 quick slots', Icons.view_week_outlined),
      const SizedBox(height: 12),
      _slotGrid(9, 0),
    ],
  );

  Widget _slotGrid(int count, int firstSlot) => LayoutBuilder(
    builder: (context, constraints) => GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            ((constraints.maxWidth + 8) /
                    (48 * MediaQuery.textScalerOf(context).scale(1) + 8))
                .floor()
                .clamp(3, 9),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: count,
      itemBuilder: (context, index) => _buildSlot(index + firstSlot),
    ),
  );

  Widget _buildSlot(int slotId, [IconData? emptyIcon]) {
    final item = _items.where((i) => i.slot == slotId).firstOrNull;
    final label =
        '${_slotLabel(slotId)}: ${item == null ? 'Empty' : '${item.displayName}, ${item.count}'}';
    return Semantics(
      label: label,
      button: true,
      child: Tooltip(
        message: item == null ? label : '$label\n${item.id}',
        child: Material(
          color: item == null ? AppTheme.surface : AppTheme.panel,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: item == null
                  ? AppTheme.border
                  : AppTheme.gold.withValues(alpha: .45),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _isLoading || _isMutating || _loadError != null
                ? null
                : () => _onSlotTap(slotId, item),
            child: SizedBox(
              width: MediaQuery.textScalerOf(context).scale(48),
              height: MediaQuery.textScalerOf(context).scale(48),
              child: Stack(
                children: [
                  Center(
                    child: item == null
                        ? Icon(
                            emptyIcon ?? Icons.add,
                            color: AppTheme.muted.withValues(alpha: .5),
                            size: 20,
                          )
                        : Padding(
                            padding: const EdgeInsets.all(4),
                            child: _getItemIcon(item),
                          ),
                  ),
                  if (slotId >= 0 && slotId < 36)
                    Positioned(
                      top: 4,
                      left: 6,
                      child: Text(
                        '${slotId < 9 ? slotId + 1 : slotId - 8}',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.muted.withValues(alpha: .75),
                        ),
                      ),
                    ),
                  if (item != null && item.count > 1)
                    Positioned(
                      bottom: 4,
                      right: 6,
                      child: Text(
                        '${item.count}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String getEmojiForId(String id) {
    final cleanId = id.toLowerCase().replaceFirst('minecraft:', '');

    // 1. Tools & Weapons
    if (cleanId.contains('sword')) return '🗡️';
    if (cleanId.contains('pickaxe')) return '⛏️';
    if (cleanId.contains('axe') && !cleanId.contains('waxed')) {
      return '🪓'; // Avoid matching waxed copper blocks
    }
    if (cleanId.contains('shovel')) return '🥄';
    if (cleanId.contains('hoe')) return '🌱';
    if (cleanId.contains('crossbow') || cleanId.contains('bow')) return '🏹';
    if (cleanId.contains('arrow')) return '🏹';
    if (cleanId.contains('shield')) return '🛡️';
    if (cleanId.contains('elytra')) return '🪽';
    if (cleanId.contains('trident')) return '🔱';
    if (cleanId.contains('fishing_rod')) return '🎣';
    if (cleanId.contains('shears')) return '✂️';
    if (cleanId.contains('flint_and_steel')) return '🔥';
    if (cleanId.contains('spyglass')) return '🔭';
    if (cleanId.contains('brush')) return '🖌️';

    // 2. Armor
    if (cleanId.contains('helmet') || cleanId.contains('cap')) return '🪖';
    if (cleanId.contains('chestplate') || cleanId.contains('tunic')) {
      return '👕';
    }
    if (cleanId.contains('leggings') || cleanId.contains('pants')) return '👖';
    if (cleanId.contains('boots')) return '🥾';

    // 3. Minerals, Ores, and Blocks
    if (cleanId.contains('diamond')) return '💎';
    if (cleanId.contains('emerald')) return '💚';
    if (cleanId.contains('amethyst')) return '🔮';
    if (cleanId.contains('netherite')) return '🖤';
    if (cleanId.contains('quartz')) return '🤍';
    if (cleanId.contains('lapis')) return '🔵';

    // Redstone blocks vs redstone items
    if (cleanId == 'redstone' || cleanId.contains('redstone_dust')) return '✨';
    if (cleanId.contains('redstone')) return '🔴';

    if (cleanId.contains('gold_ingot') ||
        cleanId.contains('raw_gold') ||
        cleanId.contains('gold_nugget')) {
      return '🧈';
    }
    if (cleanId.contains('gold_block') || cleanId.contains('gold_ore')) {
      return '🟨';
    }
    if (cleanId.contains('iron_ingot') ||
        cleanId.contains('raw_iron') ||
        cleanId.contains('iron_nugget')) {
      return '🩶';
    }
    if (cleanId.contains('iron_block') || cleanId.contains('iron_ore')) {
      return '🪙';
    }
    if (cleanId.contains('copper_ingot') || cleanId.contains('raw_copper')) {
      return '🧡';
    }
    if (cleanId.contains('copper_block') || cleanId.contains('copper_ore')) {
      return '🧱';
    }
    if (cleanId.contains('coal')) return '⬛';

    // 4. Food & Crops
    if (cleanId.contains('golden_apple')) return '🍏';
    if (cleanId.contains('apple')) return '🍎';
    if (cleanId.contains('bread')) return '🍞';
    if (cleanId.contains('cookie')) return '🍪';
    if (cleanId.contains('cake')) return '🎂';
    if (cleanId.contains('pie')) return '🥧';
    if (cleanId.contains('beef') || cleanId.contains('steak')) return '🥩';
    if (cleanId.contains('pork')) return '🥓';
    if (cleanId.contains('chicken')) return '🍗';
    if (cleanId.contains('mutton') || cleanId.contains('meat')) return '🍖';
    if (cleanId.contains('pufferfish')) return '🐡';
    if (cleanId.contains('fish') ||
        cleanId.contains('cod') ||
        cleanId.contains('salmon') ||
        cleanId.contains('tropical')) {
      return '🐟';
    }
    if (cleanId.contains('honey_bottle') || cleanId.contains('honey')) {
      return '🍯';
    }
    if (cleanId.contains('sugar')) return '🧂';
    if (cleanId.contains('egg')) return '🥚';
    if (cleanId.contains('milk_bucket') || cleanId.contains('milk')) {
      return '🥛';
    }
    if (cleanId.contains('melon')) return '🍉';
    if (cleanId.contains('carrot')) return '🥕';
    if (cleanId.contains('potato')) return '🥔';
    if (cleanId.contains('beetroot')) return '🍠';
    if (cleanId.contains('berry') || cleanId.contains('berries')) return '🍒';
    if (cleanId.contains('soup') || cleanId.contains('stew')) return '🥣';
    if (cleanId.contains('seeds')) return '🌾';

    // 5. Utility Blocks & Furniture
    if (cleanId.contains('ender_chest')) return '🔮';
    if (cleanId.contains('chest')) return '🧰';
    if (cleanId.contains('barrel')) return '📦';
    if (cleanId.contains('crafting_table')) return '🛠️';
    if (cleanId.contains('furnace') ||
        cleanId.contains('smoker') ||
        cleanId.contains('blast_furnace')) {
      return '🔥';
    }
    if (cleanId.contains('brewing_stand') || cleanId.contains('potion')) {
      return '🧪';
    }
    if (cleanId.contains('cauldron')) return '🍵';
    if (cleanId.contains('campfire')) return '🔥';
    if (cleanId.contains('anvil')) return '🔨';
    if (cleanId.contains('bell')) return '🔔';
    if (cleanId.contains('bed')) return '🛏️';
    if (cleanId.contains('door') || cleanId.contains('trapdoor')) return '🚪';
    if (cleanId.contains('ladder') || cleanId.contains('scaffolding')) {
      return '🪜';
    }
    if (cleanId.contains('lantern') || cleanId.contains('torch')) return '🕯️';
    if (cleanId.contains('painting') || cleanId.contains('item_frame')) {
      return '🖼️';
    }
    if (cleanId.contains('piston')) return '⚙️';
    if (cleanId.contains('sponge')) return '🧽';
    if (cleanId.contains('tnt') || cleanId.contains('dynamite')) return '🧨';
    if (cleanId.contains('spawner')) return '💀';
    if (cleanId.contains('glass')) return '🪟';
    if (cleanId.contains('ice')) return '🧊';
    if (cleanId.contains('snow')) return '❄️';

    // 6. Natural & Building Blocks
    if (cleanId.contains('grass_block') || cleanId.contains('moss_block')) {
      return '🌱';
    }
    if (cleanId.contains('dirt') ||
        cleanId.contains('podzol') ||
        cleanId.contains('mycelium') ||
        cleanId.contains('mud')) {
      return '🟫';
    }
    if (cleanId.contains('cobblestone')) return '🧱';
    if (cleanId.contains('stone') ||
        cleanId.contains('granite') ||
        cleanId.contains('diorite') ||
        cleanId.contains('andesite') ||
        cleanId.contains('deepslate') ||
        cleanId.contains('basalt') ||
        cleanId.contains('blackstone') ||
        cleanId.contains('tuff') ||
        cleanId.contains('calcite') ||
        cleanId.contains('dripstone')) {
      return '🪨';
    }
    if (cleanId.contains('bedrock')) return '🖤';
    if (cleanId.contains('sand')) return '🏖️';
    if (cleanId.contains('gravel')) return '🌫️';
    if (cleanId.contains('obsidian')) return '💜';
    if (cleanId.contains('clay') ||
        cleanId.contains('terracotta') ||
        cleanId.contains('concrete') ||
        cleanId.contains('brick')) {
      return '🧱';
    }
    if (cleanId.contains('wool') || cleanId.contains('carpet')) return '🧶';
    if (cleanId.contains('log') ||
        cleanId.contains('wood') ||
        cleanId.contains('stem') ||
        cleanId.contains('stripped') ||
        cleanId.contains('planks')) {
      return '🪵';
    }
    if (cleanId.contains('sapling')) return '🌱';
    if (cleanId.contains('leaves')) return '🍃';
    if (cleanId.contains('dandelion') ||
        cleanId.contains('daisy') ||
        cleanId.contains('sunflower')) {
      return '🌼';
    }
    if (cleanId.contains('poppy') ||
        cleanId.contains('rose') ||
        cleanId.contains('tulip')) {
      return '🌹';
    }
    if (cleanId.contains('orchid') ||
        cleanId.contains('allium') ||
        cleanId.contains('cornflower') ||
        cleanId.contains('lilac')) {
      return '🪻';
    }
    if (cleanId.contains('flower') ||
        cleanId.contains('bluet') ||
        cleanId.contains('peony')) {
      return '🌸';
    }
    if (cleanId.contains('mushroom') || cleanId.contains('fungus')) return '🍄';
    if (cleanId.contains('cactus')) return '🌵';
    if (cleanId.contains('bamboo')) return '🎍';
    if (cleanId.contains('sugar_cane')) return '🎋';
    if (cleanId.contains('vine') || cleanId.contains('vines')) return '🌿';
    if (cleanId.contains('lily')) return '🪷';
    if (cleanId.contains('netherrack') || cleanId.contains('crimson')) {
      return '🟥';
    }
    if (cleanId.contains('soul_sand') || cleanId.contains('soul_soil')) {
      return '🟫';
    }
    if (cleanId.contains('purpur')) return '🟪';
    if (cleanId.contains('end_stone')) return '🟨';

    // 7. Items & Drops
    if (cleanId.contains('totem')) return '👼';
    if (cleanId.contains('star')) return '⭐';
    if (cleanId.contains('pearl') || cleanId.contains('eye')) return '🔮';
    if (cleanId.contains('powder') || cleanId.contains('dust')) return '✨';
    if (cleanId.contains('rod') || cleanId.contains('stick')) return '🥢';
    if (cleanId.contains('tear')) return '💧';
    if (cleanId.contains('shell')) return '🐚';
    if (cleanId.contains('bone')) return '🦴';
    if (cleanId.contains('gunpowder')) return '💣';
    if (cleanId.contains('rocket') || cleanId.contains('firework')) return '🚀';
    if (cleanId.contains('paper') || cleanId.contains('map')) return '📄';
    if (cleanId.contains('book')) return '📖';
    if (cleanId.contains('feather')) return '🪶';
    if (cleanId.contains('leather')) return '💼';
    if (cleanId.contains('slime')) return '🟢';
    if (cleanId.contains('string')) return '🧵';
    if (cleanId.contains('bucket')) return '🪣';
    if (cleanId.contains('disc') || cleanId.contains('music')) return '💿';
    if (cleanId.contains('saddle')) return '🏇';
    if (cleanId.contains('lead')) return '🪢';
    if (cleanId.contains('tag')) return '🏷️';

    return '❓';
  }

  Widget _getItemIcon(InventoryItem item) =>
      Text(getEmojiForId(item.id), style: const TextStyle(fontSize: 20));

  void _showItemPicker({int? slot, String? itemId}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => FractionallySizedBox(
        heightFactor: .95,
        child: _GiveItemSheet(
          playerName: widget.player.name,
          initialSlot: slot,
          initialItem: itemId,
          onGive: _addItem,
        ),
      ),
    );
  }

  void _onSlotTap(int slotId, InventoryItem? item) {
    if (item == null) {
      _showItemPicker(slot: slotId);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.displayName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('${item.id} · ${item.count} items · ${_slotLabel(slotId)}'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Replace this slot'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showItemPicker(slot: slotId, itemId: item.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.redstone),
              title: const Text('Remove this stack'),
              onTap: () {
                Navigator.pop(sheetContext);
                _removeItem(slotId, item.displayName);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _feedback(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: error
            ? Theme.of(context).colorScheme.errorContainer
            : AppTheme.darkGreen,
      ),
    );
  }

  Future<void> _removeItem(int slot, String name) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      await context.read<RconProvider>().removeItem(widget.player.name, slot);
      _feedback('Removed $name from ${_slotLabel(slot)}.');
      await _refreshInventory();
    } catch (e) {
      _feedback('Could not remove item: $e', error: true);
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _addItem(String itemId, int amount, int? slot) async {
    if (_isMutating) {
      throw StateError('Another inventory change is still running.');
    }
    setState(() => _isMutating = true);
    final provider = context.read<RconProvider>();
    try {
      if (slot == null) {
        await provider.giveItem(widget.player.name, itemId, amount);
      } else {
        await provider.setItem(widget.player.name, slot, itemId, amount);
      }
      final name = InventoryItem(
        id: itemId,
        count: amount,
        slot: slot ?? 0,
      ).displayName;
      _feedback(
        slot == null
            ? 'Gave $amount × $name to ${widget.player.name}.'
            : 'Set ${_slotLabel(slot)} to $amount × $name.',
      );
      await _refreshInventory();
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }
}

String _slotLabel(int slot) => switch (slot) {
  100 => 'Feet',
  101 => 'Legs',
  102 => 'Chest',
  103 => 'Head',
  -106 => 'Offhand',
  < 9 => 'Hotbar ${slot + 1}',
  _ => 'Inventory ${slot - 8}',
};

class _GiveItemSheet extends StatefulWidget {
  final String playerName;
  final int? initialSlot;
  final String? initialItem;
  final Future<void> Function(String, int, int?) onGive;

  const _GiveItemSheet({
    required this.playerName,
    this.initialSlot,
    this.initialItem,
    required this.onGive,
  });

  @override
  State<_GiveItemSheet> createState() => _GiveItemSheetState();
}

class _GiveItemSheetState extends State<_GiveItemSheet> {
  final _search = TextEditingController();
  final _amount = TextEditingController(text: '1');
  final _selectionScroll = ScrollController();
  String _category = 'Common';
  String? _selectedId;
  late int? _slot;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _slot = widget.initialSlot;
    _selectedId = widget.initialItem;
  }

  @override
  void dispose() {
    _search.dispose();
    _amount.dispose();
    _selectionScroll.dispose();
    super.dispose();
  }

  void _select(String id) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedId = id;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amount.text);
    if (_selectedId == null || amount == null || amount < 1 || amount > 2304) {
      setState(() => _error = 'Choose an item and an amount from 1 to 2304.');
      if (_selectionScroll.hasClients) _selectionScroll.jumpTo(0);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onGive(_selectedId!, amount, _slot);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'The server did not confirm the change: $e');
        if (_selectionScroll.hasClients) _selectionScroll.jumpTo(0);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _slot == null ? 'Give items' : 'Replace item',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  tooltip: 'Close item picker',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: _selectedId == null ? _buildSearch() : _buildSelection(),
            ),
            if (_selectedId != null) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(
                  _busy
                      ? 'Sending…'
                      : '${_slot == null ? 'Give' : 'Replace with'} ${_amount.text} ${_amount.text == '1' ? 'item' : 'items'}',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    final results = ItemCatalog.search(
      _search.text,
      selectedCategory: _category,
    );
    final customId = ItemCatalog.normalizeId(_search.text);
    final showCustom = customId != null && !results.contains(customId);
    return Column(
      children: [
        TextField(
          controller: _search,
          decoration: InputDecoration(
            labelText: 'Search by name or item ID',
            hintText: 'diamond sword or mod:item_id',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _search.clear();
                      setState(() {});
                    },
                  ),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {
            if (_category == 'Common') _category = 'All';
          }),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ItemCatalog.categories
                .map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: results.isEmpty && !showCustom
              ? const SingleChildScrollView(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No matching items. Enter a valid namespaced ID, such as mod:item_id.',
                  ),
                )
              : ListView.builder(
                  itemCount: results.length + (showCustom ? 1 : 0),
                  itemBuilder: (context, index) {
                    final custom = index == results.length;
                    final id = custom ? customId! : results[index];
                    final name = InventoryItem(
                      id: id,
                      count: 1,
                      slot: 0,
                    ).displayName;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      leading: Text(
                        _InventoryScreenState.getEmojiForId(id),
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(custom ? 'Use custom ID: $id' : name),
                      subtitle: Text(
                        custom ? 'The server will check this item ID.' : id,
                      ),
                      onTap: () => _select(id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSelection() {
    return SingleChildScrollView(
      controller: _selectionScroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: AppTheme.redstone),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            _InventoryScreenState.getEmojiForId(_selectedId!),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 48),
          ),
          Text(
            InventoryItem(id: _selectedId!, count: 1, slot: 0).displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            _selectedId!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TextButton.icon(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _selectedId = null;
                    _error = null;
                  }),
            icon: const Icon(Icons.search),
            label: const Text('Choose a different item'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Amount',
              helperText: '1–2304 items',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          Wrap(
            spacing: 8,
            children: [1, 16, 64]
                .map(
                  (amount) => ChoiceChip(
                    label: Text('$amount'),
                    selected: _amount.text == '$amount',
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _amount.text = '$amount'),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _slot ?? -1,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Destination',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: -1,
                child: Text('Next available space'),
              ),
              ...[...List.generate(36, (i) => i), 103, 102, 101, 100, -106].map(
                (slot) => DropdownMenuItem(
                  value: slot,
                  child: Text(_slotLabel(slot)),
                ),
              ),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _slot = value == -1 ? null : value),
          ),
          const SizedBox(height: 8),
          Text(
            _slot == null
                ? 'If the inventory is full, Minecraft may drop excess items nearby.'
                : 'This replaces everything currently in ${_slotLabel(_slot!)}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
