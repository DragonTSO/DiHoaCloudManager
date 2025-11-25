import 'package:firebase_auth/firebase_auth.dart';
import '../utils/firebase_helper.dart';

/// Service để quản lý Firebase Authentication
class AuthService {
  FirebaseAuth? get _auth {
    if (!FirebaseHelper.isFirebaseInitialized) {
      return null;
    }
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      return null;
    }
  }

  /// Get current user
  User? get currentUser {
    if (_auth == null) return null;
    return _auth!.currentUser;
  }

  /// Stream để lắng nghe thay đổi auth state
  Stream<User?> get authStateChanges {
    if (_auth == null) {
      return Stream.value(null);
    }
    return _auth!.authStateChanges();
  }

  /// Đăng ký tài khoản mới với email và password
  Future<UserCredential?> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (_auth == null) {
      throw Exception('Firebase chưa được cấu hình. Vui lòng chạy "flutterfire configure"');
    }
    try {
      final userCredential = await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Lỗi đăng ký: ${e.toString()}');
    }
  }

  /// Đăng nhập với email và password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (_auth == null) {
      throw Exception('Firebase chưa được cấu hình. Vui lòng chạy "flutterfire configure"');
    }
    try {
      final userCredential = await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Lỗi đăng nhập: ${e.toString()}');
    }
  }

  /// Đăng xuất
  Future<void> signOut() async {
    if (_auth == null) return;
    try {
      await _auth!.signOut();
    } catch (e) {
      throw Exception('Lỗi đăng xuất: ${e.toString()}');
    }
  }

  /// Gửi email xác thực
  Future<void> sendEmailVerification() async {
    if (_auth == null) return;
    try {
      final user = _auth!.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      throw Exception('Lỗi gửi email xác thực: ${e.toString()}');
    }
  }

  /// Reset password
  Future<void> sendPasswordResetEmail(String email) async {
    if (_auth == null) {
      throw Exception('Firebase chưa được cấu hình. Vui lòng chạy "flutterfire configure"');
    }
    try {
      await _auth!.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Lỗi gửi email reset password: ${e.toString()}');
    }
  }

  /// Xử lý Firebase Auth Exception và trả về message tiếng Việt
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Mật khẩu quá yếu. Vui lòng chọn mật khẩu mạnh hơn.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng. Vui lòng đăng nhập hoặc dùng email khác.';
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'user-disabled':
        return 'Tài khoản này đã bị vô hiệu hóa.';
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này.';
      case 'wrong-password':
        return 'Mật khẩu không đúng.';
      case 'too-many-requests':
        return 'Quá nhiều yêu cầu. Vui lòng thử lại sau.';
      case 'operation-not-allowed':
        return 'Phương thức đăng nhập này không được phép.';
      case 'requires-recent-login':
        return 'Vui lòng đăng nhập lại để thực hiện thao tác này.';
      default:
        return 'Lỗi xác thực: ${e.message ?? e.code}';
    }
  }
}

