import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rcon_provider.dart';
import '../theme/app_theme.dart';

class ScriptRunnerScreen extends StatefulWidget {
  const ScriptRunnerScreen({super.key});

  @override
  State<ScriptRunnerScreen> createState() => _ScriptRunnerScreenState();
}

class _ScriptRunnerScreenState extends State<ScriptRunnerScreen> {
  final _scriptController = TextEditingController();
  final _scrollController = ScrollController();
  String? _selectedPlayer;
  bool _isRunning = false;
  int _currentCommand = 0;
  int _totalCommands = 0;
  final List<_ExecutionResult> _results = [];

  static const _sampleScript = '''# Sample cabin build script
fill ~-5 ~ ~-5 ~5 ~8 ~5 air
fill ~-5 ~-1 ~-5 ~5 ~-1 ~5 stone_bricks
fill ~-4 ~ ~-4 ~4 ~ ~4 spruce_planks
fill ~-5 ~ ~-5 ~-5 ~3 ~-5 spruce_log
fill ~5 ~ ~-5 ~5 ~3 ~-5 spruce_log
fill ~-5 ~ ~5 ~-5 ~3 ~5 spruce_log
fill ~5 ~ ~5 ~5 ~3 ~5 spruce_log
setblock ~ ~1 ~-5 oak_door[facing=north,half=lower]
setblock ~ ~2 ~-5 oak_door[facing=north,half=upper]
setblock ~ ~4 ~ lantern[hanging=true]''';

  @override
  void dispose() {
    _scriptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _parseScript(String script) {
    return script
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
  }

  Future<void> _runScript() async {
    if (_selectedPlayer == null || _scriptController.text.isEmpty) return;

    final commands = _parseScript(_scriptController.text);
    if (commands.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid commands found in script')),
      );
      return;
    }

    setState(() {
      _isRunning = true;
      _currentCommand = 0;
      _totalCommands = commands.length;
      _results.clear();
    });

    final provider = context.read<RconProvider>();

    for (int i = 0; i < commands.length; i++) {
      if (!mounted) break;

      final cmd = commands[i];
      final fullCmd = 'execute at $_selectedPlayer run $cmd';

      setState(() {
        _currentCommand = i + 1;
      });

      try {
        final response = await provider.sendCommand(fullCmd);
        setState(() {
          _results.add(_ExecutionResult(
            command: cmd,
            response: response.isEmpty ? 'OK' : response,
            isError: false,
          ));
        });
      } catch (e) {
        setState(() {
          _results.add(_ExecutionResult(
            command: cmd,
            response: 'Error: $e',
            isError: true,
          ));
        });
      }

      // Small delay to prevent overwhelming the server
      await Future.delayed(const Duration(milliseconds: 50));
    }

    setState(() {
      _isRunning = false;
    });

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

  void _clearAll() {
    setState(() {
      _scriptController.clear();
      _results.clear();
    });
  }

  void _loadSample() {
    _scriptController.text = _sampleScript;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RconProvider>(
      builder: (context, provider, _) {
        final players = provider.players;

        // Reset selected player if they went offline
        if (_selectedPlayer != null &&
            !players.any((p) => p.name == _selectedPlayer)) {
          _selectedPlayer = null;
        }

        return Column(
          children: [
            // Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[800]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Player dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedPlayer != null
                              ? AppTheme.grassGreen
                              : Colors.grey[700]!,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPlayer,
                          hint: Text(
                            players.isEmpty
                                ? 'No players online'
                                : 'Select player',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down),
                          items: players.map((player) {
                            return DropdownMenuItem(
                              value: player.name,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.grassGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(player.name),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: _isRunning
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedPlayer = value;
                                  });
                                },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () => provider.refreshPlayers(),
                    tooltip: 'Refresh Players',
                  ),
                  IconButton(
                    icon: const Icon(Icons.description_outlined, size: 20),
                    onPressed: _isRunning ? null : _loadSample,
                    tooltip: 'Load Sample Script',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: _isRunning ? null : _clearAll,
                    tooltip: 'Clear All',
                  ),
                ],
              ),
            ),

            // Script input
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: TextField(
                  controller: _scriptController,
                  maxLines: null,
                  expands: true,
                  enabled: !_isRunning,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        '# Paste mcfunction here...\n# Lines starting with # are comments\nfill ~-1 ~ ~-1 ~1 ~2 ~1 stone',
                    hintStyle: TextStyle(
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ),

            // Run button & progress
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_selectedPlayer == null ||
                              _scriptController.text.isEmpty ||
                              _isRunning)
                          ? null
                          : _runScript,
                      icon: _isRunning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(_isRunning
                          ? 'Running $_currentCommand/$_totalCommands...'
                          : 'Run at ${_selectedPlayer ?? "player"}'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Results output
            Expanded(
              flex: 1,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: _results.isEmpty
                    ? Center(
                        child: Text(
                          'Output will appear here',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final result = _results[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '> ${result.command}',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: AppTheme.diamond,
                                  ),
                                ),
                                Text(
                                  result.response,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: result.isError
                                        ? AppTheme.redstone
                                        : Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExecutionResult {
  final String command;
  final String response;
  final bool isError;

  _ExecutionResult({
    required this.command,
    required this.response,
    this.isError = false,
  });
}
