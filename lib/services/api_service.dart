import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/server.dart';
import '../utils/storage.dart';

class ApiService {
  static Future<String?> _getBaseUrl() async {
    final panelUrl = await Storage.getPanelUrl();
    if (panelUrl == null) return null;
    // Đảm bảo URL không có dấu / ở cuối
    return panelUrl.endsWith('/') ? panelUrl.substring(0, panelUrl.length - 1) : panelUrl;
  }

  static Future<String?> _getApiKey() async {
    return await Storage.getApiKey();
  }

  static Future<Map<String, String>> _getHeaders() async {
    final apiKey = await _getApiKey();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
  }

  /// Lấy danh sách server từ Pterodactyl API
  /// GET /api/client
  static Future<List<Server>> getServers() async {
    try {
      final baseUrl = await _getBaseUrl();
      final headers = await _getHeaders();

      debugPrint('[API] getServers - Base URL: $baseUrl');
      debugPrint('[API] getServers - API Key: ${headers['Authorization']?.substring(0, 20)}...');

      if (baseUrl == null) {
        throw Exception('Panel URL chưa được cấu hình');
      }

      final url = Uri.parse('$baseUrl/api/client');
      debugPrint('[API] getServers - Request URL: $url');
      
      final response = await http.get(url, headers: headers);
      debugPrint('[API] getServers - Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> serversData = data['data'] ?? [];
        debugPrint('[API] getServers - Found ${serversData.length} servers in response');
        
        // Parse danh sách server từ response
        List<Server> servers = [];
        for (var serverData in serversData) {
          final attributes = serverData['attributes'] ?? {};
          final serverId = attributes['identifier'] ?? 
                          attributes['id']?.toString() ?? '';
          
          // Tạo server từ attributes
          Server server = Server(
            id: serverId,
            name: attributes['name'] ?? 'Unknown Server',
            status: 'offline', // Mặc định, sẽ cập nhật sau nếu có resources
          );
          
          // Thử lấy resources để biết trạng thái thực tế
          try {
            final resources = await getServerResources(serverId);
            if (resources != null) {
              server = Server(
                id: server.id,
                name: server.name,
                status: resources['current_state'] == 'running' ? 'running' : 'offline',
                cpu: resources['resources']?['cpu_absolute']?.toDouble(),
                ram: resources['resources']?['memory_bytes']?.toDouble(),
              );
            }
          } catch (e) {
            // Nếu không lấy được resources, giữ nguyên status mặc định
          }
          
          servers.add(server);
        }
        
        return servers;
      } else if (response.statusCode == 401) {
        debugPrint('[API] getServers - 401 Unauthorized');
        throw Exception('API Key không hợp lệ');
      } else if (response.statusCode == 404) {
        debugPrint('[API] getServers - 404 Not Found');
        throw Exception('Panel URL không đúng');
      } else {
        final errorBody = response.body;
        debugPrint('[API] getServers - Error ${response.statusCode}: $errorBody');
        throw Exception('Lỗi khi lấy danh sách server: ${response.statusCode}\n$errorBody');
      }
    } catch (e) {
      debugPrint('[API] getServers - Exception: $e');
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }

  /// Lấy thông tin resources của server
  /// GET /api/client/servers/{id}/resources
  static Future<Map<String, dynamic>?> getServerResources(String serverId) async {
    try {
      final baseUrl = await _getBaseUrl();
      final headers = await _getHeaders();

      if (baseUrl == null) {
        return null;
      }

      final url = Uri.parse('$baseUrl/api/client/servers/$serverId/resources');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return json.decode(response.body)['attributes'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Gửi lệnh power (start/stop/restart)
  /// POST /api/client/servers/{id}/power
  /// Theo tài liệu: https://pterodactyl-api-docs.netvpx.com/docs/source-references
  static Future<bool> sendPowerSignal(String serverId, String signal) async {
    try {
      final baseUrl = await _getBaseUrl();
      final headers = await _getHeaders();

      if (baseUrl == null) {
        throw Exception('Panel URL chưa được cấu hình');
      }

      // Validate signal
      final validSignals = ['start', 'stop', 'restart', 'kill'];
      if (!validSignals.contains(signal.toLowerCase())) {
        throw Exception('Signal không hợp lệ: $signal');
      }

      final url = Uri.parse('$baseUrl/api/client/servers/$serverId/power');
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({'signal': signal.toLowerCase()}),
      );

      if (response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('API Key không hợp lệ');
      } else if (response.statusCode == 403) {
        throw Exception('Không có quyền thực hiện hành động này');
      } else if (response.statusCode == 404) {
        throw Exception('Server không tồn tại');
      } else if (response.statusCode == 422) {
        // Parse validation errors
        try {
          final errorData = json.decode(response.body);
          final errors = errorData['errors'] ?? {};
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            throw Exception(firstError.first);
          }
        } catch (_) {}
        throw Exception('Dữ liệu không hợp lệ');
      } else {
        final errorBody = response.body;
        throw Exception('Lỗi ${response.statusCode}: ${errorBody.isNotEmpty ? errorBody : "Không thể gửi lệnh"}');
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }

  /// Lấy WebSocket token
  /// GET /api/client/servers/{id}/websocket
  /// Trả về {token: string, socket: string} từ data của response
  static Future<Map<String, dynamic>?> getWebSocketToken(String serverId) async {
    try {
      final baseUrl = await _getBaseUrl();
      final headers = await _getHeaders();

      if (baseUrl == null) {
        throw Exception('Panel URL chưa được cấu hình');
      }

      final url = Uri.parse('$baseUrl/api/client/servers/$serverId/websocket');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final responseBody = response.body;
        final data = json.decode(responseBody);
        final wsData = data['data'] as Map<String, dynamic>?;
        
        // Đảm bảo có token và socket
        if (wsData == null) {
          throw Exception('Response không có data. Full response: $responseBody');
        }
        
        if (wsData['token'] == null || wsData['socket'] == null) {
          throw Exception('Response thiếu token hoặc socket. Keys: ${wsData.keys.toList()}, Full data: $wsData');
        }
        
        // Log để debug (ẩn token)
        final socketUrl = wsData['socket'] as String;
        final debugSocket = socketUrl.replaceAll(RegExp(r'token=[^&#]+'), 'token=***')
                                     .replaceAll(RegExp(r'/wstoken/[^/?#]+'), '/wstoken/***');
        print('[API DEBUG] WebSocket response:');
        print('[API DEBUG] - Socket URL: $debugSocket');
        print('[API DEBUG] - Socket starts with: ${socketUrl.substring(0, socketUrl.length > 20 ? 20 : socketUrl.length)}...');
        print('[API DEBUG] - Token length: ${(wsData['token'] as String).length}');
        
        // Trả về data từ backend (backend đã trả về URL đúng format)
        // Không validate format vì backend có thể dùng các format khác nhau:
        // - /api/servers/<id>/ws?token=xxx
        // - /api/servers/<id>/wstoken/xxx
        // - /websocket?token=xxx
        // v.v.
        return wsData;
      } else if (response.statusCode == 401) {
        throw Exception('API Key không hợp lệ');
      } else if (response.statusCode == 403) {
        throw Exception('Không có quyền truy cập WebSocket');
      } else if (response.statusCode == 404) {
        throw Exception('Server không tồn tại');
      } else {
        throw Exception('Lỗi ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Lỗi kết nối: ${e.toString()}');
    }
  }
}

