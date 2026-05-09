import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rcon_provider.dart';
import '../theme/app_theme.dart';
import 'connection_screen.dart';
import 'players_screen.dart';
import 'quick_actions_screen.dart';
import 'console_screen.dart';
import 'plugins_screen.dart';
import 'script_runner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const PlayersScreen(),
    const QuickActionsScreen(),
    const PluginsScreen(),
    const ScriptRunnerScreen(),
    const ConsoleScreen(),
  ];

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect'),
        content: const Text('Disconnect from the server?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.redstone),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<RconProvider>().disconnect();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ConnectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RconProvider>(
      builder: (context, provider, _) {
        // If disconnected, go back to connection screen
        if (!provider.isConnected && !provider.isConnecting) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ConnectionScreen()),
            );
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: provider.isConnected ? AppTheme.grassGreen : AppTheme.redstone,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  provider.currentConnection?.name ?? 'MC RCON',
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => provider.refreshPlayers(),
                tooltip: 'Refresh Players',
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _disconnect,
                tooltip: 'Disconnect',
              ),
            ],
          ),
          body: _screens[_currentIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: [
              NavigationDestination(
                icon: Badge(
                  label: Text('${provider.players.length}'),
                  isLabelVisible: provider.players.isNotEmpty,
                  child: const Icon(Icons.people_outline),
                ),
                selectedIcon: Badge(
                  label: Text('${provider.players.length}'),
                  isLabelVisible: provider.players.isNotEmpty,
                  child: const Icon(Icons.people),
                ),
                label: 'Players',
              ),
              const NavigationDestination(
                icon: Icon(Icons.bolt_outlined),
                selectedIcon: Icon(Icons.bolt),
                label: 'Quick Actions',
              ),
              const NavigationDestination(
                icon: Icon(Icons.extension_outlined),
                selectedIcon: Icon(Icons.extension),
                label: 'Plugins',
              ),
              const NavigationDestination(
                icon: Icon(Icons.code_outlined),
                selectedIcon: Icon(Icons.code),
                label: 'Script',
              ),
              const NavigationDestination(
                icon: Icon(Icons.terminal_outlined),
                selectedIcon: Icon(Icons.terminal),
                label: 'Console',
              ),
            ],
          ),
        );
      },
    );
  }
}
