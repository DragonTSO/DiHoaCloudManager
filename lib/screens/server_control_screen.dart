import 'dart:async';
import 'package:flutter/material.dart';
import '../models/server.dart';
import '../models/server_stats.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../utils/ansi_parser.dart';

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
  ServerStats? _currentStats;
  bool _isLoading = false;
  bool _isPowerActionLoading = false;
  bool _isConnecting = false;
  
  WebSocketService? _webSocketService;
  StreamSubscription<String>? _logSubscription;
  StreamSubscription<ServerStats>? _statsSubscription;

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
    _statsSubscription?.cancel();
    _webSocketService?.disconnect();
    _commandController.dispose();
    _consoleScrollController.dispose();
    super.dispose();
  }

  Future<void> _connectWebSocket() async {
    setState(() {
      _isConnecting = true;
      _consoleLogs.clear();
      _consoleLogs.add('[INFO] Connecting to ${widget.server.name}...');
    });

    try {
      _webSocketService = WebSocketService();
      final connected = await _webSocketService!.connect(widget.server.id);

      if (connected && mounted) {
        setState(() {
          _isConnecting = false;
          _consoleLogs.add('[INFO] Connected successfully!');
        });

        _logSubscription = _webSocketService!.logStream.listen((log) {
          if (mounted) {
            setState(() {
              _consoleLogs.add(log);
            });
            
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

        _statsSubscription = _webSocketService!.statsStream.listen((stats) {
          if (mounted) {
            setState(() {
              _currentStats = stats;
            });
          }
        });
      } else {
        setState(() {
          _isConnecting = false;
          _consoleLogs.add('[ERROR] Failed to connect. Please try again.');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _consoleLogs.add('[ERROR] Connection error: ${e.toString()}');
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
      _webSocketService!.sendCommand(command);
    } else {
      setState(() {
        _consoleLogs.add('[ERROR] Not connected to server.');
      });
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
              content: Text('$signal command sent successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          await Future.delayed(const Duration(seconds: 2));
          await _refreshServerStatus();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
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
    final isRunning = _currentServer?.isRunning ?? false;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
          widget.server.name,
          style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
            fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
                color: isRunning
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isRunning ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
              decoration: BoxDecoration(
                      color: isRunning ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isRunning ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: isRunning ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                                ),
                              ],
                            ),
                          ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Power control buttons
          _buildPowerButtons(),
          
          // Resources section
          _buildResourcesSection(),
          
          // Console section
          Expanded(
            child: _buildConsoleSection(),
          ),
          
          // Command input
          _buildCommandInput(),
        ],
      ),
    );
  }

  Widget _buildPowerButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildPowerButton(
              label: 'Start',
              icon: Icons.play_arrow,
              color: Colors.green,
              onPressed: () => _handlePowerAction('start'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildPowerButton(
              label: 'Stop',
              icon: Icons.stop,
              color: Colors.red,
              onPressed: () => _handlePowerAction('stop'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildPowerButton(
              label: 'Restart',
              icon: Icons.refresh,
              color: Colors.orange,
              onPressed: () => _handlePowerAction('restart'),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPowerButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _isPowerActionLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: _isPowerActionLoading
              ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourcesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
        color: const Color(0xFF1A1F3C),
        borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                        const Text(
            'Resources',
                          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
          const SizedBox(height: 16),
                    Row(
                      children: [
              _buildResourceItem(
                'CPU',
                _currentStats != null
                    ? '${_currentStats!.cpuPercent.toStringAsFixed(0)}%'
                    : '${_currentServer?.cpu?.toStringAsFixed(0) ?? '0'}%',
                Colors.blue,
              ),
              const SizedBox(width: 24),
              _buildResourceItem(
                'RAM',
                _currentStats != null
                    ? '${_currentStats!.ramUsedFormatted}/${_currentStats!.ramLimitFormatted}'
                    : _formatRam(_currentServer?.ram),
                Colors.purple,
              ),
              const SizedBox(width: 24),
              _buildResourceItem(
                'DISK',
                _currentStats != null
                    ? _currentStats!.diskUsedFormatted
                    : 'N/A',
                Colors.orange,
              ),
            ],
                        ),
                      ],
                    ),
    );
  }

  Widget _buildResourceItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
          label,
                              style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
                  Text(
          value,
                    style: TextStyle(
            color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildConsoleSection() {
    return Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
          color: const Color(0xFF30363D),
                width: 1,
              ),
                ),
              child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Console header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                  color: Color(0xFF30363D),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                  width: 10,
                  height: 10,
                          decoration: BoxDecoration(
                            color: (_webSocketService?.isConnected ?? false)
                                ? Colors.green
                                : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                const Text(
                          'Console',
                          style: TextStyle(
                    color: Colors.white,
                            fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                      ],
                    ),
                  ),
                  // Console content
                  Expanded(
                    child: _consoleLogs.isEmpty
                        ? Center(
                            child: _isConnecting
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.blue.shade400,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                'Connecting to console...',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                            'Console output will appear here...',
                                    style: TextStyle(
                              color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                          )
                        : ListView.builder(
                            controller: _consoleScrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: _consoleLogs.length,
                            itemBuilder: (context, index) {
                              final log = _consoleLogs[index];
                              
                              Color defaultColor = Colors.green.shade300;
                              if (log.contains('[ERROR]')) {
                                defaultColor = Colors.red.shade300;
                              } else if (log.contains('[WARNING]')) {
                                defaultColor = Colors.orange.shade300;
                              } else if (log.contains('[INFO]') || log.contains('[STATUS]')) {
                                defaultColor = Colors.cyan.shade300;
                              } else if (log.startsWith('>')) {
                                defaultColor = Colors.yellow.shade300;
                              }
                              
                              final textSpan = AnsiParser.parseAnsi(log, defaultColor: defaultColor);
                              
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: RichText(
                                text: textSpan,
                        ),
                              );
                            },
                          ),
                  ),
                ],
              ),
    );
  }

  Widget _buildCommandInput() {
    return Container(
          padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F3C),
        border: Border(
          top: BorderSide(
            color: Color(0xFF30363D),
            width: 1,
          ),
        ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commandController,
              style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                hintText: 'Type command here...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: const Color(0xFF0D1117),
                    border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6C8EEF)),
                ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                  vertical: 14,
                    ),
                  ),
                  onSubmitted: (_) => _sendCommand(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _sendCommand,
                style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C8EEF),
              foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
              'Send',
                  style: TextStyle(
                fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  String _formatRam(double? bytes) {
    if (bytes == null) return 'N/A';
    final gb = bytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB';
  }
}
