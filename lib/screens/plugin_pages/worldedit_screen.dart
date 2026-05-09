import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/rcon_provider.dart';
import '../../theme/app_theme.dart';

class WorldEditScreen extends StatefulWidget {
  const WorldEditScreen({super.key});

  @override
  State<WorldEditScreen> createState() => _WorldEditScreenState();
}

class _WorldEditScreenState extends State<WorldEditScreen> {
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

  Future<void> _showSetBlockDialog(BuildContext context) async {
    final blockController = TextEditingController();
    final provider = context.read<RconProvider>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Block'),
        content: TextField(
          controller: blockController,
          decoration: const InputDecoration(
            labelText: 'Block Type',
            hintText: 'e.g., stone, diamond_block',
          ),
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
              if (blockController.text.isNotEmpty) {
                _runAction(
                  () => provider.sendCommand('//set ${blockController.text}'),
                  'Selection set to ${blockController.text}',
                );
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );

    blockController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<RconProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('WorldEdit'),
        backgroundColor: Colors.amber.withOpacity(0.2),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Tools', icon: Icons.construction, color: Colors.amber),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.straighten,
                          label: 'Get Wand',
                          color: Colors.amber,
                          onTap: () => _runAction(
                            () => provider.sendCommand('//wand'),
                            'Wand given',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _SectionHeader(title: 'History', icon: Icons.history, color: Colors.amber),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.undo,
                          label: 'Undo',
                          color: Colors.orange,
                          onTap: () => _runAction(
                            () => provider.sendCommand('//undo'),
                            'Action undone',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.redo,
                          label: 'Redo',
                          color: Colors.orange,
                          onTap: () => _runAction(
                            () => provider.sendCommand('//redo'),
                            'Action redone',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _SectionHeader(title: 'Clipboard', icon: Icons.content_copy, color: Colors.amber),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.content_copy,
                          label: 'Copy',
                          color: Colors.blue,
                          onTap: () => _runAction(
                            () => provider.sendCommand('//copy'),
                            'Selection copied',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.content_paste,
                          label: 'Paste',
                          color: Colors.blue,
                          onTap: () => _runAction(
                            () => provider.sendCommand('//paste'),
                            'Clipboard pasted',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _SectionHeader(title: 'Modification', icon: Icons.edit, color: Colors.amber),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.grid_4x4,
                          label: 'Set Block',
                          color: Colors.green,
                          onTap: () => _showSetBlockDialog(context),
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
