import 'package:flutter/material.dart';
/// Màn hình chào khi mở app – người dùng chọn Đăng nhập hoặc Đăng ký
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
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
                const SizedBox(height: 24),
                const Text(
                  'DiHoaManager',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quản lý server Pterodactyl dễ dàng',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 48),
                _buildActionButton(
                  label: 'Đăng nhập',
                  icon: Icons.login,
                  colors: [Colors.white, Colors.white],
                  textColor: const Color(0xFF0D47A1),
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  label: 'Đăng ký',
                  icon: Icons.person_add,
                  colors: [Colors.orange.shade400!, Colors.deepOrange],
                  textColor: Colors.white,
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required List<Color> colors,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 240,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: textColor),
        label: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: colors.first,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 4,
        ).copyWith(
          backgroundColor: MaterialStateProperty.resolveWith(
            (states) => colors.first,
          ),
        ),
      ),
    );
  }
}

