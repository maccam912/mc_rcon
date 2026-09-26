import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/server_connection.dart';
import '../providers/rcon_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _formScrollKey = GlobalKey();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '25575');
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _saveConnection = true;
  bool _submitting = false;
  bool _connectingFromForm = false;
  String? _editingConnectionId;
  ServerConnection? _pendingConnection;

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    final connection = ServerConnection(
      id:
          _editingConnectionId ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim().isEmpty
          ? _hostController.text.trim()
          : _nameController.text.trim(),
      host: _hostController.text.trim(),
      port: int.parse(_portController.text.trim()),
      password: _passwordController.text,
    );
    await _openConnection(connection, save: _saveConnection, fromForm: true);
  }

  Future<void> _connectToSaved(ServerConnection connection) =>
      _openConnection(connection);

  Future<void> _openConnection(
    ServerConnection connection, {
    bool save = false,
    bool fromForm = false,
  }) async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _connectingFromForm = fromForm;
      _pendingConnection = connection;
    });
    final provider = context.read<RconProvider>();
    try {
      if (save) await provider.saveConnection(connection);
      if (!mounted) return;
      final success = await provider.connect(connection);
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        _showError(provider.lastError ?? 'Connection failed');
      }
    } catch (error) {
      if (mounted) _showError('Could not connect: $error');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _pendingConnection = null;
        });
      }
    }
  }

  void _showError(String message) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: colors.onErrorContainer),
          ),
          backgroundColor: colors.errorContainer,
        ),
      );
  }

  void _revealForm() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final formContext = _formScrollKey.currentContext;
      if (formContext != null) {
        Scrollable.ensureVisible(
          formContext,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.05,
        );
      }
    });
  }

  void _editConnection(ServerConnection connection) {
    _formKey.currentState?.reset();
    _nameController.text = connection.name;
    _hostController.text = connection.host;
    _portController.text = connection.port.toString();
    _passwordController.text = connection.password;
    setState(() {
      _editingConnectionId = connection.id;
      _saveConnection = true;
      _obscurePassword = true;
    });
    _revealForm();
  }

  void _startNewConnection() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _hostController.clear();
    _portController.text = '25575';
    _passwordController.clear();
    setState(() {
      _editingConnectionId = null;
      _saveConnection = true;
      _obscurePassword = true;
    });
    _revealForm();
  }

  Future<void> _deleteConnection(ServerConnection connection) async {
    final provider = context.read<RconProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove saved server?'),
        content: Text('Remove “${connection.name}” from your saved servers?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.redstone),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await provider.deleteConnection(connection.id);
        if (!mounted) return;
        if (_editingConnectionId == connection.id) _startNewConnection();
      } catch (error) {
        if (mounted) _showError('Could not delete server: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<RconProvider>(
          builder: (context, provider, _) {
            final busy = provider.isConnecting || _submitting;
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final padding = constraints.maxWidth < 600 ? 20.0 : 40.0;
                final library = _buildServerLibrary(provider, busy);
                final form = _buildConnectionForm(busy);
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(padding, 28, padding, 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(wide),
                          const SizedBox(height: 32),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    children: [
                                      library,
                                      const SizedBox(height: 20),
                                      _buildSetupHelp(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(flex: 6, child: form),
                              ],
                            )
                          else ...[
                            if (provider.savedConnections.isEmpty)
                              form
                            else
                              library,
                            const SizedBox(height: 24),
                            if (provider.savedConnections.isEmpty)
                              library
                            else
                              form,
                            const SizedBox(height: 20),
                            _buildSetupHelp(),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool wide) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.grassGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.grassGreen.withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.terminal_rounded,
                color: AppTheme.grassGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MC RCON',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Minecraft server companion',
                    style: textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: wide ? 36 : 28),
        Text(
          'Connect to your server.',
          style: (wide ? textTheme.headlineLarge : textTheme.headlineMedium)
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.8),
        ),
        const SizedBox(height: 10),
        Text(
          'Manage players, run commands, and keep your world in order.',
          style: textTheme.bodyLarge?.copyWith(
            color: AppTheme.muted,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildServerLibrary(RconProvider provider, bool busy) {
    final connections = provider.savedConnections;
    return _ConnectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Saved servers',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (connections.isNotEmpty)
                TextButton.icon(
                  onPressed: busy ? null : _startNewConnection,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            connections.isEmpty
                ? 'Your next connection is one step away.'
                : 'Choose a server to reconnect.',
            style: const TextStyle(color: AppTheme.muted),
          ),
          const SizedBox(height: 20),
          if (connections.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.background.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.dns_outlined,
                    size: 30,
                    color: AppTheme.muted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'A home for your worlds',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Add your server details and save the connection to find it here next time.',
                    style: TextStyle(color: AppTheme.muted, height: 1.5),
                  ),
                ],
              ),
            )
          else
            for (var index = 0; index < connections.length; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              _buildSavedServer(connections[index], busy),
            ],
        ],
      ),
    );
  }

  Widget _buildSavedServer(ServerConnection connection, bool busy) {
    final selected = _editingConnectionId == connection.id;
    final connecting =
        _submitting &&
        !_connectingFromForm &&
        _pendingConnection?.id == connection.id;
    return Material(
      color: selected
          ? AppTheme.grassGreen.withValues(alpha: 0.08)
          : AppTheme.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? AppTheme.grassGreen.withValues(alpha: 0.55)
              : AppTheme.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : () => _connectToSaved(connection),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.grassGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.dns_outlined,
                  color: AppTheme.grassGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${connection.host}:${connection.port}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                    ),
                    if (selected || connecting) ...[
                      const SizedBox(height: 6),
                      Text(
                        connecting ? 'Connecting…' : 'Editing connection',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.grassGreen,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (connecting)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Connect to ${connection.name}',
                  onPressed: busy ? null : () => _connectToSaved(connection),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  color: AppTheme.grassGreen,
                ),
              PopupMenuButton<String>(
                tooltip: 'Options for ${connection.name}',
                enabled: !busy,
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (action) {
                  if (action == 'edit') {
                    _editConnection(connection);
                  } else if (action == 'remove') {
                    _deleteConnection(connection);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 12),
                        Text('Edit connection'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppTheme.redstone,
                        ),
                        SizedBox(width: 12),
                        Text('Remove server'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionForm(bool busy) {
    final editing = _editingConnectionId != null;
    return _ConnectionPanel(
      key: _formScrollKey,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      editing ? 'Edit connection' : 'New connection',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (editing)
                    TextButton(
                      onPressed: busy ? null : _startNewConnection,
                      child: const Text('Cancel edit'),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                editing
                    ? 'Update the details below, then reconnect.'
                    : 'Enter the RCON details from your server configuration.',
                style: const TextStyle(color: AppTheme.muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                enabled: !busy,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Server name (optional)',
                  hintText: 'My survival world',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _hostController,
                enabled: !busy,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Host / IP address',
                  prefixIcon: Icon(Icons.dns_outlined),
                  hintText: '192.168.1.100',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter the server hostname or IP address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _portController,
                enabled: !busy,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'RCON port',
                  prefixIcon: Icon(Icons.numbers_rounded),
                  helperText:
                      'Usually 25575 · use the RCON port, not the game port',
                  helperMaxLines: 2,
                ),
                validator: (value) {
                  final port = int.tryParse(value?.trim() ?? '');
                  if (port == null || port < 1 || port > 65535) {
                    return 'Enter a port between 1 and 65535';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _passwordController,
                enabled: !busy,
                obscureText: _obscurePassword,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!busy) _connect();
                },
                decoration: InputDecoration(
                  labelText: 'RCON password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            _obscurePassword = !_obscurePassword;
                          }),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter the RCON password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                value: _saveConnection,
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                        _saveConnection = value ?? true;
                      }),
                title: Text(
                  editing
                      ? 'Save changes to this server'
                      : 'Save this connection',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  editing
                      ? 'Update the saved details when you connect.'
                      : 'Remember these details on this device.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                    height: 1.5,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: busy ? null : _connect,
                  icon: _submitting && _connectingFromForm
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login_rounded, size: 20),
                  label: Text(
                    _submitting && _connectingFromForm
                        ? 'Connecting…'
                        : editing && _saveConnection
                        ? 'Save & connect'
                        : 'Connect',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetupHelp() {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: const Icon(
            Icons.tune_rounded,
            color: AppTheme.diamond,
            size: 22,
          ),
          title: const Text('First time using RCON?'),
          subtitle: const Text(
            'Server setup guide',
            style: TextStyle(color: AppTheme.muted),
          ),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add these settings to server.properties, then restart your server.',
                style: TextStyle(color: AppTheme.muted, height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const SelectableText(
                'enable-rcon=true\n'
                'rcon.port=25575\n'
                'rcon.password=your_password',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.7,
                  color: AppTheme.diamond,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionPanel extends StatelessWidget {
  const _ConnectionPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 20 : 24,
        ),
        child: child,
      ),
    );
  }
}
