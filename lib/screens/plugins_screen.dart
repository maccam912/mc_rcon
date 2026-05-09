import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'plugin_pages/worldedit_screen.dart';
import 'plugin_pages/multiverse_screen.dart';
import 'plugin_pages/mythicmobs_screen.dart';
import 'plugin_pages/quests_screen.dart';
import 'plugin_pages/executableitems_screen.dart';
import 'plugin_pages/executableevents_screen.dart';

class PluginsScreen extends StatelessWidget {
  const PluginsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plugins = [
      _PluginInfo(
        name: 'WorldEdit',
        description: 'World editing tools',
        icon: Icons.architecture,
        color: Colors.amber,
        screen: const WorldEditScreen(),
      ),
      _PluginInfo(
        name: 'Multiverse',
        description: 'World management',
        icon: Icons.public,
        color: AppTheme.enderPurple,
        screen: const MultiverseScreen(),
      ),
      _PluginInfo(
        name: 'MythicMobs',
        description: 'Custom mobs',
        icon: Icons.pets,
        color: AppTheme.redstone,
        screen: const MythicMobsScreen(),
      ),
      _PluginInfo(
        name: 'Quests',
        description: 'Quest management',
        icon: Icons.assignment,
        color: AppTheme.gold,
        screen: const QuestsScreen(),
      ),
      _PluginInfo(
        name: 'ExecutableItems',
        description: 'Custom items',
        icon: Icons.inventory_2,
        color: AppTheme.diamond,
        screen: const ExecutableItemsScreen(),
      ),
      _PluginInfo(
        name: 'ExecutableEvents',
        description: 'Custom events',
        icon: Icons.bolt,
        color: AppTheme.grassGreen,
        screen: const ExecutableEventsScreen(),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemCount: plugins.length,
        itemBuilder: (context, index) {
          final plugin = plugins[index];
          return _PluginCard(plugin: plugin);
        },
      ),
    );
  }
}

class _PluginInfo {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final Widget screen;

  const _PluginInfo({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.screen,
  });
}

class _PluginCard extends StatelessWidget {
  final _PluginInfo plugin;

  const _PluginCard({required this.plugin});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => plugin.screen),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: plugin.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  plugin.icon,
                  color: plugin.color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                plugin.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                plugin.description,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
