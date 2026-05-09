import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/rcon_provider.dart';
import '../../theme/app_theme.dart';

class MultiverseScreen extends StatefulWidget {
  const MultiverseScreen({super.key});

  @override
  State<MultiverseScreen> createState() => _MultiverseScreenState();
}

class _MultiverseScreenState extends State<MultiverseScreen> {
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

  Future<void> _showTeleportDialog(BuildContext context) async {
    final playerController = TextEditingController();
    final worldController = TextEditingController();
    final provider = context.read<RconProvider>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Teleport to World'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: playerController,
              decoration: const InputDecoration(
                labelText: 'Player Name',
                hintText: 'e.g., Steve',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: worldController,
              decoration: const InputDecoration(
                labelText: 'World Name',
                hintText: 'e.g., world_nether',
              ),
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
              if (playerController.text.isNotEmpty && worldController.text.isNotEmpty) {
                _runAction(
                  () => provider.sendCommand('mv tp ${playerController.text} ${worldController.text}'),
                  'Teleported ${playerController.text} to ${worldController.text}',
                );
              }
            },
            child: const Text('Teleport'),
          ),
        ],
      ),
    );

    playerController.dispose();
    worldController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<RconProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiverse-Core'),
        backgroundColor: AppTheme.enderPurple.withOpacity(0.2),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Information', icon: Icons.info, color: AppTheme.enderPurple),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.list,
                          label: 'List Worlds',
                          color: AppTheme.enderPurple,
                          onTap: () => _runAction(
                            () => provider.sendCommand('mv list'),
                            'Listing worlds',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.people,
                          label: 'Who',
                          color: AppTheme.enderPurple,
                          onTap: () => _runAction(
                            () => provider.sendCommand('mv who'),
                            'Listing players per world',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _SectionHeader(title: 'Teleport', icon: Icons.flight_takeoff, color: AppTheme.enderPurple),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.swap_horiz,
                          label: 'TP to World',
                          color: Colors.blue,
                          onTap: () => _showTeleportDialog(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.home,
                          label: 'Spawn',
                          color: Colors.blue,
                          onTap: () => _runAction(
                            () => provider.sendCommand('mv spawn'),
                            'Teleported to spawn',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _SectionHeader(title: 'Management', icon: Icons.settings, color: AppTheme.enderPurple),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.refresh,
                          label: 'Reload',
                          color: Colors.orange,
                          onTap: () => _runAction(
                            () => provider.sendCommand('mv reload'),
                            'Multiverse reloaded',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[400],
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
