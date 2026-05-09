import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rcon_provider.dart';
import '../theme/app_theme.dart';

class ConsoleScreen extends StatefulWidget {
  const ConsoleScreen({super.key});

  @override
  State<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<ConsoleScreen> {
  final _commandController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ConsoleEntry> _entries = [];
  StreamSubscription<String>? _responseSubscription;
  bool _isExecuting = false;

  @override
  void initState() {
    super.initState();
    _responseSubscription = context.read<RconProvider>().responseStream.listen((response) {
      // Response is handled in _sendCommand
    });
  }

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    _responseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _sendCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;

    setState(() {
      _entries.add(_ConsoleEntry(text: '> $command', isCommand: true));
      _isExecuting = true;
    });

    _commandController.clear();
    _scrollToBottom();

    try {
      final provider = context.read<RconProvider>();
      final response = await provider.sendCommand(command);

      setState(() {
        if (response.isNotEmpty) {
          _entries.add(_ConsoleEntry(text: response, isCommand: false));
        } else {
          _entries.add(_ConsoleEntry(text: '(no response)', isCommand: false, isInfo: true));
        }
        _isExecuting = false;
      });
    } catch (e) {
      setState(() {
        _entries.add(_ConsoleEntry(text: 'Error: $e', isCommand: false, isError: true));
        _isExecuting = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearConsole() {
    setState(() {
      _entries.clear();
    });
  }

  void _showHistoryDialog() {
    final provider = context.read<RconProvider>();

    if (provider.commandHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No command history')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.history),
                const SizedBox(width: 8),
                Text(
                  'Command History',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: provider.commandHistory.length,
              itemBuilder: (context, index) {
                final cmd = provider.commandHistory[index];
                return ListTile(
                  leading: const Icon(Icons.terminal, size: 20),
                  title: Text(
                    cmd,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _commandController.text = cmd;
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[800]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.history, size: 20),
                onPressed: _showHistoryDialog,
                tooltip: 'Command History',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: _clearConsole,
                tooltip: 'Clear Console',
              ),
              const Spacer(),
              // Quick command chips
              _QuickCommandChip(label: 'list', onTap: () {
                _commandController.text = 'list';
                _sendCommand();
              }),
              const SizedBox(width: 8),
              _QuickCommandChip(label: 'help', onTap: () {
                _commandController.text = 'help';
                _sendCommand();
              }),
            ],
          ),
        ),

        // Console output
        Expanded(
          child: _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.terminal,
                        size: 64,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Console ready',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Type a command below',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: SelectableText(
                        entry.text,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: entry.isCommand
                              ? AppTheme.diamond
                              : entry.isError
                                  ? AppTheme.redstone
                                  : entry.isInfo
                                      ? Colors.grey[500]
                                      : Colors.grey[300],
                          fontWeight: entry.isCommand ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Command input
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              top: BorderSide(
                color: Colors.grey[800]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                '>',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  color: AppTheme.grassGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _commandController,
                  decoration: const InputDecoration(
                    hintText: 'Enter command...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                  onSubmitted: (_) => _sendCommand(),
                  enabled: !_isExecuting,
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 8),
              _isExecuting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendCommand,
                      color: AppTheme.grassGreen,
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConsoleEntry {
  final String text;
  final bool isCommand;
  final bool isError;
  final bool isInfo;

  _ConsoleEntry({
    required this.text,
    required this.isCommand,
    this.isError = false,
    this.isInfo = false,
  });
}

class _QuickCommandChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickCommandChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.grassGreen.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.grassGreen.withAlpha(50)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: AppTheme.grassGreen,
          ),
        ),
      ),
    );
  }
}
