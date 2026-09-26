import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../providers/rcon_provider.dart';
import '../theme/app_theme.dart';
import 'inventory_screen.dart';
import '../widgets/player_timer_panel.dart';
import '../widgets/connection_status_banner.dart';

class PlayerActionsScreen extends StatefulWidget {
  final Player player;

  const PlayerActionsScreen({super.key, required this.player});

  @override
  State<PlayerActionsScreen> createState() => _PlayerActionsScreenState();
}

class _PlayerActionsScreenState extends State<PlayerActionsScreen> {
  bool _isLoading = false;

  Future<bool> _runAction(
    Future<String> Function() action,
    String successMessage,
  ) async {
    if (_isLoading) return false;
    setState(() => _isLoading = true);
    var success = false;

    try {
      final response = await action();
      success = true;
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              response.isEmpty ? successMessage : response,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppTheme.darkGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
    return success;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RconProvider>();
    final playerName = widget.player.name;
    final online = provider.players.any(
      (p) => p.name.toLowerCase() == playerName.toLowerCase(),
    );
    final statusColor = online ? AppTheme.grassGreen : AppTheme.muted;

    final essentials = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: 'Health & Food', icon: Icons.favorite_outline),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                [
                      _ActionCard(
                        icon: Icons.favorite_outline,
                        label: 'Heal',
                        color: AppTheme.redstone,
                        onTap: () => _runAction(
                          () => provider.healPlayer(playerName),
                          'Healed $playerName',
                        ),
                      ),
                      _ActionCard(
                        icon: Icons.restaurant,
                        label: 'Feed',
                        color: AppTheme.gold,
                        onTap: () => _runAction(
                          () => provider.feedPlayer(playerName),
                          'Fed $playerName',
                        ),
                      ),
                      _ActionCard(
                        icon: Icons.shield_outlined,
                        label: 'Invincible',
                        color: AppTheme.diamond,
                        onTap: () => _runAction(
                          () => provider.giveInvincibility(playerName, 1000000),
                          'Gave invincibility',
                        ),
                      ),
                      _ActionCard(
                        icon: Icons.cleaning_services_outlined,
                        label: 'Clear Effects',
                        color: AppTheme.muted,
                        onTap: () => _runAction(
                          () => provider.clearEffects(playerName),
                          'Cleared effects',
                        ),
                      ),
                    ]
                    .map(
                      (card) => SizedBox(
                        width:
                            constraints.maxWidth <
                                272 *
                                        MediaQuery.textScalerOf(
                                          context,
                                        ).scale(1) +
                                    12
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 12) / 2,
                        child: card,
                      ),
                    )
                    .toList(),
          ),
        ),
        const SizedBox(height: 28),
        _SectionHeader(title: 'Game Mode', icon: Icons.sports_esports_outlined),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: GameMode.values
              .map(
                (mode) => _ActionChip(
                  label: mode.displayName,
                  icon: _getGameModeIcon(mode),
                  onTap: () => _runAction(
                    () => provider.setGameMode(playerName, mode),
                    'Set game mode to ${mode.displayName}',
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 28),
        _SectionHeader(title: 'Inventory', icon: Icons.inventory_2_outlined),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            leading: const Icon(
              Icons.inventory_2_outlined,
              color: AppTheme.gold,
            ),
            title: const Text('Manage Inventory'),
            subtitle: const Text(
              'Give items, edit slots and manage equipment.',
            ),
            trailing: const Icon(Icons.arrow_forward, size: 20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InventoryScreen(player: widget.player),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _SectionHeader(title: 'Teleport', icon: Icons.my_location),
        const SizedBox(height: 12),
        _TeleportSection(player: widget.player),
      ],
    );

    final management = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.player.isBot) ...[
          PlayerTimerPanel(playerName: playerName),
          const SizedBox(height: 24),
        ],
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.redstone.withValues(alpha: .25)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(
                  title: 'Moderation',
                  icon: Icons.admin_panel_settings_outlined,
                  color: AppTheme.redstone,
                ),
                const SizedBox(height: 8),
                const Text(
                  'These actions interrupt the player’s session and ask for confirmation.',
                  style: TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.redstone,
                  ),
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(widget.player.isBot ? 'Dismiss bot' : 'Kick'),
                  onPressed: () => _showKickDialog(context, playerName),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.redstone,
                  ),
                  icon: const Icon(Icons.dangerous_outlined, size: 18),
                  label: const Text('Kill Player'),
                  onPressed: () => _confirmAction(
                    context,
                    'Kill Player',
                    'This will kill $playerName. They will respawn at their spawn point.',
                    () => _runAction(
                      () => provider.killPlayer(playerName),
                      'Killed $playerName',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(playerName)),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: AbsorbPointer(
              absorbing: _isLoading,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const ConnectionStatusBanner(),
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: .14),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: widget.player.isBot
                                      ? const Icon(
                                          Icons.smart_toy_outlined,
                                          color: AppTheme.diamond,
                                          size: 28,
                                        )
                                      : Text(
                                          playerName.isEmpty
                                              ? '?'
                                              : playerName[0].toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                            color: statusColor,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        playerName,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            size: 8,
                                            color: statusColor,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              widget.player.isBot
                                                  ? 'Assistant bot • ${widget.player.botOwner}'
                                                  : online
                                                  ? 'Online'
                                                  : 'Offline',
                                              style: const TextStyle(
                                                color: AppTheme.muted,
                                              ),
                                            ),
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
                        const SizedBox(height: 28),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 880) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 5, child: essentials),
                                  const SizedBox(width: 28),
                                  Expanded(flex: 4, child: management),
                                ],
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                essentials,
                                const SizedBox(height: 28),
                                management,
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
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
    final provider = context.read<RconProvider>();
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (_) => _KickDialog(
        playerName: playerName,
        isBot: widget.player.isBot,
        supportsTimers: provider.supportsPlayerTimers,
      ),
    );
    if (result == null || !mounted) return;
    final success = await _runAction(
      () =>
          provider.kickPlayer(playerName, result.$1, lockoutMinutes: result.$2),
      widget.player.isBot ? 'Dismissed $playerName' : 'Kicked $playerName',
    );
    if (success && context.mounted) Navigator.pop(context);
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
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color ?? Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
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
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
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
                  Icon(Icons.info_outline, color: AppTheme.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No other players online to teleport to',
                      style: TextStyle(color: AppTheme.muted),
                    ),
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
                  style: TextStyle(color: AppTheme.muted),
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
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: AppTheme.darkGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error: $e',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.errorContainer,
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

class _KickDialog extends StatefulWidget {
  final String playerName;
  final bool isBot;
  final bool supportsTimers;
  const _KickDialog({
    required this.playerName,
    required this.isBot,
    required this.supportsTimers,
  });
  @override
  State<_KickDialog> createState() => _KickDialogState();
}

class _KickDialogState extends State<_KickDialog> {
  final _reason = TextEditingController(text: 'Time for a break!');
  final _minutes = TextEditingController(text: '0');
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _reason.dispose();
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.isBot
          ? 'Dismiss ${widget.playerName}?'
          : 'Kick ${widget.playerName}?',
    ),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isBot)
              const Text(
                'Remove this assistant bot through its mod. The owner can summon it again.',
              )
            else ...[
              TextFormField(
                controller: _reason,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              const SizedBox(height: 16),
              if (widget.supportsTimers) ...[
                TextFormField(
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Block reconnecting (minutes)',
                    helperText: '0 = kick only; maximum 1440 minutes',
                  ),
                  validator: (text) {
                    final n = int.tryParse(text ?? '');
                    return n == null || n < 0 || n > 1440
                        ? 'Enter 0–1440 whole minutes'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Keep this app running and connected. If it closes, the temporary ban is released when you reconnect.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [0, 2, 5, 10, 30]
                      .map(
                        (n) => ActionChip(
                          label: Text(n == 0 ? 'Kick only' : '$n min'),
                          onPressed: () => setState(() => _minutes.text = '$n'),
                        ),
                      )
                      .toList(),
                ),
              ] else
                const Text(
                  'Connect to the server and wait for saved timers to load.',
                ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, (
              _reason.text,
              widget.isBot || !widget.supportsTimers
                  ? 0
                  : int.parse(_minutes.text),
            ));
          }
        },
        child: Text(widget.isBot ? 'Dismiss bot' : 'Kick'),
      ),
    ],
  );
}
