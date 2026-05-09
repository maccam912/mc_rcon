import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../providers/rcon_provider.dart';
import '../theme/app_theme.dart';
import 'player_actions_screen.dart';

class PlayersScreen extends StatelessWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RconProvider>(
      builder: (context, provider, _) {
        if (provider.players.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_off,
                  size: 64,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 16),
                Text(
                  'No players online',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pull down to refresh',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => provider.refreshPlayers(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.refreshPlayers(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.players.length,
            itemBuilder: (context, index) {
              final player = provider.players[index];
              return _PlayerCard(player: player);
            },
          ),
        );
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final Player player;

  const _PlayerCard({required this.player});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlayerActionsScreen(player: player),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Player avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.grassGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    player.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Player info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Quick actions
              _QuickActionButton(
                icon: Icons.favorite,
                color: AppTheme.redstone,
                tooltip: 'Heal',
                onPressed: () => _quickAction(context, 'heal', player),
              ),
              _QuickActionButton(
                icon: Icons.restaurant,
                color: AppTheme.gold,
                tooltip: 'Feed',
                onPressed: () => _quickAction(context, 'feed', player),
              ),
              _QuickActionButton(
                icon: Icons.shield,
                color: AppTheme.diamond,
                tooltip: 'Invincibility',
                onPressed: () => _quickAction(context, 'invincible', player),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _quickAction(BuildContext context, String action, Player player) async {
    final provider = context.read<RconProvider>();
    String response;

    try {
      switch (action) {
        case 'heal':
          response = await provider.healPlayer(player.name);
          break;
        case 'feed':
          response = await provider.feedPlayer(player.name);
          break;
        case 'invincible':
          response = await provider.giveInvincibility(player.name, 1000000);
          break;
        default:
          return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.isEmpty ? 'Command sent' : response),
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
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
