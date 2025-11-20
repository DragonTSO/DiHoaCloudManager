import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'api_service.dart';
import '../utils/storage.dart';
import '../models/server_stats.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  WebSocket? _rawWebSocket; // Raw WebSocket để set headers
  StreamController<String>? _logController;
  StreamController<ServerStats>? _statsController;
  bool _isConnected = false;
  String? _serverId;
  Timer? _pingTimer;
  String? _savedToken; // Lưu token để gửi auth message (tham khảo Java code)

  Stream<String> get logStream => _logController?.stream ?? const Stream.empty();
  Stream<ServerStats> get statsStream => _statsController?.stream ?? const Stream.empty();
  bool get isConnected => _isConnected;

  /// Kết nối WebSocket với server
  Future<bool> connect(String serverId) async {
    // Khởi tạo log controller sớm để có thể log lỗi
    if (_logController == null) {
      _logController = StreamController<String>.broadcast();
    }
    // Khởi tạo stats controller
    if (_statsController == null) {
      _statsController = StreamController<ServerStats>.broadcast();
    }
    
    try {
      _serverId = serverId;
      
      // Lấy WebSocket token từ API
      _logController?.add('[DEBUG] Đang lấy WebSocket token từ API...');
      final wsData = await ApiService.getWebSocketToken(serverId);
      if (wsData == null) {
        throw Exception('Không thể lấy WebSocket token - API trả về null');
      }

      // Log toàn bộ response để debug
      _logController?.add('[DEBUG] API Response keys: ${wsData.keys.toList()}');

      final token = wsData['token'] as String?;
      final socket = wsData['socket'] as String?;
      
      // Validate token và socket URL
      if (token == null || token.isEmpty) {
        throw Exception('Token không hợp lệ hoặc rỗng');
      }
      
      if (socket == null || socket.isEmpty) {
        throw Exception('WebSocket URL không hợp lệ hoặc rỗng');
      }
      
      // Log token và socket URL (ẩn token để bảo mật)
      _logController?.add('[DEBUG] Token length: ${token.length} characters');
      _logController?.add('[DEBUG] Token starts with: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
      _logController?.add('[DEBUG] Socket URL from API: ${socket.substring(0, socket.length > 100 ? 100 : socket.length)}...');

      // 1. Lấy URL gốc từ API (backend đã trả về URL đúng format)
      String wsUrl = socket.trim();
      
      // Log RAW URL từ API (trước khi xử lý)
      final rawDebugUrl = wsUrl.replaceAll(RegExp(r'token=[^&#]+'), 'token=***')
                               .replaceAll(RegExp(r'/wstoken/[^/?#]+'), '/wstoken/***');
      _logController?.add('[DEBUG] ========== RAW URL từ API ==========');
      _logController?.add('[DEBUG] Raw socket URL: $rawDebugUrl');
      _logController?.add('[DEBUG] Length: ${wsUrl.length}');
      _logController?.add('[DEBUG] Starts with: ${wsUrl.substring(0, wsUrl.length > 30 ? 30 : wsUrl.length)}...');
      
      // Loại bỏ ký tự không hợp lệ ở cuối URL (#, space, etc.)
      final originalLength = wsUrl.length;
      wsUrl = wsUrl.replaceAll(RegExp(r'[#\s]+$'), '');
      if (originalLength != wsUrl.length) {
        _logController?.add('[DEBUG] Removed ${originalLength - wsUrl.length} trailing character(s)');
      }
      
      // Log sau khi clean
      final cleanDebugUrl = wsUrl.replaceAll(RegExp(r'token=[^&#]+'), 'token=***')
                                  .replaceAll(RegExp(r'/wstoken/[^/?#]+'), '/wstoken/***');
      _logController?.add('[DEBUG] After clean: $cleanDebugUrl');
      
      // 2. Đổi protocol http/https -> ws/wss (chắc chắn)
      String finalWsUrl;
      String protocolInfo;
      
      // Log URL trước khi convert
      _logController?.add('[DEBUG] URL before conversion: ${wsUrl.substring(0, wsUrl.length > 80 ? 80 : wsUrl.length)}...');
      
      if (wsUrl.startsWith('wss://')) {
        finalWsUrl = wsUrl; // Đã đúng, không cần convert
        protocolInfo = 'Already wss:// (correct)';
      } else if (wsUrl.startsWith('ws://')) {
        finalWsUrl = wsUrl; // Đã đúng, không cần convert
        protocolInfo = 'Already ws:// (correct)';
      } else if (wsUrl.startsWith('https://')) {
        // Convert https:// -> wss://
        finalWsUrl = 'wss://' + wsUrl.substring(8); // Bỏ 'https://' (8 ký tự)
        protocolInfo = 'Converted: https:// -> wss://';
        _logController?.add('[DEBUG] ✅ CONVERTED https:// to wss://');
      } else if (wsUrl.startsWith('http://')) {
        // Convert http:// -> ws://
        finalWsUrl = 'ws://' + wsUrl.substring(7); // Bỏ 'http://' (7 ký tự)
        protocolInfo = 'Converted: http:// -> ws://';
        _logController?.add('[DEBUG] ✅ CONVERTED http:// to ws://');
      } else {
        // Không có protocol, thêm ws:// mặc định
        finalWsUrl = 'ws://$wsUrl';
        protocolInfo = 'Added ws:// prefix (no protocol found)';
        _logController?.add('[WARNING] No protocol found, added ws:// prefix');
      }
      
      _logController?.add('[DEBUG] Protocol conversion: $protocolInfo');
      _logController?.add('[DEBUG] URL after conversion: ${finalWsUrl.substring(0, finalWsUrl.length > 80 ? 80 : finalWsUrl.length)}...');
      
      // CRITICAL: Validate conversion đã thành công
      if (finalWsUrl.startsWith('https://') || finalWsUrl.startsWith('http://')) {
        throw Exception(
          '❌ CONVERSION FAILED: URL vẫn là HTTP/HTTPS sau khi convert!\n'
          'Original: ${wsUrl.substring(0, 50)}...\n'
          'After conversion: ${finalWsUrl.substring(0, 50)}...'
        );
      }
      
      if (!finalWsUrl.startsWith('wss://') && !finalWsUrl.startsWith('ws://')) {
        throw Exception(
          '❌ CONVERSION FAILED: URL không bắt đầu bằng ws:// hoặc wss://!\n'
          'URL: ${finalWsUrl.substring(0, 50)}...'
        );
      }
      
      // Loại bỏ lại ký tự # nếu có (sau khi convert có thể phát sinh)
      final beforeCleanLength = finalWsUrl.length;
      finalWsUrl = finalWsUrl.replaceAll(RegExp(r'[#\s]+$'), '');
      if (beforeCleanLength != finalWsUrl.length) {
        _logController?.add('[DEBUG] Removed ${beforeCleanLength - finalWsUrl.length} trailing character(s) after conversion');
      }
      
      // KHÔNG thêm ?token= nữa nếu backend đã nhúng token trong URL
      // Backend có thể dùng format: /wstoken/<token> hoặc đã có ?token= sẵn
      // Nếu backend yêu cầu query ?token= thì nó sẽ tự thêm sẵn trong socket response
      
      // Parse URI
      final finalUri = Uri.parse(finalWsUrl);
      
      // Log URL cuối cùng dùng để connect (ẩn token)
      final finalUrlStr = finalUri.toString();
      final debugFinalUrl = finalUrlStr.replaceAll(RegExp(r'token=[^&#]+'), 'token=***')
                                       .replaceAll(RegExp(r'/wstoken/[^/?#]+'), '/wstoken/***');
      _logController?.add('[DEBUG] ========== Final WebSocket URL ==========');
      _logController?.add('[DEBUG] Final URL (string): $debugFinalUrl');
      _logController?.add('[DEBUG] Final URL (original): ${finalWsUrl.substring(0, finalWsUrl.length > 100 ? 100 : finalWsUrl.length)}...');
      _logController?.add('[DEBUG] Scheme: ${finalUri.scheme}');
      _logController?.add('[DEBUG] Host: ${finalUri.host}');
      _logController?.add('[DEBUG] Port: ${finalUri.port}');
      _logController?.add('[DEBUG] Path: ${finalUri.path}');
      _logController?.add('[DEBUG] Query: ${finalUri.query}');
      _logController?.add('[DEBUG] ===========================================');
      
      // CRITICAL: Validate protocol phải là ws hoặc wss TRƯỚC KHI connect
      if (finalUri.scheme != 'ws' && finalUri.scheme != 'wss') {
        throw Exception(
          '❌ CRITICAL ERROR: Protocol phải là ws hoặc wss!\n'
          'Current scheme: ${finalUri.scheme}\n'
          'Raw URL from API: $rawDebugUrl\n'
          'After conversion: $debugFinalUrl\n'
          'Full URL string: ${finalWsUrl.substring(0, finalWsUrl.length > 150 ? 150 : finalWsUrl.length)}'
        );
      }
      
      // CRITICAL: Đảm bảo URL thực sự bắt đầu bằng ws:// hoặc wss://
      if (!finalWsUrl.startsWith('ws://') && !finalWsUrl.startsWith('wss://')) {
        throw Exception(
          '❌ CRITICAL ERROR: URL phải bắt đầu bằng ws:// hoặc wss://!\n'
          'Current URL: ${finalWsUrl.substring(0, finalWsUrl.length > 150 ? 150 : finalWsUrl.length)}\n'
          'First 20 chars: ${finalWsUrl.substring(0, finalWsUrl.length > 20 ? 20 : finalWsUrl.length)}'
        );
      }
      
      // Log một lần nữa để chắc chắn
      _logController?.add('[DEBUG] ✅ Validation passed - Connecting with: $debugFinalUrl');
      
      // Lấy Panel URL để set Origin header (QUAN TRỌNG để tránh 403)
      final panelUrl = await Storage.getPanelUrl();
      String? cleanPanelUrl;
      
      if (panelUrl != null) {
        // Đảm bảo panel URL không có trailing slash
        cleanPanelUrl = panelUrl.trim();
        if (cleanPanelUrl.endsWith('/')) {
          cleanPanelUrl = cleanPanelUrl.substring(0, cleanPanelUrl.length - 1);
        }
        _logController?.add('[DEBUG] Panel URL for Origin header: $cleanPanelUrl');
      } else {
        _logController?.add('[WARNING] ⚠️ Panel URL not found! This may cause 403 Forbidden');
      }
      
      // Pterodactyl: Dùng y nguyên socket URL từ API response
      // Socket URL đã được server tạo sẵn với token embedded
      // Lưu token để gửi auth message sau khi connect (tham khảo Java code)
      _savedToken = token;
      final savedToken = _savedToken; // Local variable để dùng trong scope
      
      // CRITICAL: Set Origin header = Panel URL để tránh 403 Forbidden
      // Pterodactyl Wings daemon kiểm tra Origin header phải khớp với Panel URL
      // Trong Flutter/Dart, việc set Origin header cho WebSocket rất khó
      // Giải pháp tốt nhất: Cấu hình Wings daemon allowed_origins
      
      if (cleanPanelUrl != null && cleanPanelUrl.isNotEmpty) {
        _logController?.add('[DEBUG] Panel URL available: $cleanPanelUrl');
        _logController?.add('[INFO] ⚠️ LƯU Ý: Flutter không thể set Origin header trực tiếp');
        _logController?.add('[INFO] 💡 Giải pháp: Cấu hình Wings daemon allowed_origins');
        _logController?.add('[INFO] 📝 File: /etc/pterodactyl/config.yml');
        _logController?.add('[INFO] 📝 Thêm: allowed_origins: ["*"] hoặc domain cụ thể');
      } else {
        _logController?.add('[WARNING] ⚠️ No Panel URL - Cannot set Origin header!');
        _logController?.add('[WARNING] This may cause 403 Forbidden error');
      }
      
      // Connect WebSocket (Flutter không hỗ trợ set Origin header trực tiếp)
      // Cần cấu hình Wings daemon để chấp nhận connections từ app
      
      // Log URL cuối cùng trước khi connect để debug
      final urlBeforeConnect = finalUri.toString();
      _logController?.add('[DEBUG] ========== Final Validation Before Connect ==========');
      _logController?.add('[DEBUG] Final URL string: ${urlBeforeConnect.substring(0, urlBeforeConnect.length > 150 ? 150 : urlBeforeConnect.length)}...');
      _logController?.add('[DEBUG] Final URL first 30 chars: ${urlBeforeConnect.substring(0, urlBeforeConnect.length > 30 ? 30 : urlBeforeConnect.length)}');
      _logController?.add('[DEBUG] Scheme: ${finalUri.scheme}');
      _logController?.add('[DEBUG] Host: ${finalUri.host}');
      _logController?.add('[DEBUG] Port: ${finalUri.port}');
      _logController?.add('[DEBUG] Path: ${finalUri.path}');
      _logController?.add('[DEBUG] Query params count: ${finalUri.queryParameters.length}');
      
      // CRITICAL: Validate một lần nữa trước khi connect
      if (finalUri.scheme == 'https' || finalUri.scheme == 'http') {
        throw Exception(
          '❌ CRITICAL ERROR: Scheme vẫn là HTTP/HTTPS!\n'
          'Scheme: ${finalUri.scheme}\n'
          'URL: ${urlBeforeConnect.substring(0, 100)}...\n'
          'Protocol conversion đã FAIL!\n'
          'Có thể do Uri.parse() không hoạt động đúng.'
        );
      }
      
      if (finalUri.scheme != 'ws' && finalUri.scheme != 'wss') {
        throw Exception(
          '❌ CRITICAL ERROR: Scheme không phải ws hoặc wss!\n'
          'Scheme: ${finalUri.scheme}\n'
          'URL: ${urlBeforeConnect.substring(0, 100)}...'
        );
      }
      
      if (!urlBeforeConnect.startsWith('wss://') && !urlBeforeConnect.startsWith('ws://')) {
        throw Exception(
          '❌ CRITICAL ERROR: URL string không bắt đầu bằng ws:// hoặc wss://!\n'
          'URL: ${urlBeforeConnect.substring(0, 100)}...\n'
          'First 20 chars: ${urlBeforeConnect.substring(0, urlBeforeConnect.length > 20 ? 20 : urlBeforeConnect.length)}'
        );
      }
      
      _logController?.add('[DEBUG] ✅ All validations passed');
      _logController?.add('[DEBUG] ===========================================');
      
      // Kết nối WebSocket
      // LƯU Ý: Flutter/Dart không hỗ trợ set Origin header trực tiếp cho WebSocket
      // Giải pháp: Cấu hình Wings daemon allowed_origins để chấp nhận connections
      _logController?.add('[INFO] ⚠️ Flutter không thể set Origin header cho WebSocket');
      _logController?.add('[INFO] 💡 Solution: Configure Wings daemon allowed_origins');
      _logController?.add('[INFO] 📝 File: /etc/pterodactyl/config.yml');
      if (cleanPanelUrl != null && cleanPanelUrl.isNotEmpty) {
        _logController?.add('[INFO] 📝 Add: allowed_origins: ["*"] or ["$cleanPanelUrl"]');
      } else {
        _logController?.add('[INFO] 📝 Add: allowed_origins: ["*"]');
      }
      _logController?.add('[INFO] 🔄 Then: systemctl restart wings');
      
      // THỬ CÁCH MỚI: HTTP Upgrade thủ công với Origin header
      try {
        if (cleanPanelUrl != null && cleanPanelUrl.isNotEmpty) {
          _logController?.add('[INFO] 🔧 Attempting HTTP upgrade with Origin header: $cleanPanelUrl');
          _logController?.add('[INFO] 💡 This method allows setting Origin header to avoid 403 errors');
          
          // Sử dụng HTTP upgrade thủ công để set Origin header
          try {
            final success = await _connectWithHttpUpgrade(finalUri, cleanPanelUrl);
            
            if (!success) {
              // Fallback về cách cũ nếu upgrade thất bại
              _logController?.add('[WARNING] HTTP upgrade failed, falling back to standard connection');
              _logController?.add('[WARNING] This may result in 403 error if Origin header is required');
              _channel = IOWebSocketChannel.connect(finalUri);
            } else {
              _logController?.add('[INFO] ✅ HTTP upgrade successful! Origin header set correctly');
            }
          } catch (upgradeError) {
            // Nếu có lỗi trong quá trình upgrade, fallback về cách cũ
            _logController?.add('[WARNING] HTTP upgrade error: $upgradeError');
            _logController?.add('[WARNING] Falling back to standard connection...');
            _channel = IOWebSocketChannel.connect(finalUri);
          }
        } else {
          // Không có Panel URL, dùng cách cũ
          _logController?.add('[WARNING] No Panel URL, using standard connection (may cause 403)');
          _channel = IOWebSocketChannel.connect(finalUri);
        }
      } catch (connectError) {
        // Parse error theo format của Pterodactyl API (tham khảo: https://pterodactyl-api-docs.netvpx.com/docs/error-handling)
        final errorStr = connectError.toString();
        _logController?.add('[ERROR] ========== WebSocket Connection Error ==========');
        
        // Kiểm tra các loại lỗi HTTP status codes theo Pterodactyl API
        if (errorStr.contains('403') || errorStr.contains('Forbidden')) {
          // 403 Forbidden - Wings daemon từ chối kết nối (Origin header)
          _logController?.add('');
          _logController?.add('[ERROR] ===========================================');
          _logController?.add('[ERROR] ❌ 403 Forbidden - Connection rejected by server');
          _logController?.add('[ERROR] ===========================================');
          _logController?.add('');
          _logController?.add('[INFO] 🔍 Nguyên nhân:');
          _logController?.add('[INFO] Wings daemon từ chối kết nối vì Origin header không được phép.');
          _logController?.add('[INFO] Flutter/Dart không thể tự set Origin header cho WebSocket.');
          _logController?.add('');
          _logController?.add('[INFO] ✅ Giải pháp (CẦN SỬA TRÊN SERVER):');
          _logController?.add('[INFO]');
          _logController?.add('[INFO] 1. SSH vào node server (Wings daemon):');
          // Extract host từ WebSocket URL để gợi ý node server
          try {
            final wsHost = finalUri.host;
            if (wsHost.isNotEmpty && wsHost != 'localhost' && wsHost != '127.0.0.1') {
              _logController?.add('[INFO]    ssh root@$wsHost');
              _logController?.add('[INFO]    (hoặc domain/IP của node Wings daemon của bạn)');
            } else {
              _logController?.add('[INFO]    ssh root@<node-server-ip-or-domain>');
              _logController?.add('[INFO]    (thay <node-server-ip-or-domain> bằng IP hoặc domain của node Wings)');
            }
          } catch (e) {
            _logController?.add('[INFO]    ssh root@<node-server-ip-or-domain>');
            _logController?.add('[INFO]    (thay <node-server-ip-or-domain> bằng IP hoặc domain của node Wings)');
          }
          _logController?.add('[INFO]');
          _logController?.add('[INFO] 2. Mở file config Wings:');
          _logController?.add('[INFO]    nano /etc/pterodactyl/config.yml');
          _logController?.add('[INFO]    (hoặc: nano /etc/pterodactyl/wings.yml)');
          _logController?.add('[INFO]');
          _logController?.add('[INFO] 3. Thêm hoặc sửa allowed_origins:');
          _logController?.add('[INFO]    allowed_origins:');
          _logController?.add('[INFO]      - "*"');
          _logController?.add('[INFO]');
          if (cleanPanelUrl != null && cleanPanelUrl.isNotEmpty) {
            _logController?.add('[INFO]    Hoặc an toàn hơn (sau khi test):');
            _logController?.add('[INFO]    allowed_origins:');
            _logController?.add('[INFO]      - "$cleanPanelUrl"');
            _logController?.add('[INFO]      - "null"  # cho app native');
            _logController?.add('[INFO]');
          }
          _logController?.add('[INFO] 4. Lưu file (Ctrl+O, Enter) và thoát (Ctrl+X)');
          _logController?.add('[INFO]');
          _logController?.add('[INFO] 5. Restart Wings daemon:');
          _logController?.add('[INFO]    systemctl restart wings');
          _logController?.add('');
          _logController?.add('[INFO] 6. Quay lại app và kết nối lại');
          _logController?.add('');
          _logController?.add('[ERROR] ===========================================');
          _logController?.add('[ERROR] LƯU Ý: Đây là lỗi SERVER-SIDE, không thể sửa từ app!');
          _logController?.add('[ERROR] ===========================================');
        } else if (errorStr.contains('401') || errorStr.contains('Unauthorized')) {
          // 401 Unauthorized - Invalid or missing authentication
          _logController?.add('[ERROR] 401 Unauthorized - Invalid or missing authentication');
          _logController?.add('[ERROR] Detail: The credentials provided were invalid.');
          _logController?.add('[ERROR] Solution: Check your API key and WebSocket token');
        } else if (errorStr.contains('404') || errorStr.contains('Not Found')) {
          // 404 Not Found - Resource doesn't exist
          _logController?.add('[ERROR] 404 Not Found - Resource doesn\'t exist');
          _logController?.add('[ERROR] Detail: The requested resource could not be found.');
          _logController?.add('[ERROR] Solution: Check WebSocket URL from API response');
          _logController?.add('[ERROR] URL used: ${finalUri.toString().substring(0, finalUri.toString().length > 100 ? 100 : finalUri.toString().length)}...');
        } else if (errorStr.contains('502') || errorStr.contains('Bad Gateway')) {
          // 502 Bad Gateway - Server is down or unreachable
          _logController?.add('[ERROR] 502 Bad Gateway - Server is down or unreachable');
          _logController?.add('[ERROR] Detail: An error was encountered while processing this request.');
          _logController?.add('[ERROR] Solution: Check if Wings daemon is running');
        } else if (errorStr.contains('429') || errorStr.contains('Too Many Requests')) {
          // 429 Too Many Requests - Rate limit exceeded
          _logController?.add('[ERROR] 429 Too Many Requests - Rate limit exceeded');
          _logController?.add('[ERROR] Solution: Wait a moment and try again');
        } else {
          // Generic error
          _logController?.add('[ERROR] Connection failed: $errorStr');
        }
        
        _logController?.add('[ERROR] Full error: $connectError');
        _logController?.add('[ERROR] ===========================================');
        rethrow;
      }
      
      _isConnected = true;

      // Pterodactyl: Gửi auth message ngay sau khi connect (tương tự Java onOpen)
      // Đây là bước QUAN TRỌNG để xác thực với Wings daemon
      if (savedToken != null && savedToken.isNotEmpty) {
        // Gửi auth message ngay sau khi connection established
        // Sử dụng Future.microtask để đảm bảo channel đã sẵn sàng
        Future.microtask(() {
          try {
            if (_channel != null && _isConnected) {
              final authMsg = json.encode({
                'event': 'auth',
                'args': [savedToken],
              });
              
              _channel!.sink.add(authMsg);
              _logController?.add('[DEBUG] ✅ Sent auth message with token');
            }
          } catch (e) {
            _logController?.add('[ERROR] Lỗi gửi auth message: $e');
          }
        });
      } else {
        _logController?.add('[WARNING] Không có token để gửi auth message!');
      }

      // Lắng nghe messages
      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          // Parse error theo format của Pterodactyl API
          final errorStr = error.toString();
          _logController?.add('[ERROR] ========== WebSocket Stream Error ==========');
          
          if (errorStr.contains('403') || errorStr.contains('Forbidden')) {
            _logController?.add('[ERROR] 403 Forbidden - Connection rejected by server');
            _logController?.add('[ERROR] Solution: Configure Wings daemon allowed_origins');
          } else if (errorStr.contains('401')) {
            _logController?.add('[ERROR] 401 Unauthorized - Authentication failed');
          } else {
            _logController?.add('[ERROR] WebSocket error: $error');
          }
          
          _logController?.add('[ERROR] ===========================================');
          _isConnected = false;
        },
        onDone: () {
          _logController?.add('[INFO] WebSocket connection closed');
          _isConnected = false;
        },
        cancelOnError: false, // Tiếp tục lắng nghe sau khi có lỗi
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

  /// Helper method để lấy tất cả keys từ JSON object (tham khảo Java code)
  String _getJsonKeys(Map<String, dynamic> json) {
    try {
      return json.keys.join(', ');
    } catch (e) {
      return 'error getting keys';
    }
  }

  /// Generate WebSocket key cho handshake (RFC 6455)
  String _generateWebSocketKey() {
    final random = Random.secure();
    final key = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(key);
  }

  /// Kết nối WebSocket bằng HTTP upgrade thủ công với Origin header
  /// Đây là cách để set Origin header khi Flutter không hỗ trợ trực tiếp
  Future<bool> _connectWithHttpUpgrade(Uri wsUri, String originUrl) async {
    HttpClient? httpClient;
    try {
      _logController?.add('[DEBUG] Starting HTTP upgrade to WebSocket...');
      
      // Tạo HttpClient
      httpClient = HttpClient();
      
      // Parse URI để lấy thông tin kết nối
      final host = wsUri.host;
      final port = wsUri.port > 0 
          ? wsUri.port 
          : (wsUri.scheme == 'wss' ? 443 : 80);
      
      // Build path với query string
      String path = wsUri.path;
      if (wsUri.query.isNotEmpty) {
        path += '?${wsUri.query}';
      }
      
      // Tạo HTTP URI (http/https thay vì ws/wss)
      final httpScheme = wsUri.scheme == 'wss' ? 'https' : 'http';
      final httpUri = Uri(
        scheme: httpScheme,
        host: host,
        port: port,
        path: path,
      );
      
      _logController?.add('[DEBUG] HTTP URI: $httpScheme://$host:$port$path');
      
      // Tạo HTTP request
      final request = await httpClient.openUrl('GET', httpUri);
      
      // Set WebSocket upgrade headers (RFC 6455)
      final wsKey = _generateWebSocketKey();
      request.headers.set('Upgrade', 'websocket');
      request.headers.set('Connection', 'Upgrade');
      request.headers.set('Sec-WebSocket-Key', wsKey);
      request.headers.set('Sec-WebSocket-Version', '13');
      request.headers.set('Sec-WebSocket-Protocol', '');
      
      // Set Origin header (QUAN TRỌNG để tránh 403!)
      request.headers.set('Origin', originUrl);
      _logController?.add('[DEBUG] Set Origin header: $originUrl');
      
      // Set User-Agent
      request.headers.set('User-Agent', 'DiHoaManager/1.0');
      
      // Gửi request
      _logController?.add('[DEBUG] Sending HTTP upgrade request...');
      final response = await request.close();
      
      // Kiểm tra status code (phải là 101 Switching Protocols)
      _logController?.add('[DEBUG] HTTP Response status: ${response.statusCode}');
      
      if (response.statusCode == 101) {
        // Upgrade thành công!
        _logController?.add('[DEBUG] ✅ HTTP upgrade successful! Status 101 Switching Protocols');
        
        // Kiểm tra upgrade header trong response
        final upgradeHeader = response.headers.value('upgrade');
        final connectionHeader = response.headers.value('connection');
        _logController?.add('[DEBUG] Response Upgrade: $upgradeHeader');
        _logController?.add('[DEBUG] Response Connection: $connectionHeader');
        
        // Detach socket từ HTTP response
        final socket = await response.detachSocket();
        
        // Tạo WebSocket từ socket đã upgrade
        _rawWebSocket = WebSocket.fromUpgradedSocket(
          socket,
          serverSide: false,
        );
        
        // Tạo IOWebSocketChannel từ raw WebSocket
        _channel = IOWebSocketChannel(_rawWebSocket!);
        
        _logController?.add('[INFO] ✅ WebSocket connected with Origin header using HTTP upgrade');
        
        // Đóng HttpClient (không cần nữa)
        httpClient.close();
        httpClient = null;
        
        return true;
      } else {
        // Upgrade thất bại
        String errorBody = '';
        try {
          errorBody = await response.transform(utf8.decoder).join();
        } catch (e) {
          errorBody = 'Could not read response body: $e';
        }
        
        _logController?.add('[ERROR] HTTP upgrade failed: Status ${response.statusCode}');
        
        // Kiểm tra lỗi 403 cụ thể
        if (response.statusCode == 403) {
          _logController?.add('[ERROR] ❌ 403 Forbidden - Origin header may not be accepted');
          _logController?.add('[ERROR] Origin header was set to: $originUrl');
          _logController?.add('[ERROR] Response headers: ${response.headers}');
          if (errorBody.isNotEmpty) {
            _logController?.add('[ERROR] Response body: ${errorBody.substring(0, errorBody.length > 200 ? 200 : errorBody.length)}');
          }
        } else {
          _logController?.add('[ERROR] Response headers: ${response.headers}');
          if (errorBody.isNotEmpty) {
            _logController?.add('[ERROR] Response body: ${errorBody.substring(0, errorBody.length > 200 ? 200 : errorBody.length)}');
          }
        }
        
        httpClient.close();
        httpClient = null;
        return false;
      }
    } catch (e) {
      _logController?.add('[ERROR] HTTP upgrade error: $e');
      if (httpClient != null) {
        httpClient.close();
      }
      return false;
    }
  }

  /// Xử lý message từ WebSocket (tham khảo từ Java code đã hoạt động)
  void _handleMessage(dynamic message) {
    try {
      if (message is String) {
        // Log message length để debug (tham khảo Java)
        final messageLength = message.length;
        
        // Nếu không phải JSON, gửi trực tiếp (có thể là plain text console output)
        try {
          final data = json.decode(message) as Map<String, dynamic>;
          final event = data['event'] as String?;
          final args = data['args'];

          // Log parsed event và keys để debug (chỉ log khi cần debug)
          // _logController?.add('[DEBUG] WebSocket message received (length: $messageLength)');
          // _logController?.add('[DEBUG] Parsed event: "$event", full JSON keys: ${_getJsonKeys(data)}');

          // Pterodactyl: Event name chính xác là "console output" (có khoảng trắng)
          if (event == 'console output') {
            // Parse console output với nhiều format khác nhau (tham khảo Java)
            _handleConsoleOutput(args);
          } else if (event == 'console') {
            // Fallback: Nếu event là "console" thay vì "console output"
            _handleConsoleOutput(args);
          } else if (event == 'auth_success') {
            // Auth thành công, có thể bắt đầu nhận console output
            _logController?.add('[INFO] WebSocket authentication successful');
          } else if (event == 'stats') {
            // Stats event - Pterodactyl gửi định kỳ để cập nhật CPU/RAM/Disk/Network
            // Parse stats và emit lên stream để UI cập nhật
            try {
              if (args != null && args is List && args.isNotEmpty) {
                final statsData = args[0];
                final stats = ServerStats.fromJson(statsData);
                _statsController?.add(stats);
              }
            } catch (e) {
              // Ignore parse errors, stats sẽ được gửi lại
            }
          } else if (event == 'status' && args != null) {
            // Status update
            final status = args is List && args.isNotEmpty ? args[0].toString() : args.toString();
            _logController?.add('[STATUS] Server status: $status');
          } else if (event == 'error' || event == 'exception') {
            // Xử lý error event từ server
            String errorMsg = 'Unknown error';
            if (args is List && args.isNotEmpty) {
              errorMsg = args[0].toString();
            } else if (args is String) {
              errorMsg = args;
            } else if (data['message'] != null) {
              errorMsg = data['message'].toString();
            }
            _logController?.add('[SERVER ERROR] $errorMsg');
          } else if (event == 'token' || event == 'auth') {
            // Token/auth event - bỏ qua (không log để tránh spam)
            // _logController?.add('[DEBUG] Received auth/token event');
          } else if (event == 'token expiring') {
            // Token sắp hết hạn, cần refresh
            _logController?.add('[WARNING] Token sắp hết hạn');
          } else if (event == 'token expired') {
            // Token đã hết hạn
            _logController?.add('[ERROR] Token đã hết hạn. Vui lòng kết nối lại.');
            disconnect();
          } else if (event == 'daemon error') {
            // Lỗi từ daemon
            final error = args is List && args.isNotEmpty ? args[0].toString() : (args?.toString() ?? 'Unknown error');
            _logController?.add('[DAEMON ERROR] $error');
          } else if (event == 'install output') {
            // Install output - parse như console output
            _handleConsoleOutput(args);
          } else if (event == 'install started') {
            _logController?.add('[INFO] Quá trình cài đặt đã bắt đầu');
          } else if (event == 'install completed') {
            _logController?.add('[INFO] Quá trình cài đặt đã hoàn thành');
          } else if (event == null || event.isEmpty) {
            // Không có event name - có thể là console output trực tiếp
            // _logController?.add('[DEBUG] Message without event, attempting to parse as console output');
            if (args != null) {
              _handleConsoleOutput(args);
            } else {
              _logController?.add(message);
            }
          } else {
            // Các event khác - thử parse như console output (log chỉ khi không parse được)
            if (args != null) {
              _handleConsoleOutput(args);
            } else {
              // Fallback: gửi toàn bộ JSON nếu không parse được
              _logController?.add('[DEBUG] Unknown event: "$event", full JSON: $message');
              _logController?.add(message);
            }
          }
        } catch (e) {
          // Nếu không parse được JSON, gửi trực tiếp (có thể là plain text console output)
          // _logController?.add('[DEBUG] Non-JSON message, sending as plain text');
          _logController?.add(message);
        }
      } else {
        // Nếu không phải String, convert sang string
        _logController?.add(message.toString());
      }
    } catch (e) {
      // Nếu có lỗi xử lý, hiển thị raw message
      _logController?.add('[ERROR] Error processing message: $e');
      _logController?.add(message.toString());
    }
  }

  /// Parse console output từ args với nhiều format khác nhau (tham khảo Java code)
  /// Args có thể là: String, List (array), hoặc Map (object)
  void _handleConsoleOutput(dynamic args) {
    try {
      if (args == null) {
        return;
      }

      if (args is String) {
        // Nếu args là string, gửi trực tiếp
        _logController?.add(args);
        return;
      }

      if (args is List && args.isNotEmpty) {
        // Nếu args là array, xử lý từng item
        final buffer = StringBuffer();
        for (var i = 0; i < args.length; i++) {
          if (i > 0) buffer.write('\n');
          
          final item = args[i];
          if (item == null) continue;

          if (item is String) {
            // Item là string
            buffer.write(item);
          } else if (item is Map) {
            // Item là object - thử lấy text, data, hoặc message
            final itemMap = Map<String, dynamic>.from(item);
            final text = itemMap['text'] ?? itemMap['data'] ?? itemMap['message'] ?? '';
            if (text.toString().isNotEmpty) {
              buffer.write(text.toString());
            } else {
              // Fallback: gửi toàn bộ object
              buffer.write(json.encode(item));
            }
          } else {
            // Item là kiểu khác, convert sang string
            buffer.write(item.toString());
          }
        }
        
        final result = buffer.toString();
        if (result.isNotEmpty) {
          _logController?.add(result);
        }
        return;
      }

      if (args is Map) {
        // Nếu args là object, thử lấy text, data, hoặc message
        final argsMap = Map<String, dynamic>.from(args);
        final text = argsMap['text'] ?? argsMap['data'] ?? argsMap['message'] ?? '';
        if (text.toString().isNotEmpty) {
          _logController?.add(text.toString());
        } else {
          // Fallback: thử lấy toàn bộ data field
          final data = argsMap['data'];
          if (data != null) {
            _handleConsoleOutput(data);
          } else {
            // Fallback cuối cùng: gửi toàn bộ JSON
            // Log warning nếu không parse được
            _logController?.add('[WARNING] Could not parse console output, sending raw JSON. Available keys: ${_getJsonKeys(argsMap)}');
            _logController?.add(json.encode(args));
          }
        }
        return;
      }

      // Fallback: convert sang string
      _logController?.add(args.toString());
    } catch (e) {
      // Nếu có lỗi parse, gửi raw args
      _logController?.add('[ERROR] Error parsing console output: $e');
      _logController?.add('[ERROR] Raw args: $args');
    }
  }

  /// Gửi command tới server
  void sendCommand(String command) {
    if (!_isConnected || _channel == null) {
      _logController?.add('[ERROR] Chưa kết nối tới server');
      return;
    }

    try {
      // Pterodactyl: Event name chính xác là "send command" (có khoảng trắng)
      // Args phải là array, không phải string
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

  /// Ngắt kết nối WebSocket (tham khảo Java code)
  void disconnect() {
    _pingTimer?.cancel();
    
    // Đóng WebSocket channel
    if (_channel != null) {
      try {
        _channel!.sink.close(1000, "Normal closure");
      } catch (e) {
        // Ignore errors when closing
      }
      _channel = null;
    }
    
    // Đóng raw WebSocket nếu có
    if (_rawWebSocket != null) {
      try {
        _rawWebSocket!.close(1000, "Normal closure");
      } catch (e) {
        // Ignore errors when closing
      }
      _rawWebSocket = null;
    }
    
    _isConnected = false;
    _serverId = null;
    _savedToken = null;
    
    // Không đóng logController và statsController ở đây vì có thể còn cần
    // Chỉ đóng khi dispose hoàn toàn
  }
  
  /// Dispose resources (đóng tất cả controllers)
  void dispose() {
    _logController?.close();
    _logController = null;
    _statsController?.close();
    _statsController = null;
  }
}

