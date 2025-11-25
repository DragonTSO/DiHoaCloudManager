import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/welcome_screen.dart';
import 'screens/auth_login_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/server_list_screen.dart';
import 'screens/server_control_screen.dart';
import 'models/server.dart';
import 'widgets/auth_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Khởi tạo Firebase với error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase đã được khởi tạo thành công');
  } catch (e) {
    // Nếu Firebase chưa được cấu hình, log lỗi nhưng vẫn chạy app
    debugPrint('⚠️ Firebase chưa được cấu hình: $e');
    debugPrint('💡 Chạy "flutterfire configure" để cấu hình Firebase');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DiHoaManager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/login': (context) => const AuthLoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/panel-login': (context) => const _ProtectedRoute(child: PanelLoginScreen()),
        '/server-list': (context) => const _ProtectedRoute(child: ServerListScreen()),
        '/server-control': (context) {
          final server = ModalRoute.of(context)!.settings.arguments as Server;
          return _ProtectedRoute(child: ServerControlScreen(server: server));
        },
      },
    );
  }
}

/// Wrapper để bảo vệ route cần authentication
class _ProtectedRoute extends StatelessWidget {
  final Widget child;

  const _ProtectedRoute({required this.child});

  @override
  Widget build(BuildContext context) {
    return AuthGuard(child: child);
  }
}

