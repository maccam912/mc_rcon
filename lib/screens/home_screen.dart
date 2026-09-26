import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/rcon_provider.dart';
import '../theme/app_theme.dart';
import 'connection_screen.dart';
import '../widgets/connection_status_banner.dart';
import 'players_screen.dart';
import 'quick_actions_screen.dart';
import 'console_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final Set<int> _visited = {0};
  bool _refreshing = false;
  StreamSubscription<String>? _notices;

  @override
  void initState() {
    super.initState();
    _notices = context.read<RconProvider>().notices.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  void dispose() {
    _notices?.cancel();
    super.dispose();
  }

  final List<Widget> _screens = [
    const PlayersScreen(),
    const QuickActionsScreen(),
    const ConsoleScreen(),
  ];

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect'),
        content: Text(
          context.read<RconProvider>().timerStatuses.any(
                (timer) => timer.blockedUntil != null,
              )
              ? 'A temporary player ban is pending. Disconnecting pauses automatic releases until you reconnect. Disconnect anyway?'
              : 'Disconnect from the server? Playtime tracking will pause.',
        ),
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

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _currentIndex = index;
      _visited.add(index);
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await context.read<RconProvider>().refreshPlayers();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RconProvider>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return CallbackShortcuts(
          bindings: {
            for (var i = 0; i < 3; i++) ...{
              SingleActivator(
                [
                  LogicalKeyboardKey.digit1,
                  LogicalKeyboardKey.digit2,
                  LogicalKeyboardKey.digit3,
                ][i],
                meta: true,
              ): () =>
                  _selectTab(i),
              SingleActivator(
                [
                  LogicalKeyboardKey.digit1,
                  LogicalKeyboardKey.digit2,
                  LogicalKeyboardKey.digit3,
                ][i],
                control: true,
              ): () =>
                  _selectTab(i),
            },
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              appBar: AppBar(
                titleSpacing: wide ? 24 : 16,
                leadingWidth: 0,
                automaticallyImplyLeading: false,
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppTheme.darkGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.dns_outlined,
                        size: 21,
                        color: AppTheme.grassGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.currentConnection?.name ?? 'MC RCON',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            wide && provider.currentConnection != null
                                ? '${provider.currentConnection!.host}:${provider.currentConnection!.port}'
                                : provider.isConnecting
                                ? 'Reconnecting…'
                                : provider.isConnected
                                ? 'Connected'
                                : 'Offline',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  if (wide) ...[
                    _ConnectionPill(
                      connected: provider.isConnected,
                      connecting: provider.isConnecting,
                    ),
                    const SizedBox(width: 12),
                  ],
                  IconButton(
                    tooltip: 'Refresh players',
                    onPressed: _refreshing || provider.isConnecting
                        ? null
                        : _refresh,
                    icon: _refreshing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                  if (!wide)
                    IconButton(
                      tooltip: 'Disconnect',
                      onPressed: _disconnect,
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  SizedBox(width: wide ? 20 : 8),
                ],
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(1),
                  child: Divider(),
                ),
              ),
              body: SafeArea(
                top: false,
                bottom: wide,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide) _buildSidebar(provider),
                    Expanded(
                      key: const ValueKey('workspace'),
                      child: Column(
                        children: [
                          const ConnectionStatusBanner(),
                          Expanded(
                            child: IndexedStack(
                              index: _currentIndex,
                              children: List.generate(
                                _screens.length,
                                (index) => TickerMode(
                                  enabled: index == _currentIndex,
                                  child: ExcludeFocus(
                                    excluding: index != _currentIndex,
                                    child: _visited.contains(index)
                                        ? _screens[index]
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: wide
                  ? null
                  : DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppTheme.border)),
                      ),
                      child: NavigationBar(
                        selectedIndex: _currentIndex,
                        onDestinationSelected: _selectTab,
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.people_outline_rounded),
                            selectedIcon: Icon(Icons.people_rounded),
                            label: 'Players',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.bolt_outlined),
                            selectedIcon: Icon(Icons.bolt),
                            label: 'Quick actions',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.terminal_outlined),
                            selectedIcon: Icon(Icons.terminal),
                            label: 'Console',
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebar(RconProvider provider) {
    return Container(
      key: const ValueKey('desktop-sidebar'),
      width: 224,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 12, bottom: 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          color: AppTheme.grassGreen,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'MC RCON',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 12, bottom: 12),
                    child: Text(
                      'WORKSPACE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                  _navigationItem(
                    0,
                    'Players',
                    Icons.people_outline_rounded,
                    '${provider.players.where((p) => !p.isBot).length}',
                  ),
                  const SizedBox(height: 6),
                  _navigationItem(
                    1,
                    'Quick actions',
                    Icons.bolt_outlined,
                    null,
                  ),
                  const SizedBox(height: 6),
                  _navigationItem(2, 'Console', Icons.terminal_outlined, null),
                ],
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR SERVER, AT A GLANCE',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  provider.supportsPlayerTimers &&
                          provider.timerStatuses.isNotEmpty
                      ? 'Keep this app connected to track playtime and release breaks.'
                      : 'The player list refreshes automatically while connected.',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _disconnect,
                  icon: const Icon(Icons.logout_rounded, size: 17),
                  label: const Text('Disconnect'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navigationItem(
    int index,
    String label,
    IconData icon,
    String? count,
  ) {
    final selected = _currentIndex == index;
    return Tooltip(
      message: '$label · ⌘${index + 1} / Ctrl+${index + 1}',
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          selected: selected,
          selectedTileColor: AppTheme.darkGreen,
          selectedColor: AppTheme.grassGreen,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Icon(icon, size: 21),
          title: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          trailing: count == null
              ? null
              : Text(
                  count,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? AppTheme.grassGreen : AppTheme.muted,
                  ),
                ),
          onTap: () => _selectTab(index),
        ),
      ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  final bool connected;
  final bool connecting;
  const _ConnectionPill({required this.connected, required this.connecting});

  @override
  Widget build(BuildContext context) {
    final color = connecting
        ? AppTheme.gold
        : connected
        ? AppTheme.grassGreen
        : AppTheme.redstone;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 7),
          Text(
            connecting
                ? 'Reconnecting'
                : connected
                ? 'Connected'
                : 'Offline',
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
