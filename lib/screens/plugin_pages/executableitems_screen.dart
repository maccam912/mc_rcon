import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/rcon_provider.dart';
import '../../theme/app_theme.dart';

class ExecutableItemsScreen extends StatefulWidget {
  const ExecutableItemsScreen({super.key});

  @override
  State<ExecutableItemsScreen> createState() => _ExecutableItemsScreenState();
}

class _ExecutableItemsScreenState extends State<ExecutableItemsScreen> {
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

  Future<void> _showGiveItemDialog(BuildContext context) async {
    final playerController = TextEditingController();
    final itemController = TextEditingController();
    final amountController = TextEditingController(text: '1');
    final provider = context.read<RconProvider>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Give Item'),
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
              controller: itemController,
              decoration: const InputDecoration(
                labelText: 'Item ID',
                hintText: 'e.g., MyCustomSword',
              ),
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
              if (playerController.text.isNotEmpty && itemController.text.isNotEmpty) {
                final amount = amountController.text.isEmpty ? '1' : amountController.text;
                _runAction(
                  () => provider.sendCommand('ei give ${playerController.text} ${itemController.text} $amount'),
                  'Gave ${itemController.text} to ${playerController.text}',
                );
              }
            },
            child: const Text('Give'),
          ),
        ],
      ),
    );

    playerController.dispose();
    itemController.dispose();
    amountController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<RconProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ExecutableItems'),
        backgroundColor: AppTheme.diamond.withOpacity(0.2),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'General', icon: Icons.settings, color: AppTheme.diamond),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.refresh,
                          label: 'Reload',
                          color: Colors.orange,
                          onTap: () => _runAction(
                            () => provider.sendCommand('ei reload'),
                            'ExecutableItems reloaded',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.list,
                          label: 'Show Items',
                          color: AppTheme.diamond,
                          onTap: () => _runAction(
                            () => provider.sendCommand('ei show'),
                            'Showing items',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _SectionHeader(title: 'Items', icon: Icons.inventory_2, color: AppTheme.diamond),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.card_giftcard,
                          label: 'Give Item',
                          color: AppTheme.grassGreen,
                          onTap: () => _showGiveItemDialog(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.edit,
                          label: 'Editor',
                          color: Colors.blue,
                          onTap: () => _runAction(
                            () => provider.sendCommand('ei editor'),
                            'Opening editor',
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
