import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/firebase_helper.dart';
import '../screens/auth_login_screen.dart';

/// Widget để bảo vệ các màn hình cần đăng nhập Firebase
/// Nếu chưa đăng nhập, sẽ redirect về màn hình đăng nhập
class AuthGuard extends StatelessWidget {
  final Widget child;

  const AuthGuard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Kiểm tra Firebase có được khởi tạo không
    if (!FirebaseHelper.isFirebaseInitialized) {
      // Firebase chưa cấu hình, cho phép truy cập (fallback)
      debugPrint('⚠️ Firebase chưa cấu hình, bỏ qua AuthGuard');
      return child;
    }

    try {
      final authService = AuthService();
      final currentUser = authService.currentUser;

      // Nếu chưa đăng nhập Firebase, redirect về login
      if (currentUser == null) {
        // Sử dụng WidgetsBinding để đảm bảo context sẵn sàng
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthLoginScreen()),
              (route) => false,
            );
          }
        });
        
        // Hiển thị loading trong khi redirect
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Đã đăng nhập, hiển thị child widget
      return child;
    } catch (e) {
      // Nếu có lỗi (Firebase chưa cấu hình), vẫn redirect về login
      debugPrint('⚠️ AuthGuard error: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthLoginScreen()),
            (route) => false,
          );
        }
      });
      
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
  }
}

