# DiHoaCloud - Pterodactyl Server Manager

<p align="center">
  <img src="assets/logo.png" alt="DiHoaCloud Logo" width="120"/>
</p>

<p align="center">
  <b>Quản lý server Pterodactyl ở mọi lúc, mọi nơi, mọi thời điểm.</b>
</p>

Ứng dụng Flutter đa nền tảng để quản lý server Pterodactyl thông qua Client API và WebSocket.

## ✨ Tính năng

- 🎨 **Giao diện Dark Mode** - UI hiện đại, đẹp mắt
- 🔐 **Xác thực** - Đăng nhập / Đăng ký tài khoản
- 📊 **Dashboard** - Tổng quan các panel và server
- 🖥️ **Multi-Panel** - Hỗ trợ kết nối nhiều Pterodactyl Panel cùng lúc
- 📋 **Danh sách Server** - Xem tất cả server với trạng thái realtime
- ⚡ **Điều khiển Server** - Start / Stop / Restart server
- 💻 **Console Realtime** - Xem log và gửi lệnh qua WebSocket
- 👤 **Profile** - Quản lý tài khoản và cài đặt
- 🔒 **Đổi mật khẩu** - Bảo mật tài khoản

## 📱 Screenshots

| Splash | Login | Dashboard |
|--------|-------|-----------|
| Welcome Screen | Login/Register | Server List |

| Server Control | Profile | Change Password |
|----------------|---------|-----------------|
| Console & Actions | Settings | Security |

## 🚀 App Flow

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│  1. Splash  │ --> │ 2. Login/Register│ --> │ 3. Dashboard│
└─────────────┘     └──────────────────┘     └──────┬──────┘
                                                    │
                    ┌───────────────────────────────┼───────────────────────────────┐
                    │                               │                               │
                    ▼                               ▼                               ▼
           ┌─────────────────┐           ┌──────────────────┐           ┌─────────────────┐
           │ 4. Add Panel    │           │ 5. Profile       │           │ Server Control  │
           │    Sheet (+)    │           │    Settings      │           │                 │
           └─────────────────┘           └────────┬─────────┘           └─────────────────┘
                                                  │
                                                  ▼
                                         ┌─────────────────┐
                                         │ 6. Change       │
                                         │    Password     │
                                         └─────────────────┘
```

## 📁 Cấu trúc Project

```
lib/
├── main.dart                      # Entry point & Routes
├── models/
│   ├── server.dart               # Model Server
│   ├── server_stats.dart         # Model Server Stats
│   └── panel.dart                # Model Panel (multi-panel support)
├── services/
│   ├── api_service.dart          # HTTP client cho Pterodactyl API
│   └── websocket_service.dart    # WebSocket cho console realtime
├── screens/
│   ├── splash_screen.dart        # Màn hình chào
│   ├── auth_screen.dart          # Đăng nhập / Đăng ký
│   ├── dashboard_screen.dart     # Dashboard chính
│   ├── add_panel_sheet.dart      # Bottom sheet thêm panel
│   ├── server_control_screen.dart # Điều khiển server
│   ├── profile_screen.dart       # Cài đặt profile
│   └── change_password_screen.dart # Đổi mật khẩu
├── widgets/
│   └── server_item.dart          # Widget server item
└── utils/
    ├── storage.dart              # Local storage (multi-panel)
    └── ansi_parser.dart          # Parse ANSI colors cho console
```

## 🔌 API Endpoints

Ứng dụng sử dụng các endpoint của Pterodactyl Client API:

| Method | Endpoint | Mô tả |
|--------|----------|-------|
| GET | `/api/client` | Lấy danh sách server |
| GET | `/api/client/servers/{id}/resources` | Lấy trạng thái và tài nguyên |
| POST | `/api/client/servers/{id}/power` | Gửi lệnh power |
| GET | `/api/client/servers/{id}/websocket` | Lấy WebSocket token |

## 🛠️ Cài đặt

### Yêu cầu

- Flutter SDK >= 3.10.0
- Android SDK (cho Android)
- Xcode (cho iOS/macOS)
- Pterodactyl Panel với Client API enabled
- Client API Key (bắt đầu với `ptlc_...`)

### Cài đặt

1. Clone repository:
```bash
git clone https://github.com/user/DiHoaCloudManager.git
cd DiHoaCloudManager
```

2. Cài đặt dependencies:
```bash
flutter pub get
```

3. Chạy ứng dụng:
```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Web (có thể gặp lỗi CORS)
flutter run -d chrome
```

## ⚠️ Lưu ý về CORS

Nếu chạy trên **Web**, bạn có thể gặp lỗi CORS do Pterodactyl Panel không cho phép cross-origin requests từ localhost.

**Giải pháp:**
- ✅ Chạy trên Android/iOS/Windows/macOS (khuyên dùng)
- ⚠️ Disable web security trong Chrome (chỉ để test):
```bash
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

## 📦 Dependencies

```yaml
dependencies:
  flutter: sdk
  cupertino_icons: ^1.0.8
  http: ^1.1.0
  web_socket_channel: ^2.4.0
  shared_preferences: ^2.2.2
  provider: ^6.1.1
```

## 🔐 Bảo mật

- Panel URL và API Key được lưu local bằng SharedPreferences
- Hỗ trợ lưu nhiều panel với mỗi panel có API key riêng
- WebSocket sử dụng token có thời hạn từ Pterodactyl API
- Không hardcode API keys trong code

## 🎨 Theme

App sử dụng dark theme với color scheme:

| Color | Hex | Usage |
|-------|-----|-------|
| Background | `#0A0E21` | Màu nền chính |
| Surface | `#1A1F3C` | Cards, inputs |
| Primary | `#6C8EEF` | Buttons, accents |
| Success | `#4CAF50` | Online status |
| Error | `#F44336` | Offline status |

## 📄 License

MIT License

## 👨‍💻 Tác giả

**DragonTSO**

---

<p align="center">
  Made with ❤️ using Flutter
</p>
