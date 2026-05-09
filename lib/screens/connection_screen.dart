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
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '25575');
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _saveConnection = true;

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<RconProvider>();

    final connection = ServerConnection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.isEmpty
          ? _hostController.text
          : _nameController.text,
      host: _hostController.text,
      port: int.parse(_portController.text),
      password: _passwordController.text,
    );

    if (_saveConnection) {
      await provider.saveConnection(connection);
    }

    final success = await provider.connect(connection);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.lastError ?? 'Connection failed'),
          backgroundColor: AppTheme.redstone,
        ),
      );
    }
  }

  Future<void> _connectToSaved(ServerConnection connection) async {
    final provider = context.read<RconProvider>();
    final success = await provider.connect(connection);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.lastError ?? 'Connection failed'),
          backgroundColor: AppTheme.redstone,
        ),
      );
    }
  }

  void _editConnection(ServerConnection connection) {
    _nameController.text = connection.name;
    _hostController.text = connection.host;
    _portController.text = connection.port.toString();
    _passwordController.text = connection.password;
    setState(() {});
  }

  Future<void> _deleteConnection(ServerConnection connection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Server'),
        content: Text('Delete "${connection.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.redstone),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await context.read<RconProvider>().deleteConnection(connection.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<RconProvider>(
          builder: (context, provider, _) {
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 120,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.dns, color: AppTheme.grassGreen, size: 24),
                        const SizedBox(width: 8),
                        const Text('MC RCON'),
                      ],
                    ),
                    centerTitle: true,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Saved connections
                      if (provider.savedConnections.isNotEmpty) ...[
                        Text(
                          'Saved Servers',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey[400],
                              ),
                        ),
                        const SizedBox(height: 12),
                        ...provider.savedConnections.map((connection) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AppTheme.grassGreen,
                                  child: Icon(Icons.dns, color: Colors.white),
                                ),
                                title: Text(connection.name),
                                subtitle: Text(
                                  '${connection.host}:${connection.port}',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () => _editConnection(connection),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete,
                                          size: 20, color: Colors.red[300]),
                                      onPressed: () => _deleteConnection(connection),
                                    ),
                                  ],
                                ),
                                onTap: provider.isConnecting
                                    ? null
                                    : () => _connectToSaved(connection),
                              ),
                            )),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                      ],

                      // New connection form
                      Text(
                        provider.savedConnections.isEmpty
                            ? 'Connect to Server'
                            : 'New Connection',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[400],
                            ),
                      ),
                      const SizedBox(height: 16),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Server Name (optional)',
                                prefixIcon: Icon(Icons.label),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _hostController,
                              decoration: const InputDecoration(
                                labelText: 'Host / IP Address',
                                prefixIcon: Icon(Icons.computer),
                                hintText: 'e.g., 192.168.1.100',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter the server host';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _portController,
                              decoration: const InputDecoration(
                                labelText: 'RCON Port',
                                prefixIcon: Icon(Icons.numbers),
                                hintText: '25575',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter the RCON port';
                                }
                                final port = int.tryParse(value);
                                if (port == null || port < 1 || port > 65535) {
                                  return 'Please enter a valid port (1-65535)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'RCON Password',
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter the RCON password';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            CheckboxListTile(
                              value: _saveConnection,
                              onChanged: (value) {
                                setState(() {
                                  _saveConnection = value ?? true;
                                });
                              },
                              title: const Text('Save this connection'),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: provider.isConnecting ? null : _connect,
                                child: provider.isConnecting
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Connect',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Help section
                      Card(
                        color: AppTheme.darkStone.withAlpha(50),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.help_outline,
                                      color: AppTheme.diamond, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'How to enable RCON',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'In your server.properties file, set:\n\n'
                                'enable-rcon=true\n'
                                'rcon.port=25575\n'
                                'rcon.password=your_password',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
