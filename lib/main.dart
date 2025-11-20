import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/server_list_screen.dart';
import 'screens/server_control_screen.dart';
import 'models/server.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DiHoaManager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/server-list': (context) => const ServerListScreen(),
        '/server-control': (context) {
          final server = ModalRoute.of(context)!.settings.arguments as Server;
          return ServerControlScreen(server: server);
        },
      },
    );
  }
}
