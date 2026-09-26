import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../models/player_admin_status.dart';
import '../providers/rcon_provider.dart';
import '../theme/app_theme.dart';
import 'player_actions_screen.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RconProvider>(
      builder: (context, provider, _) {
        final query = _search.text.trim().toLowerCase();
        bool matches(String name) => name.toLowerCase().contains(query);
        final humans = provider.players.where((p) => !p.isBot).toList();
        final bots = provider.players.where((p) => p.isBot).toList();
        final offlineTimers = provider.timerStatuses
            .where(
              (p) =>
                  !provider.players.any(
                    (online) =>
                        online.name.toLowerCase() == p.name.toLowerCase(),
                  ) &&
                  (p.enabled || p.blockedUntil != null),
            )
            .toList();
        final matchingHumans = humans.where((p) => matches(p.name)).toList();
        final matchingBots = bots.where((p) => matches(p.name)).toList();
        final matchingOffline = offlineTimers
            .where((p) => matches(p.name))
            .toList();
        final noMatches =
            matchingHumans.isEmpty &&
            matchingBots.isEmpty &&
            matchingOffline.isEmpty;

        return RefreshIndicator(
          onRefresh: provider.refreshPlayers,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Players (${humans.length})',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Look after your players and manage their time.',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Find a player or assistant bot',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () => setState(_search.clear),
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (query.isNotEmpty && noMatches)
                        _emptyState(
                          Icons.search_off,
                          'No matching players',
                          'Try another name or clear your search.',
                        )
                      else ...[
                        if (humans.isEmpty && query.isEmpty)
                          _emptyState(
                            Icons.people_outline,
                            'No human players online.',
                            'Players appear here when they join the server.',
                          ),
                        if (matchingHumans.isNotEmpty) ...[
                          _groupTitle(
                            'Online now',
                            '${matchingHumans.length} players',
                          ),
                          _cards(
                            matchingHumans
                                .map(
                                  (player) => _PlayerCard(
                                    key: ValueKey(player.name),
                                    player: player,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (matchingBots.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _groupTitle(
                            'Assistant bots (${bots.length})',
                            'Managed by their owners',
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Dismiss bots through their owner’s assistant mod.',
                              style: TextStyle(color: AppTheme.muted),
                            ),
                          ),
                          _cards(
                            matchingBots
                                .map(
                                  (player) => _PlayerCard(
                                    key: ValueKey(player.name),
                                    player: player,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (matchingOffline.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _groupTitle(
                            'Offline players with timers',
                            'Saved play breaks',
                          ),
                          _cards(
                            matchingOffline
                                .map(
                                  (timer) => _PlayerCard(
                                    key: ValueKey(timer.name),
                                    player: Player(
                                      name: timer.name,
                                      uuid: timer.uuid,
                                    ),
                                    online: false,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _groupTitle(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Text(
          subtitle,
          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _cards(List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 16,
      runSpacing: 12,
      children: children
          .map(
            (child) => SizedBox(
              width: constraints.maxWidth >= 760
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth,
              child: child,
            ),
          )
          .toList(),
    ),
  );

  Widget _emptyState(IconData icon, String title, String message) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, size: 28, color: AppTheme.muted),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: AppTheme.muted)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PlayerCard extends StatefulWidget {
  final Player player;
  final bool online;
  const _PlayerCard({super.key, required this.player, this.online = true});
  @override
  State<_PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<_PlayerCard> {
  bool _busy = false;

  Future<void> _teleportTo(String destination) async {
    if (_busy) return;
    setState(() => _busy = true);
    final provider = context.read<RconProvider>();
    final name = widget.player.name;
    try {
      final response = await provider.teleportPlayerTo(name, destination);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            response.isEmpty ? 'Teleported $name to $destination' : response,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.darkGreen,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('$error', style: const TextStyle(color: Colors.white)),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final provider = context.watch<RconProvider>();
    final timer = provider.timerStatusFor(player.name);
    final destinations =
        provider.players
            .where(
              (other) => other.name.toLowerCase() != player.name.toLowerCase(),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    final subtitle = player.isBot
        ? 'Bot for ${player.botOwner}'
        : (timer?.remainingBreak.inSeconds ?? 0) > 0
        ? 'Break: ${formatPlayDuration(timer!.remainingBreak.inSeconds)} left'
        : timer?.blockedUntil != null
        ? 'Break elapsed • release pending'
        : timer?.enabled == true
        ? '${widget.online ? 'Online' : 'Offline'} • ${formatPlayDuration(timer!.playedSeconds)} / ${formatPlayDuration(timer.playSeconds)}'
        : widget.online
        ? 'Online'
        : 'Offline';
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _busy
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlayerActionsScreen(player: player),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        (player.isBot ? AppTheme.diamond : AppTheme.grassGreen)
                            .withValues(alpha: .14),
                    foregroundColor: player.isBot
                        ? AppTheme.diamond
                        : AppTheme.grassGreen,
                    child: player.isBot
                        ? const Icon(Icons.smart_toy_outlined)
                        : Text(
                            player.name.isEmpty
                                ? '?'
                                : player.name[0].toUpperCase(),
                          ),
                  ),
                  const SizedBox(width: 12),
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
                        Text(
                          subtitle,
                          style: TextStyle(color: AppTheme.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (widget.online && !player.isBot) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                const Text(
                  'Teleport to',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                if (destinations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No other players online',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: destinations.map(_teleportButton).toList(),
                  ),
              ],
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teleportButton(Player destination) => Tooltip(
    message: 'Teleport ${widget.player.name} to ${destination.name}',
    child: TextButton.icon(
      onPressed: _busy ? null : () => _teleportTo(destination.name),
      icon: const Icon(Icons.my_location, size: 18),
      label: Text(destination.name),
    ),
  );
}
