import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/rcon_provider.dart';
import 'screens/connection_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const McRconApp());
}

class McRconApp extends StatelessWidget {
  const McRconApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RconProvider(),
      child: MaterialApp(
        title: 'MC RCON',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const ConnectionScreen(),
      ),
    );
  }
}
