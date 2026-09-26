import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rcon_provider.dart';

class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RconProvider>();
    if (provider.currentConnection == null ||
        (provider.isConnected &&
            provider.lastError == null &&
            provider.timerError == null)) {
      return const SizedBox.shrink();
    }
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (provider.isConnecting)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                provider.isConnected ? Icons.error_outline : Icons.wifi_off,
                size: 20,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                provider.isConnecting
                    ? 'Reconnecting to the server…'
                    : provider.lastError ??
                          provider.timerError ??
                          'Disconnected. Retrying automatically…',
              ),
            ),
            TextButton(
              onPressed: provider.isConnecting ? null : provider.refreshPlayers,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
