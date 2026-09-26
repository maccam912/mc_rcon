import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rcon_provider.dart';
import '../theme/app_theme.dart';

class QuickActionsScreen extends StatefulWidget {
  const QuickActionsScreen({super.key});

  @override
  State<QuickActionsScreen> createState() => _QuickActionsScreenState();
}

class _QuickActionsScreenState extends State<QuickActionsScreen> {
  String? _runningAction;

  Future<void> _runAction(
    Future<String> Function() action,
    String successMessage,
    String label,
  ) async {
    if (_runningAction != null) return;
    setState(() => _runningAction = label);

    try {
      final response = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.isEmpty ? successMessage : response)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    } finally {
      if (mounted) setState(() => _runningAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<RconProvider>();

    Widget action({
      required IconData icon,
      required String label,
      required Color color,
      required Future<String> Function() run,
      required String success,
      String? detail,
    }) {
      return _ActionTile(
        icon: icon,
        label: label,
        detail: detail,
        color: color,
        running: _runningAction == label,
        onTap: _runningAction == null
            ? () => _runAction(run, success, label)
            : null,
      );
    }

    final sections = [
      _ActionSection(
        title: 'Time of day',
        description: 'Set the time across your world.',
        icon: Icons.schedule_rounded,
        children: [
          action(
            icon: Icons.wb_sunny_outlined,
            label: 'Day',
            color: AppTheme.gold,
            run: () => provider.setTime('day'),
            success: 'Set time to day',
          ),
          action(
            icon: Icons.wb_sunny_rounded,
            label: 'Noon',
            color: AppTheme.gold,
            run: () => provider.setTime('noon'),
            success: 'Set time to noon',
          ),
          action(
            icon: Icons.nightlight_outlined,
            label: 'Night',
            color: AppTheme.enderPurple,
            run: () => provider.setTime('night'),
            success: 'Set time to night',
          ),
          action(
            icon: Icons.dark_mode_rounded,
            label: 'Midnight',
            color: AppTheme.enderPurple,
            run: () => provider.setTime('midnight'),
            success: 'Set time to midnight',
          ),
        ],
      ),
      _ActionSection(
        title: 'Weather',
        description: 'Choose the forecast for your world.',
        icon: Icons.cloud_outlined,
        children: [
          action(
            icon: Icons.wb_sunny_outlined,
            label: 'Clear',
            color: AppTheme.gold,
            run: () => provider.setWeather('clear'),
            success: 'Set weather to clear',
          ),
          action(
            icon: Icons.water_drop_outlined,
            label: 'Rain',
            color: AppTheme.diamond,
            run: () => provider.setWeather('rain'),
            success: 'Set weather to rain',
          ),
          action(
            icon: Icons.thunderstorm_outlined,
            label: 'Thunder',
            color: AppTheme.enderPurple,
            run: () => provider.setWeather('thunder'),
            success: 'Set weather to thunder',
          ),
        ],
      ),
      _ActionSection(
        title: 'All players',
        description: 'Apply an effect to everyone online.',
        icon: Icons.people_outline_rounded,
        children: [
          action(
            icon: Icons.favorite_outline_rounded,
            label: 'Heal all',
            color: AppTheme.redstone,
            run: () => provider.sendCommand(
              'effect give @a minecraft:instant_health 1 10',
            ),
            success: 'Healed all players',
          ),
          action(
            icon: Icons.restaurant_rounded,
            label: 'Feed all',
            color: AppTheme.gold,
            run: () => provider.sendCommand(
              'effect give @a minecraft:saturation 1 20',
            ),
            success: 'Fed all players',
          ),
          action(
            icon: Icons.shield_outlined,
            label: 'Invincibility',
            detail: 'Everyone · 60 seconds',
            color: AppTheme.diamond,
            run: () => provider.sendCommand(
              'effect give @a minecraft:resistance 60 255',
            ),
            success: 'All players invincible',
          ),
          action(
            icon: Icons.auto_fix_high_rounded,
            label: 'Clear effects',
            detail: 'Everyone · all effects',
            color: AppTheme.muted,
            run: () => provider.sendCommand('effect clear @a'),
            success: 'Cleared all effects',
          ),
        ],
      ),
      _ActionSection(
        title: 'Difficulty',
        description: 'Change the challenge for all players.',
        icon: Icons.tune_rounded,
        children: [
          for (final difficulty in [
            ('Peaceful', AppTheme.grassGreen, Icons.spa_outlined),
            ('Easy', AppTheme.diamond, Icons.terrain_outlined),
            ('Normal', AppTheme.gold, Icons.local_fire_department_outlined),
            ('Hard', AppTheme.redstone, Icons.whatshot_rounded),
          ])
            action(
              icon: difficulty.$3,
              label: difficulty.$1,
              color: difficulty.$2,
              run: () => provider.sendCommand(
                'difficulty ${difficulty.$1.toLowerCase()}',
              ),
              success: 'Set difficulty to ${difficulty.$1}',
            ),
        ],
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 600 ? 20.0 : 32.0;
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick actions',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A few taps to keep your world running smoothly.',
                    style: TextStyle(color: AppTheme.muted, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.grassGreen.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        if (_runningAction != null)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(
                            Icons.public_rounded,
                            size: 18,
                            color: AppTheme.grassGreen,
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _runningAction == null
                                ? 'Server-wide controls. Changes apply immediately.'
                                : 'Running $_runningAction…',
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, innerConstraints) {
                      final columns = innerConstraints.maxWidth >= 760 ? 2 : 1;
                      final width =
                          (innerConstraints.maxWidth - (columns - 1) * 20) /
                          columns;
                      return Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          for (final section in sections)
                            SizedBox(width: width, child: section),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionSection extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<Widget> children;

  const _ActionSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.grassGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: AppTheme.muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 270 ? 2 : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final child in children)
                    SizedBox(width: width, child: child),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? detail;
  final Color color;
  final bool running;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.detail,
    required this.color,
    required this.running,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.panel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Semantics(
          button: true,
          enabled: onTap != null,
          child: Opacity(
            opacity: onTap == null && !running ? 0.45 : 1,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (running)
                    SizedBox(
                      width: 23,
                      height: 23,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  else
                    Icon(icon, color: color, size: 23),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
