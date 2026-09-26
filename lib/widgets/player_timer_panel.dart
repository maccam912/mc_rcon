import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player_admin_status.dart';
import '../providers/rcon_provider.dart';
import '../theme/app_theme.dart';

class PlayerTimerPanel extends StatefulWidget {
  final String playerName;
  const PlayerTimerPanel({super.key, required this.playerName});

  @override
  State<PlayerTimerPanel> createState() => _PlayerTimerPanelState();
}

class _PlayerTimerPanelState extends State<PlayerTimerPanel> {
  bool _busy = false;

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$error'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(PlayerTimerStatus? status) async {
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (_) =>
          _PolicyDialog(playerName: widget.playerName, status: status),
    );
    if (result == null || !mounted) return;
    await _run(
      () => context.read<RconProvider>().setPlayPolicy(
        widget.playerName,
        result.$1,
        result.$2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RconProvider>();
    final status = provider.timerStatusFor(widget.playerName);
    final remaining = status?.remainingBreak.inSeconds ?? 0;
    final hasPendingRelease = status?.blockedUntil != null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined, color: AppTheme.diamond),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Play breaks',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (hasPendingRelease ? AppTheme.gold : AppTheme.diamond)
                            .withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    hasPendingRelease
                        ? 'On break'
                        : status?.enabled == true
                        ? 'Active'
                        : 'Off',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hasPendingRelease
                          ? AppTheme.gold
                          : AppTheme.diamond,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!provider.supportsPlayerTimers)
              Text(provider.timerError ?? 'Loading saved player timers…')
            else ...[
              if (status?.enabled == true) ...[
                Text(
                  'Play ${formatPlayDuration(status!.playSeconds)}, then take a ${formatPlayDuration(status.breakSeconds)} break.',
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(8),
                  color: AppTheme.diamond,
                  value: (status.playedSeconds / status.playSeconds).clamp(
                    0.0,
                    1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${formatPlayDuration(status.playedSeconds)} played since the last break',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ] else ...[
                const Text(
                  'No automatic play break configured for this player.',
                ),
                Text(
                  'Observed play time: ${formatPlayDuration(status?.playedSeconds ?? 0)}',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
              if (hasPendingRelease)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    remaining > 0
                        ? 'Reconnect available in about ${formatPlayDuration(remaining)}.'
                        : 'Break time has elapsed. Waiting for the server to confirm release.',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gold,
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1),
              ),
              const Text(
                'This app counts observed play time across reconnects. Breaks temporarily ban the player. Keep the app running (in the foreground on mobile) and connected to release them on time; pending releases resume when you reconnect.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              if (_busy) const LinearProgressIndicator(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _edit(status),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(
                      status?.enabled == true
                          ? 'Edit policy'
                          : 'Set play break',
                    ),
                  ),
                  if (status?.enabled == true)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () =>
                                  provider.disablePlayPolicy(widget.playerName),
                            ),
                      child: const Text('Disable policy'),
                    ),
                  if (hasPendingRelease)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => provider.releasePlayer(widget.playerName),
                            ),
                      child: const Text('End break now'),
                    ),
                ],
              ),
              if (hasPendingRelease && status?.enabled == true)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Disabling the policy keeps the current break. Use “End break now” to allow reconnecting.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.muted,
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PolicyDialog extends StatefulWidget {
  final String playerName;
  final PlayerTimerStatus? status;
  const _PolicyDialog({required this.playerName, this.status});
  @override
  State<_PolicyDialog> createState() => _PolicyDialogState();
}

class _PolicyDialogState extends State<_PolicyDialog> {
  final _form = GlobalKey<FormState>();
  late final _play = TextEditingController(
    text: '${((widget.status?.playSeconds ?? 3600) / 60).ceil()}',
  );
  late final _rest = TextEditingController(
    text: '${((widget.status?.breakSeconds ?? 120) / 60).ceil()}',
  );
  @override
  void dispose() {
    _play.dispose();
    _rest.dispose();
    super.dispose();
  }

  String? _validate(String? text) {
    final number = int.tryParse(text ?? '');
    return number == null || number < 1 || number > 1440
        ? 'Enter 1–1440 whole minutes'
        : null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Play break for ${widget.playerName}'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Only this player is affected. Time starts when this app observes them online. Keep the app running and connected to enforce breaks and lift temporary bans.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _play,
              keyboardType: TextInputType.number,
              validator: _validate,
              decoration: const InputDecoration(
                labelText: 'Play time (minutes)',
                helperText: 'Example: 60 for one hour',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rest,
              keyboardType: TextInputType.number,
              validator: _validate,
              decoration: const InputDecoration(
                labelText: 'Break (minutes)',
                helperText: 'Example: 2',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, (
              int.parse(_play.text),
              int.parse(_rest.text),
            ));
          }
        },
        child: const Text('Save policy'),
      ),
    ],
  );
}
