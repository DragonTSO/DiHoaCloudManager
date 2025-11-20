# DiHoaManager - Pterodactyl Server Manager

Ứng dụng Android Flutter để quản lý server Pterodactyl thông qua Client API và WebSocket.

## Tính năng

- 🔐 **Đăng nhập**: Nhập Panel URL và Client API Key
- 📋 **Danh sách Server**: Xem danh sách tất cả server với trạng thái (running/offline)
- ⚡ **Điều khiển Server**: Start / Stop / Restart server
- 💻 **Console Realtime**: Xem log console và gửi lệnh trực tiếp tới server qua WebSocket

## API Endpoints

Ứng dụng sử dụng các endpoint sau của Pterodactyl Client API:

- `GET /api/client` - Lấy danh sách server
- `GET /api/client/servers/{id}/resources` - Lấy trạng thái và tài nguyên server
- `POST /api/client/servers/{id}/power` - Gửi lệnh power (start/stop/restart)
- `GET /api/client/servers/{id}/websocket` - Lấy WebSocket token và URL

## Cấu trúc Project

```
lib/
├── main.dart                 # Entry point
├── models/
│   └── server.dart          # Model cho server
├── services/
│   ├── api_service.dart     # HTTP client cho Pterodactyl API
│   └── websocket_service.dart # WebSocket cho console realtime
├── screens/
│   ├── login_screen.dart    # Màn hình đăng nhập
│   ├── server_list_screen.dart # Màn hình danh sách server
│   └── server_control_screen.dart # Màn hình điều khiển server
├── widgets/
│   └── server_item.dart     # Widget hiển thị item server
└── utils/
    └── storage.dart         # Lưu trữ Panel URL và API Key
```

## Cài đặt

1. Clone repository:
```bash
git clone https://github.com/DragonTSO/DiHoaCloudManager.git
cd DiHoaCloudManager
```

2. Cài đặt dependencies:
```bash
flutter pub get
```

3. Chạy ứng dụng:
```bash
flutter run
```

## Dependencies

- `http: ^1.1.0` - HTTP client
- `web_socket_channel: ^2.4.0` - WebSocket client
- `shared_preferences: ^2.2.2` - Local storage
- `provider: ^6.1.1` - State management

## Yêu cầu

- Flutter SDK >= 3.10.0
- Android SDK (cho Android app)
- Pterodactyl Panel với Client API enabled
- Client API Key với quyền truy cập server

## Lưu ý Bảo mật

- Panel URL và API Key được lưu trữ local trên thiết bị bằng SharedPreferences
- Không hardcode API keys trong code
- WebSocket sử dụng token có thời hạn từ Pterodactyl API

## License

MIT License

## Tác giả

DragonTSO
