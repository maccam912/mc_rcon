import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _focusNode = FocusNode();
  final List<_ConsoleEntry> _entries = [];
  bool _isExecuting = false;
  int _historyIndex = -1;
  String _currentInput = '';

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty || _isExecuting) return;

    setState(() {
      _entries.add(_ConsoleEntry(text: '> $command', isCommand: true));
      _isExecuting = true;
      _historyIndex = -1;
      _currentInput = '';
    });
    _commandController.clear();
    _scrollToBottom();

    try {
      final response = await context.read<RconProvider>().sendCommand(command);
      if (!mounted) return;
      setState(() {
        _entries.add(
          _ConsoleEntry(
            text: response.isEmpty ? '(no response)' : response,
            isCommand: false,
            isInfo: response.isEmpty,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _entries.add(
          _ConsoleEntry(text: 'Error: $e', isCommand: false, isError: true),
        );
      });
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _setInput(String text, {bool requestFocus = false}) {
    _commandController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    if (requestFocus) _focusNode.requestFocus();
  }

  void _handleHistoryNavigation(bool up) {
    if (_isExecuting) return;
    final history = context.read<RconProvider>().commandHistory;
    if (history.isEmpty) return;

    if (up) {
      if (_historyIndex == -1) _currentInput = _commandController.text;
      if (_historyIndex < history.length - 1) {
        _historyIndex++;
        _setInput(history[_historyIndex]);
      }
    } else if (_historyIndex > 0) {
      _historyIndex--;
      _setInput(history[_historyIndex]);
    } else if (_historyIndex == 0) {
      _historyIndex = -1;
      _setInput(_currentInput);
    }
  }

  Future<void> _copyOutput() async {
    await Clipboard.setData(
      ClipboardData(text: _entries.map((entry) => entry.text).join('\n')),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Console output copied')));
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<RconProvider>().commandHistory;
    final commandCount = _entries.where((entry) => entry.isCommand).length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final padding = compact ? 20.0 : 32.0;
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final shortViewport =
            constraints.maxHeight < 440 * textScale ||
            MediaQuery.viewInsetsOf(context).bottom > 0;
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                padding,
                shortViewport ? 8 : padding,
                padding,
                shortViewport ? 8 : 16,
              ),
              child: Row(
                crossAxisAlignment: shortViewport
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Console',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              (shortViewport
                                      ? Theme.of(context).textTheme.titleLarge
                                      : Theme.of(
                                          context,
                                        ).textTheme.headlineMedium)
                                  ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (!shortViewport) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Send commands. See the response.',
                            style: TextStyle(
                              color: AppTheme.muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Copy console output',
                    icon: const Icon(Icons.copy_all_outlined, size: 21),
                    onPressed: _entries.isEmpty ? null : _copyOutput,
                  ),
                  IconButton(
                    tooltip: 'Clear console output',
                    icon: const Icon(Icons.delete_sweep_outlined, size: 22),
                    onPressed: _entries.isEmpty || _isExecuting
                        ? null
                        : () => setState(_entries.clear),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: padding),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B120E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        color: AppTheme.surface,
                        border: Border(
                          bottom: BorderSide(color: AppTheme.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.terminal_rounded,
                            size: 17,
                            color: AppTheme.grassGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              compact && _isExecuting
                                  ? 'Running…'
                                  : 'COMMAND OUTPUT',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.muted,
                              ),
                            ),
                          ),
                          if (!compact && _isExecuting)
                            const Text(
                              'Running…',
                              style: TextStyle(
                                color: AppTheme.gold,
                                fontSize: 12,
                              ),
                            )
                          else if (!compact)
                            Text(
                              '$commandCount ${commandCount == 1 ? 'command' : 'commands'}',
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _entries.isEmpty
                          ? _buildEmptyState()
                          : Scrollbar(
                              controller: _scrollController,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: _entries.length,
                                itemBuilder: (context, index) {
                                  final entry = _entries[index];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      top: entry.isCommand && index > 0
                                          ? 18
                                          : 0,
                                      bottom: 6,
                                    ),
                                    child: SelectableText(
                                      entry.text,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                        height: 1.6,
                                        color: entry.isCommand
                                            ? AppTheme.diamond
                                            : entry.isError
                                            ? AppTheme.redstone
                                            : entry.isInfo
                                            ? AppTheme.muted
                                            : const Color(0xFFE0EAE3),
                                        fontWeight: entry.isCommand
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                    if (_isExecuting)
                      const LinearProgressIndicator(minHeight: 2),
                  ],
                ),
              ),
            ),
            _buildComposer(history, padding, compact, shortViewport),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.panel,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.terminal_rounded,
                size: 30,
                color: AppTheme.grassGreen,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your server, at your command',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter a Minecraft command below, or choose one to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final command in ['list', 'time query daytime', 'help'])
                  ActionChip(
                    label: Text(
                      command,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () => _setInput(command, requestFocus: true),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(
    List<String> history,
    double padding,
    bool compact,
    bool shortViewport,
  ) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          padding,
          shortViewport ? 8 : 16,
          padding,
          shortViewport ? 8 : (compact ? 12 : 24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                              event.logicalKey ==
                                  LogicalKeyboardKey.arrowDown)) {
                        _handleHistoryNavigation(
                          event.logicalKey == LogicalKeyboardKey.arrowUp,
                        );
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _commandController,
                      focusNode: _focusNode,
                      readOnly: _isExecuting,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter a command…',
                        prefixIcon: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.grassGreen,
                        ),
                        suffixIcon: PopupMenuButton<String>(
                          tooltip: 'Command history',
                          enabled: history.isNotEmpty && !_isExecuting,
                          icon: const Icon(Icons.history_rounded, size: 21),
                          onSelected: (command) {
                            _historyIndex = -1;
                            _setInput(command, requestFocus: true);
                          },
                          itemBuilder: (context) => [
                            for (final command in history.take(20))
                              PopupMenuItem(
                                value: command,
                                child: Text(
                                  command,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      onChanged: (_) => _historyIndex = -1,
                      onEditingComplete: () {},
                      onSubmitted: (_) => _sendCommand(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _commandController,
                  builder: (context, value, child) {
                    final canSend =
                        value.text.trim().isNotEmpty && !_isExecuting;
                    return SizedBox(
                      height: 52,
                      child: compact
                          ? IconButton.filled(
                              tooltip: 'Send command',
                              onPressed: canSend ? _sendCommand : null,
                              icon: const Icon(Icons.arrow_upward_rounded),
                            )
                          : FilledButton.icon(
                              onPressed: canSend ? _sendCommand : null,
                              icon: const Icon(
                                Icons.arrow_upward_rounded,
                                size: 18,
                              ),
                              label: const Text('Send'),
                            ),
                    );
                  },
                ),
              ],
            ),
            if (!shortViewport) ...[
              const SizedBox(height: 8),
              Text(
                compact
                    ? 'Use the history icon to reuse a command.'
                    : 'Enter to send · ↑ ↓ to browse history · Commands run on the connected server',
                style: const TextStyle(color: AppTheme.muted, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
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
