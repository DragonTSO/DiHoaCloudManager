import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/storage.dart';
import '../utils/firebase_helper.dart';
import 'auth_login_screen.dart';
import 'login_screen.dart';
import 'server_list_screen.dart';

/// Màn hình splash để kiểm tra trạng thái đăng nhập
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Đợi một chút để hiển thị splash screen
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // Kiểm tra Firebase có được khởi tạo không
    if (!FirebaseHelper.isFirebaseInitialized) {
      // Firebase chưa cấu hình, chuyển thẳng đến Panel Login (flow cũ)
      debugPrint('⚠️ Firebase chưa cấu hình, sử dụng flow cũ');
      final panelUrl = await Storage.getPanelUrl();
      final apiKey = await Storage.getApiKey();
      
      if (panelUrl != null && apiKey != null && panelUrl.isNotEmpty && apiKey.isNotEmpty) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/server-list');
        }
      } else {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/panel-login');
        }
      }
      return;
    }

    try {
      final authService = AuthService();
      final currentUser = authService.currentUser;

      // Kiểm tra Firebase Auth
      if (currentUser != null) {
        // Đã đăng nhập Firebase -> Kiểm tra Panel credentials
        final panelUrl = await Storage.getPanelUrl();
        final apiKey = await Storage.getApiKey();

        if (panelUrl != null && apiKey != null && panelUrl.isNotEmpty && apiKey.isNotEmpty) {
          // Đã có cả Firebase Auth và Panel credentials -> Vào Server List
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/server-list');
          }
        } else {
          // Chưa có Panel credentials -> Vào Panel Login
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/panel-login');
          }
        }
      } else {
        // Chưa đăng nhập Firebase -> Vào Auth Login
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      // Nếu có lỗi (Firebase chưa cấu hình), vẫn cho vào Auth Login
      debugPrint('⚠️ Error checking auth: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2196F3),
              const Color(0xFF1976D2),
              const Color(0xFF0D47A1),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_queue,
                  size: 100,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'DiHoaManager',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Đang kiểm tra...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

