import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/rcon_provider.dart';
import '../../theme/app_theme.dart';

class MythicMobsScreen extends StatefulWidget {
  const MythicMobsScreen({super.key});

  @override
  State<MythicMobsScreen> createState() => _MythicMobsScreenState();
}

class _MythicMobsScreenState extends State<MythicMobsScreen> {
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

  Future<void> _showSpawnDialog(BuildContext context) async {
    final mobController = TextEditingController();
    final amountController = TextEditingController(text: '1');
    final provider = context.read<RconProvider>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spawn Mob'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: mobController,
              decoration: const InputDecoration(
                labelText: 'Mob Name',
                hintText: 'e.g., SkeletalKnight',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '1',
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
              if (mobController.text.isNotEmpty) {
                final amount = amountController.text.isEmpty ? '1' : amountController.text;
                _runAction(
                  () => provider.sendCommand('mm mobs spawn ${mobController.text} $amount'),
                  'Spawned ${mobController.text}',
                );
              }
            },
            child: const Text('Spawn'),
          ),
        ],
      ),
    );

    mobController.dispose();
    amountController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<RconProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MythicMobs'),
        backgroundColor: AppTheme.redstone.withOpacity(0.2),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'General', icon: Icons.settings, color: AppTheme.redstone),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.refresh,
                          label: 'Reload',
                          color: Colors.orange,
                          onTap: () => _runAction(
                            () => provider.sendCommand('mm reload'),
                            'MythicMobs reloaded',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.save,
                          label: 'Save',
                          color: AppTheme.grassGreen,
                          onTap: () => _runAction(
                            () => provider.sendCommand('mm save'),
                            'MythicMobs saved',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _SectionHeader(title: 'Mobs', icon: Icons.pets, color: AppTheme.redstone),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.list,
                          label: 'List Mobs',
                          color: AppTheme.redstone,
                          onTap: () => _runAction(
                            () => provider.sendCommand('mm mobs list'),
                            'Listing mobs',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.add_circle,
                          label: 'Spawn Mob',
                          color: AppTheme.redstone,
                          onTap: () => _showSpawnDialog(context),
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
