import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../providers/rcon_provider.dart';
import '../theme/app_theme.dart';
import 'inventory_screen.dart';

class PlayerActionsScreen extends StatefulWidget {
  final Player player;

  const PlayerActionsScreen({super.key, required this.player});

  @override
  State<PlayerActionsScreen> createState() => _PlayerActionsScreenState();
}

class _PlayerActionsScreenState extends State<PlayerActionsScreen> {
  bool _isLoading = false;

  Future<void> _runAction(
    Future<String> Function() action,
    String successMessage,
  ) async {
    setState(() => _isLoading = true);

    try {
      final response = await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.isEmpty ? successMessage : response),
            backgroundColor: AppTheme.grassGreen,
          ),
        );
      }
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

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<RconProvider>();
    final playerName = widget.player.name;

    return Scaffold(
      appBar: AppBar(title: Text(playerName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Player header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppTheme.grassGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                playerName[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  playerName,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.grassGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Online',
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Health & Food section
                  _SectionHeader(title: 'Health & Food', icon: Icons.favorite),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.favorite,
                          label: 'Heal',
                          color: AppTheme.redstone,
                          onTap: () => _runAction(
                            () => provider.healPlayer(playerName),
                            'Healed $playerName',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.restaurant,
                          label: 'Feed',
                          color: AppTheme.gold,
                          onTap: () => _runAction(
                            () => provider.feedPlayer(playerName),
                            'Fed $playerName',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.shield,
                          label: 'Invincible',
                          color: AppTheme.diamond,
                          onTap: () => _runAction(
                            () =>
                                provider.giveInvincibility(playerName, 1000000),
                            'Gave invincibility',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.cleaning_services,
                          label: 'Clear Effects',
                          color: Colors.grey,
                          onTap: () => _runAction(
                            () => provider.clearEffects(playerName),
                            'Cleared effects',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Game Mode section
                  _SectionHeader(title: 'Game Mode', icon: Icons.gamepad),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: GameMode.values.map((mode) {
                      return _ActionChip(
                        label: mode.displayName,
                        icon: _getGameModeIcon(mode),
                        onTap: () => _runAction(
                          () => provider.setGameMode(playerName, mode),
                          'Set game mode to ${mode.displayName}',
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Teleport section
                  _SectionHeader(title: 'Teleport', icon: Icons.my_location),
                  const SizedBox(height: 12),
                  _TeleportSection(player: widget.player),
                  const SizedBox(height: 24),

                  // Items section
                  _SectionHeader(title: 'Give Items', icon: Icons.inventory_2),
                  const SizedBox(height: 12),
                  _GiveItemsSection(playerName: playerName),
                  const SizedBox(height: 24),

                  // XP section
                  _SectionHeader(title: 'Experience', icon: Icons.auto_awesome),
                  const SizedBox(height: 12),
                  _XpSection(playerName: playerName),
                  const SizedBox(height: 24),

                  // Danger Zone
                  _SectionHeader(
                    title: 'Danger Zone',
                    icon: Icons.warning,
                    color: AppTheme.redstone,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.inventory_2,
                          label: 'Manage Inventory',
                          color: AppTheme.gold,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  InventoryScreen(player: widget.player),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.logout,
                          label: 'Kick',
                          color: AppTheme.redstone,
                          onTap: () => _showKickDialog(context, playerName),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _ActionCard(
                      icon: Icons.dangerous,
                      label: 'Kill Player',
                      color: Colors.red[900]!,
                      onTap: () => _confirmAction(
                        context,
                        'Kill Player',
                        'This will kill $playerName. They will respawn at their spawn point.',
                        () => _runAction(
                          () => provider.killPlayer(playerName),
                          'Killed $playerName',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  IconData _getGameModeIcon(GameMode mode) {
    switch (mode) {
      case GameMode.survival:
        return Icons.grass;
      case GameMode.creative:
        return Icons.construction;
      case GameMode.adventure:
        return Icons.explore;
      case GameMode.spectator:
        return Icons.visibility;
    }
  }

  Future<void> _confirmAction(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.redstone),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onConfirm();
    }
  }

  Future<void> _showKickDialog(BuildContext context, String playerName) async {
    final reasonController = TextEditingController(text: 'Time out!');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kick Player'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kick $playerName from the server?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.redstone),
            child: const Text('Kick'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<RconProvider>();
      await _runAction(
        () => provider.kickPlayer(playerName, reasonController.text),
        'Kicked $playerName',
      );
      if (mounted) {
        Navigator.pop(context);
        provider.refreshPlayers();
      }
    }

    reasonController.dispose();
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? color;

  const _SectionHeader({required this.title, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color ?? AppTheme.grassGreen),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color ?? Colors.grey[400],
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _TeleportSection extends StatelessWidget {
  final Player player;

  const _TeleportSection({required this.player});

  @override
  Widget build(BuildContext context) {
    return Consumer<RconProvider>(
      builder: (context, provider, _) {
        final otherPlayers = provider.players
            .where((p) => p.name != player.name)
            .toList();

        if (otherPlayers.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[500]),
                  const SizedBox(width: 12),
                  Text(
                    'No other players online to teleport to',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teleport ${player.name} to:',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: otherPlayers.map((other) {
                    return ActionChip(
                      avatar: const Icon(Icons.person, size: 18),
                      label: Text(other.name),
                      onPressed: () async {
                        try {
                          final response = await provider.teleportPlayerTo(
                            player.name,
                            other.name,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  response.isEmpty
                                      ? 'Teleported ${player.name} to ${other.name}'
                                      : response,
                                ),
                                backgroundColor: AppTheme.grassGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppTheme.redstone,
                              ),
                            );
                          }
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GiveItemsSection extends StatelessWidget {
  final String playerName;

  const _GiveItemsSection({required this.playerName});

  static const _commonItems = [
    ('Diamond Sword', 'minecraft:diamond_sword', Icons.sports_martial_arts),
    ('Diamond Pickaxe', 'minecraft:diamond_pickaxe', Icons.hardware),
    ('Cooked Beef', 'minecraft:cooked_beef', Icons.lunch_dining),
    ('Golden Apple', 'minecraft:golden_apple', Icons.apple),
    ('Torch', 'minecraft:torch', Icons.light_mode),
    ('Ender Pearl', 'minecraft:ender_pearl', Icons.circle),
    ('Bow', 'minecraft:bow', Icons.architecture),
    ('Arrow', 'minecraft:arrow', Icons.arrow_forward),
    ('Shield', 'minecraft:shield', Icons.shield),
    ('Bed', 'minecraft:red_bed', Icons.bed),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick give (x1):', style: TextStyle(color: Colors.grey[400])),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonItems.map((item) {
                return ActionChip(
                  avatar: Icon(item.$3, size: 18),
                  label: Text(item.$1),
                  onPressed: () => _giveItem(context, item.$2, 1),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _showCustomItemDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Give Custom Item'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _giveItem(BuildContext context, String item, int amount) async {
    final provider = context.read<RconProvider>();
    try {
      final response = await provider.giveItem(playerName, item, amount);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.isEmpty ? 'Gave item' : response),
            backgroundColor: AppTheme.grassGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.redstone,
          ),
        );
      }
    }
  }

  Future<void> _showCustomItemDialog(BuildContext context) async {
    final itemController = TextEditingController();
    final amountController = TextEditingController(text: '1');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Give Custom Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: itemController,
              decoration: const InputDecoration(
                labelText: 'Item ID',
                hintText: 'e.g., minecraft:diamond',
              ),
            ),
            const SizedBox(height: 12),
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
              final amount = int.tryParse(amountController.text) ?? 1;
              _giveItem(context, itemController.text, amount);
            },
            child: const Text('Give'),
          ),
        ],
      ),
    );

    itemController.dispose();
    amountController.dispose();
  }
}

class _XpSection extends StatelessWidget {
  final String playerName;

  const _XpSection({required this.playerName});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick XP:', style: TextStyle(color: Colors.grey[400])),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _XpChip(playerName: playerName, levels: 5),
                _XpChip(playerName: playerName, levels: 10),
                _XpChip(playerName: playerName, levels: 30),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _XpChip extends StatelessWidget {
  final String playerName;
  final int levels;

  const _XpChip({required this.playerName, required this.levels});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.auto_awesome, size: 18, color: AppTheme.gold),
      label: Text('+$levels levels'),
      onPressed: () async {
        final provider = context.read<RconProvider>();
        try {
          final response = await provider.sendCommand(
            'xp add $playerName $levels levels',
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  response.isEmpty ? 'Added $levels XP levels' : response,
                ),
                backgroundColor: AppTheme.grassGreen,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: AppTheme.redstone,
              ),
            );
          }
        }
      },
    );
  }
}
