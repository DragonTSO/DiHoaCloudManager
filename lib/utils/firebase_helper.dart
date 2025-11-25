import 'package:firebase_core/firebase_core.dart';

/// Helper để kiểm tra Firebase có được khởi tạo không
class FirebaseHelper {
  /// Kiểm tra Firebase có sẵn sàng không
  static bool get isFirebaseInitialized {
    try {
      Firebase.app();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Lấy Firebase app nếu đã khởi tạo, null nếu chưa
  static FirebaseApp? get firebaseApp {
    try {
      return Firebase.app();
    } catch (e) {
      return null;
    }
  }
}

