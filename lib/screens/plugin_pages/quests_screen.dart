import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/rcon_provider.dart';
import '../../theme/app_theme.dart';

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
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

  Future<void> _showGiveQuestDialog(BuildContext context) async {
    final playerController = TextEditingController();
    final questController = TextEditingController();
    final provider = context.read<RconProvider>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Give Quest'),
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
              controller: questController,
              decoration: const InputDecoration(
                labelText: 'Quest Name',
                hintText: 'e.g., Tutorial',
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
              if (playerController.text.isNotEmpty && questController.text.isNotEmpty) {
                _runAction(
                  () => provider.sendCommand('questadmin give ${playerController.text} ${questController.text}'),
                  'Quest given to ${playerController.text}',
                );
              }
            },
            child: const Text('Give'),
          ),
        ],
      ),
    );

    playerController.dispose();
    questController.dispose();
  }

  Future<void> _showRemoveQuestDialog(BuildContext context) async {
    final playerController = TextEditingController();
    final questController = TextEditingController();
    final provider = context.read<RconProvider>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Quest'),
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
              controller: questController,
              decoration: const InputDecoration(
                labelText: 'Quest Name',
                hintText: 'e.g., Tutorial',
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
              if (playerController.text.isNotEmpty && questController.text.isNotEmpty) {
                _runAction(
                  () => provider.sendCommand('questadmin remove ${playerController.text} ${questController.text}'),
                  'Quest removed from ${playerController.text}',
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.redstone),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    playerController.dispose();
    questController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<RconProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quests'),
        backgroundColor: AppTheme.gold.withOpacity(0.2),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Admin', icon: Icons.admin_panel_settings, color: AppTheme.gold),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.refresh,
                          label: 'Reload',
                          color: Colors.orange,
                          onTap: () => _runAction(
                            () => provider.sendCommand('questadmin reload'),
                            'Quests reloaded',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.list,
                          label: 'List Quests',
                          color: AppTheme.gold,
                          onTap: () => _runAction(
                            () => provider.sendCommand('quests list'),
                            'Listing quests',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _SectionHeader(title: 'Player Quests', icon: Icons.assignment, color: AppTheme.gold),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.add_task,
                          label: 'Give Quest',
                          color: AppTheme.grassGreen,
                          onTap: () => _showGiveQuestDialog(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.remove_circle,
                          label: 'Remove Quest',
                          color: AppTheme.redstone,
                          onTap: () => _showRemoveQuestDialog(context),
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
