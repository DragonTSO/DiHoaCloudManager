import 'dart:async';
import 'package:flutter/material.dart';
import '../models/server.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class ServerControlScreen extends StatefulWidget {
  final Server server;

  const ServerControlScreen({
    super.key,
    required this.server,
  });

  @override
  State<ServerControlScreen> createState() => _ServerControlScreenState();
}

class _ServerControlScreenState extends State<ServerControlScreen> {
  final _commandController = TextEditingController();
  final _consoleScrollController = ScrollController();
  final List<String> _consoleLogs = [];
  
  Server? _currentServer;
  bool _isLoading = false;
  bool _isPowerActionLoading = false;
  bool _isConnecting = false;
  
  WebSocketService? _webSocketService;
  StreamSubscription<String>? _logSubscription;

  @override
  void initState() {
    super.initState();
    _currentServer = widget.server;
    _refreshServerStatus();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _webSocketService?.disconnect();
    _commandController.dispose();
    _consoleScrollController.dispose();
    super.dispose();
  }

  Future<void> _connectWebSocket() async {
    setState(() {
      _isConnecting = true;
      _consoleLogs.clear();
      _consoleLogs.add('[INFO] Đang kết nối tới server ${widget.server.name}...');
    });

    try {
      _webSocketService = WebSocketService();
      final connected = await _webSocketService!.connect(widget.server.id);

      if (connected && mounted) {
        setState(() {
          _isConnecting = false;
          _consoleLogs.add('[INFO] Đã kết nối thành công!');
        });

        // Lắng nghe log stream
        _logSubscription = _webSocketService!.logStream.listen((log) {
          if (mounted) {
            setState(() {
              _consoleLogs.add(log);
            });
            
            // Auto scroll to bottom
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_consoleScrollController.hasClients) {
                _consoleScrollController.animateTo(
                  _consoleScrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        });
      } else {
        setState(() {
          _isConnecting = false;
          _consoleLogs.add('[ERROR] Không thể kết nối. Vui lòng thử lại.');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _consoleLogs.add('[ERROR] Lỗi kết nối: ${e.toString()}');
        });
      }
    }
  }

  Future<void> _refreshServerStatus() async {
    try {
      final resources = await ApiService.getServerResources(_currentServer!.id);
      if (resources != null && mounted) {
        setState(() {
          _currentServer = Server(
            id: _currentServer!.id,
            name: _currentServer!.name,
            status: resources['current_state'] == 'running' ? 'running' : 'offline',
            cpu: resources['resources']?['cpu_absolute']?.toDouble(),
            ram: resources['resources']?['memory_bytes']?.toDouble(),
          );
        });
      }
    } catch (e) {
      // Ignore errors when refreshing
    }
  }

  void _sendCommand() {
    if (_commandController.text.trim().isEmpty) return;
    
    final command = _commandController.text.trim();
    _commandController.clear();
    
    if (_webSocketService?.isConnected ?? false) {
      // Gửi command qua WebSocket
      _webSocketService!.sendCommand(command);
    } else {
      // Nếu chưa kết nối, hiển thị thông báo
      setState(() {
        _consoleLogs.add('[ERROR] Chưa kết nối tới server. Vui lòng đợi...');
      });
      
      // Thử kết nối lại
      _connectWebSocket();
    }
  }

  Future<void> _handlePowerAction(String signal) async {
    if (_isPowerActionLoading) return;

    setState(() {
      _isPowerActionLoading = true;
    });

    try {
      final success = await ApiService.sendPowerSignal(_currentServer!.id, signal);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã gửi lệnh $signal server thành công'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Đợi một chút rồi refresh status
          await Future.delayed(const Duration(seconds: 2));
          await _refreshServerStatus();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể gửi lệnh. Vui lòng thử lại.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPowerActionLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.server.name),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Server status header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _currentServer?.isRunning ?? false
                        ? Colors.green 
                        : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _currentServer?.isRunning ?? false ? 'Đang chạy' : 'Đã tắt',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // WebSocket connection status
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: (_webSocketService?.isConnected ?? false)
                        ? Colors.green
                        : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () async {
                          setState(() => _isLoading = true);
                          await _refreshServerStatus();
                          setState(() => _isLoading = false);
                        },
                        tooltip: 'Làm mới trạng thái',
                      ),
                      if (!(_webSocketService?.isConnected ?? false))
                        IconButton(
                          icon: const Icon(Icons.replay),
                          onPressed: _connectWebSocket,
                          tooltip: 'Kết nối lại WebSocket',
                        ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Power control buttons (Remote style)
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // START button
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isPowerActionLoading ? null : () => _handlePowerAction('start'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isPowerActionLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'START',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // STOP button
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isPowerActionLoading ? null : () => _handlePowerAction('stop'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isPowerActionLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'STOP',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // RESTART button
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isPowerActionLoading ? null : () => _handlePowerAction('restart'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isPowerActionLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'RESTART',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          
          // Console area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _consoleLogs.isEmpty
                    ? Center(
                        child: _isConnecting
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text(
                                    'Đang kết nối...',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              )
                            : const Text(
                                'Console sẽ hiển thị ở đây...',
                                style: TextStyle(color: Colors.grey),
                              ),
                      )
                    : ListView.builder(
                        controller: _consoleScrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _consoleLogs.length,
                        itemBuilder: (context, index) {
                          final log = _consoleLogs[index];
                          Color textColor = Colors.green;
                          
                          // Màu sắc theo loại log
                          if (log.contains('[ERROR]')) {
                            textColor = Colors.red;
                          } else if (log.contains('[WARNING]')) {
                            textColor = Colors.orange;
                          } else if (log.contains('[INFO]') || log.contains('[STATUS]')) {
                            textColor = Colors.cyan;
                          } else if (log.startsWith('>')) {
                            textColor = Colors.yellow;
                          }
                          
                          return Text(
                            log,
                            style: TextStyle(
                              color: textColor,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
          
          // Command input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    decoration: InputDecoration(
                      hintText: 'Nhập lệnh...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendCommand(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _sendCommand,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Gửi',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

