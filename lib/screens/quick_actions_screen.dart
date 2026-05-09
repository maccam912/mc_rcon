import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rcon_provider.dart';
import '../theme/app_theme.dart';

class QuickActionsScreen extends StatefulWidget {
  const QuickActionsScreen({super.key});

  @override
  State<QuickActionsScreen> createState() => _QuickActionsScreenState();
}

class _QuickActionsScreenState extends State<QuickActionsScreen> {
  bool _isLoading = false;

  Future<void> _runAction(Future<String> Function() action, String successMessage) async {
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

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time controls
                _SectionHeader(title: 'Time', icon: Icons.schedule),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.wb_sunny,
                        label: 'Day',
                        color: AppTheme.gold,
                        onTap: () => _runAction(
                          () => provider.setTime('day'),
                          'Set time to day',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.nightlight,
                        label: 'Night',
                        color: AppTheme.enderPurple,
                        onTap: () => _runAction(
                          () => provider.setTime('night'),
                          'Set time to night',
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
                        icon: Icons.wb_twilight,
                        label: 'Noon',
                        color: Colors.orange,
                        onTap: () => _runAction(
                          () => provider.setTime('noon'),
                          'Set time to noon',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.dark_mode,
                        label: 'Midnight',
                        color: Colors.indigo,
                        onTap: () => _runAction(
                          () => provider.setTime('midnight'),
                          'Set time to midnight',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Weather controls
                _SectionHeader(title: 'Weather', icon: Icons.cloud),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.wb_sunny,
                        label: 'Clear',
                        color: AppTheme.gold,
                        onTap: () => _runAction(
                          () => provider.setWeather('clear'),
                          'Set weather to clear',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.water_drop,
                        label: 'Rain',
                        color: Colors.blue,
                        onTap: () => _runAction(
                          () => provider.setWeather('rain'),
                          'Set weather to rain',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.flash_on,
                        label: 'Thunder',
                        color: Colors.yellow,
                        onTap: () => _runAction(
                          () => provider.setWeather('thunder'),
                          'Set weather to thunder',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Broadcast message
                _SectionHeader(title: 'Broadcast', icon: Icons.campaign),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick announcements:',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _BroadcastChip(
                              label: 'Dinner time!',
                              onTap: () => _runAction(
                                () => provider.broadcastMessage('Dinner time! Come eat!'),
                                'Broadcast sent',
                              ),
                            ),
                            _BroadcastChip(
                              label: '5 min warning',
                              onTap: () => _runAction(
                                () => provider.broadcastMessage('5 minutes until shutdown!'),
                                'Broadcast sent',
                              ),
                            ),
                            _BroadcastChip(
                              label: 'Bedtime soon',
                              onTap: () => _runAction(
                                () => provider.broadcastMessage('Bedtime in 10 minutes!'),
                                'Broadcast sent',
                              ),
                            ),
                            _BroadcastChip(
                              label: 'Shutting down',
                              onTap: () => _runAction(
                                () => provider.broadcastMessage('Server shutting down NOW!'),
                                'Broadcast sent',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _showBroadcastDialog(context),
                          icon: const Icon(Icons.edit),
                          label: const Text('Custom Message'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // All Players actions
                _SectionHeader(title: 'All Players', icon: Icons.group),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.favorite,
                        label: 'Heal All',
                        color: AppTheme.redstone,
                        onTap: () => _runAction(
                          () => provider.sendCommand('effect give @a minecraft:instant_health 1 10'),
                          'Healed all players',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.restaurant,
                        label: 'Feed All',
                        color: AppTheme.gold,
                        onTap: () => _runAction(
                          () => provider.sendCommand('effect give @a minecraft:saturation 1 20'),
                          'Fed all players',
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
                        label: 'Invincible All 60s',
                        color: AppTheme.diamond,
                        onTap: () => _runAction(
                          () => provider.sendCommand('effect give @a minecraft:resistance 60 255'),
                          'All players invincible',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.cleaning_services,
                        label: 'Clear All Effects',
                        color: Colors.grey,
                        onTap: () => _runAction(
                          () => provider.sendCommand('effect clear @a'),
                          'Cleared all effects',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Difficulty
                _SectionHeader(title: 'Difficulty', icon: Icons.fitness_center),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DifficultyChip(
                      label: 'Peaceful',
                      difficulty: 'peaceful',
                      color: AppTheme.grassGreen,
                      onRun: _runAction,
                    ),
                    _DifficultyChip(
                      label: 'Easy',
                      difficulty: 'easy',
                      color: Colors.lightGreen,
                      onRun: _runAction,
                    ),
                    _DifficultyChip(
                      label: 'Normal',
                      difficulty: 'normal',
                      color: Colors.orange,
                      onRun: _runAction,
                    ),
                    _DifficultyChip(
                      label: 'Hard',
                      difficulty: 'hard',
                      color: AppTheme.redstone,
                      onRun: _runAction,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Server controls
                _SectionHeader(title: 'Server', icon: Icons.dns, color: AppTheme.redstone),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.save,
                        label: 'Save World',
                        color: AppTheme.grassGreen,
                        onTap: () => _runAction(
                          () => provider.sendCommand('save-all'),
                          'World saved',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.power_settings_new,
                        label: 'Stop Server',
                        color: AppTheme.redstone,
                        onTap: () => _confirmServerStop(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
  }

  Future<void> _showBroadcastDialog(BuildContext context) async {
    final messageController = TextEditingController();
    final provider = context.read<RconProvider>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Broadcast Message'),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(
            labelText: 'Message',
            hintText: 'Type your announcement...',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (messageController.text.isNotEmpty) {
                _runAction(
                  () => provider.broadcastMessage(messageController.text),
                  'Broadcast sent',
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );

    messageController.dispose();
  }

  Future<void> _confirmServerStop(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Server'),
        content: const Text(
          'This will stop the Minecraft server completely. All players will be disconnected.\n\n'
          'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.redstone),
            child: const Text('Stop Server'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<RconProvider>();
      await _runAction(
        () => provider.sendCommand('stop'),
        'Server stopping...',
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? color;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.color,
  });

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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BroadcastChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BroadcastChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.send, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final String label;
  final String difficulty;
  final Color color;
  final Future<void> Function(Future<String> Function(), String) onRun;

  const _DifficultyChip({
    required this.label,
    required this.difficulty,
    required this.color,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(Icons.circle, size: 12, color: color),
      label: Text(label),
      onPressed: () {
        final provider = context.read<RconProvider>();
        onRun(
          () => provider.sendCommand('difficulty $difficulty'),
          'Set difficulty to $label',
        );
      },
    );
  }
}
