import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';
import '../utils/storage.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<String>? _logController;
  bool _isConnected = false;
  String? _serverId;
  Timer? _pingTimer;

  Stream<String> get logStream => _logController?.stream ?? const Stream.empty();
  bool get isConnected => _isConnected;

  /// Kết nối WebSocket với server
  Future<bool> connect(String serverId) async {
    // Khởi tạo log controller sớm để có thể log lỗi
    if (_logController == null) {
      _logController = StreamController<String>.broadcast();
    }
    
    try {
      _serverId = serverId;
      
      // Lấy WebSocket token từ API
      final wsData = await ApiService.getWebSocketToken(serverId);
      if (wsData == null) {
        throw Exception('Không thể lấy WebSocket token');
      }

      final token = wsData['token'] as String?;
      final socket = wsData['socket'] as String?;
      
      if (token == null || socket == null) {
        throw Exception('Token hoặc socket URL không hợp lệ. Token: ${token != null}, Socket: ${socket != null}');
      }

      // Sử dụng trực tiếp socket URL từ API response (đã là full URL từ Wings daemon)
      // Không tự ghép với panelUrl
      String wsUrl = socket.trim();
      
      // Log raw socket URL để debug (ẩn token nếu có)
      final debugSocketUrl = wsUrl.contains('token=') 
          ? wsUrl.replaceAll(RegExp(r'token=[^&#]+'), 'token=***')
          : wsUrl;
      _logController?.add('[DEBUG] ========== WebSocket Info ==========');
      _logController?.add('[DEBUG] Raw socket URL từ API: $debugSocketUrl');
      _logController?.add('[DEBUG] Token có độ dài: ${token.length} ký tự');
      
      // Kiểm tra URL có phải Panel URL không (sai format)
      if (wsUrl.contains('/api/client/') || wsUrl.contains('/api/application/')) {
        throw Exception(
          '❌ LỖI: Socket URL trỏ về Panel API, không phải Wings daemon!\n'
          'URL nhận được: $debugSocketUrl\n'
          'URL đúng phải là Wings daemon: ws://<ip>:8080/api/servers/<id>/ws\n'
          'Panel API không xử lý WebSocket console.\n'
          'Vui lòng kiểm tra cấu hình Pterodactyl Panel.'
        );
      }
      
      // Kiểm tra endpoint WebSocket
      if (!wsUrl.contains('/ws') && !wsUrl.contains('/websocket')) {
        throw Exception(
          '❌ LỖI: Socket URL thiếu WebSocket endpoint!\n'
          'URL nhận được: $debugSocketUrl\n'
          'URL phải có: /api/servers/<id>/ws hoặc /api/servers/<id>/websocket'
        );
      }
      
      // Chuyển đổi protocol: https:// -> wss://, http:// -> ws://
      // CHỈ convert nếu URL đã đúng format (Wings daemon)
      // Không convert nếu URL là Panel URL (sẽ bị lỗi 403)
      String protocol;
      String urlWithoutProtocol;
      
      if (wsUrl.startsWith('wss://')) {
        // Đã đúng protocol WebSocket secure
        protocol = 'wss://';
        urlWithoutProtocol = wsUrl.substring(6);
        _logController?.add('[DEBUG] Protocol: wss:// (đã đúng)');
      } else if (wsUrl.startsWith('ws://')) {
        // Đã đúng protocol WebSocket
        protocol = 'ws://';
        urlWithoutProtocol = wsUrl.substring(5);
        _logController?.add('[DEBUG] Protocol: ws:// (đã đúng)');
      } else if (wsUrl.startsWith('https://')) {
        // Convert https -> wss
        protocol = 'wss://';
        urlWithoutProtocol = wsUrl.substring(8);
        _logController?.add('[DEBUG] Protocol: https:// -> wss:// (đã convert)');
      } else if (wsUrl.startsWith('http://')) {
        // Convert http -> ws
        protocol = 'ws://';
        urlWithoutProtocol = wsUrl.substring(7);
        _logController?.add('[DEBUG] Protocol: http:// -> ws:// (đã convert)');
      } else {
        // Không có protocol, thêm ws:// mặc định (cho localhost/internal IP)
        protocol = 'ws://';
        urlWithoutProtocol = wsUrl;
        _logController?.add('[DEBUG] Protocol: không có -> ws:// (thêm mặc định)');
      }
      
      // Rebuild URL với protocol đúng
      wsUrl = protocol + urlWithoutProtocol;
      
      // Parse URI
      final uri = Uri.parse(wsUrl);
      
      // Kiểm tra xem đã có token trong URL chưa
      final existingToken = uri.queryParameters['token'];
      
      // Thêm/update token vào query string
      final queryParams = Map<String, String>.from(uri.queryParameters);
      queryParams['token'] = token;
      
      // Tạo URI mới với query parameters đã update
      final finalUri = uri.replace(queryParameters: queryParams);
      
      // Log để debug (ẩn token)
      final finalUrlStr = finalUri.toString();
      final debugUrl = finalUrlStr.replaceAll(RegExp(r'token=[^&#]+'), 'token=***');
      _logController?.add('[DEBUG] WebSocket URL cuối cùng: $debugUrl');
      _logController?.add('[DEBUG] Scheme: ${finalUri.scheme}');
      _logController?.add('[DEBUG] Host: ${finalUri.host}');
      _logController?.add('[DEBUG] Port: ${finalUri.port}');
      _logController?.add('[DEBUG] Path: ${finalUri.path}');
      _logController?.add('[DEBUG] =================================');
      
      // Đảm bảo protocol là wss:// hoặc ws://
      if (finalUri.scheme != 'wss' && finalUri.scheme != 'ws') {
        throw Exception(
          '❌ WebSocket URL không hợp lệ!\n'
          'Protocol: ${finalUri.scheme} (phải là ws hoặc wss)\n'
          'URL: $debugUrl\n'
          'URL đúng format: wss://<host>:<port>/api/servers/<id>/ws?token=xxx'
        );
      }
      
      // Cảnh báo nếu đang kết nối tới Panel domain thay vì Wings IP
      if (finalUri.host.contains('panel') || finalUri.host.contains('enderdragonstudio') || finalUri.port == 443) {
        _logController?.add('[WARNING] ⚠️ Có thể đang kết nối tới Panel thay vì Wings daemon!');
        _logController?.add('[WARNING] Host: ${finalUri.host}, Port: ${finalUri.port}');
        _logController?.add('[WARNING] Wings daemon thường chạy trên port 8080, không phải 443');
      }
      
      _channel = WebSocketChannel.connect(finalUri);
      _isConnected = true;

      // Lắng nghe messages
      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          _logController?.add('[ERROR] Lỗi kết nối: $error');
          _isConnected = false;
        },
        onDone: () {
          _logController?.add('[INFO] Kết nối đã đóng');
          _isConnected = false;
        },
      );

      // Gửi ping định kỳ để giữ kết nối
      _startPingTimer();

      return true;
    } catch (e) {
      _isConnected = false;
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      _logController?.add('[ERROR] Không thể kết nối: $errorMsg');
      
      // Nếu có logController chưa được khởi tạo, tạo một cái tạm
      if (_logController == null) {
        _logController = StreamController<String>.broadcast();
      }
      
      return false;
    }
  }

  /// Xử lý message từ WebSocket
  void _handleMessage(dynamic message) {
    try {
      if (message is String) {
        final data = json.decode(message);
        final event = data['event'] as String?;
        final args = data['args'] as List?;

        if (event == 'console' && args != null && args.isNotEmpty) {
          // Console output
          final logLine = args[0] as String?;
          if (logLine != null) {
            _logController?.add(logLine);
          }
        } else if (event == 'status' && args != null && args.isNotEmpty) {
          // Status update
          final status = args[0] as String?;
          if (status != null) {
            _logController?.add('[STATUS] Server status: $status');
          }
        } else if (event == 'token expiring') {
          // Token sắp hết hạn, cần refresh
          _logController?.add('[WARNING] Token sắp hết hạn');
        } else if (event == 'token expired') {
          // Token đã hết hạn
          _logController?.add('[ERROR] Token đã hết hạn. Vui lòng kết nối lại.');
          disconnect();
        } else if (event == 'daemon error') {
          // Lỗi từ daemon
          final error = args?[0] as String?;
          _logController?.add('[DAEMON ERROR] ${error ?? "Unknown error"}');
        } else if (event == 'install output') {
          // Install output
          final output = args?[0] as String?;
          if (output != null) {
            _logController?.add(output);
          }
        } else if (event == 'install started') {
          _logController?.add('[INFO] Quá trình cài đặt đã bắt đầu');
        } else if (event == 'install completed') {
          _logController?.add('[INFO] Quá trình cài đặt đã hoàn thành');
        }
      }
    } catch (e) {
      // Nếu không parse được JSON, hiển thị raw message
      _logController?.add(message.toString());
    }
  }

  /// Gửi command tới server
  void sendCommand(String command) {
    if (!_isConnected || _channel == null) {
      _logController?.add('[ERROR] Chưa kết nối tới server');
      return;
    }

    try {
      // Pterodactyl WebSocket command format
      final message = json.encode({
        'event': 'send command',
        'args': [command],
      });
      
      _channel!.sink.add(message);
      _logController?.add('> $command');
    } catch (e) {
      _logController?.add('[ERROR] Không thể gửi command: ${e.toString()}');
    }
  }

  /// Gửi power signal qua WebSocket (tùy chọn)
  void sendPowerSignal(String signal) {
    if (!_isConnected || _channel == null) {
      return;
    }

    try {
      final message = json.encode({
        'event': 'set state',
        'args': [signal],
      });
      
      _channel!.sink.add(message);
    } catch (e) {
      _logController?.add('[ERROR] Không thể gửi power signal: ${e.toString()}');
    }
  }

  /// Bắt đầu ping timer để giữ kết nối
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(json.encode({
            'event': 'ping',
            'args': [],
          }));
        } catch (e) {
          // Ignore ping errors
        }
      } else {
        timer.cancel();
      }
    });
  }

  /// Ngắt kết nối WebSocket
  void disconnect() {
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _logController?.close();
    _logController = null;
  }
}

