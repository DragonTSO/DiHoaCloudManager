import 'dart:convert';
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

      if (baseUrl == null) {
        throw Exception('Panel URL chưa được cấu hình');
      }

      final url = Uri.parse('$baseUrl/api/client');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> serversData = data['data'] ?? [];
        
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
        throw Exception('API Key không hợp lệ');
      } else if (response.statusCode == 404) {
        throw Exception('Panel URL không đúng');
      } else {
        final errorBody = response.body;
        throw Exception('Lỗi khi lấy danh sách server: ${response.statusCode}\n$errorBody');
      }
    } catch (e) {
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
        final data = json.decode(response.body);
        final wsData = data['data'] as Map<String, dynamic>?;
        
        // Đảm bảo có token và socket
        if (wsData == null) {
          throw Exception('Response không có data. Full response: ${response.body}');
        }
        
        if (wsData['token'] == null || wsData['socket'] == null) {
          throw Exception('Response thiếu token hoặc socket. Keys: ${wsData.keys.toList()}, Full data: $wsData');
        }
        
        final socketUrl = wsData['socket'] as String;
        
        // Cảnh báo nếu socket URL có vẻ là Panel URL thay vì Wings daemon URL
        if (socketUrl.contains('/api/client/') || socketUrl.contains('/api/application/')) {
          throw Exception(
            '⚠️ SAI FORMAT: Socket URL trỏ về Panel API thay vì Wings daemon!\n'
            'URL nhận được: $socketUrl\n'
            'URL đúng phải là: ws://<wings-ip>:8080/api/servers/<id>/ws hoặc wss://...\n'
            'Kiểm tra lại cấu hình Pterodactyl Panel.'
          );
        }
        
        // Kiểm tra endpoint có phải WebSocket endpoint không
        if (!socketUrl.contains('/ws') && !socketUrl.contains('/websocket')) {
          throw Exception(
            '⚠️ Socket URL không có endpoint WebSocket (/ws hoặc /websocket)!\n'
            'URL nhận được: $socketUrl\n'
            'URL đúng phải có: /api/servers/<id>/ws'
          );
        }
        
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

