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

class _ServerControlScreenState extends State<ServerControlScreen> with TickerProviderStateMixin {
  final _commandController = TextEditingController();
  final _consoleScrollController = ScrollController();
  final List<String> _consoleLogs = [];
  late TabController _tabController;
  
  // Animation controllers cho buttons
  late AnimationController _startScaleController;
  late AnimationController _stopScaleController;
  late AnimationController _restartScaleController;
  late AnimationController _startPulseController;
  late AnimationController _stopPulseController;
  late AnimationController _restartRotateController;
  
  late Animation<double> _startScaleAnimation;
  late Animation<double> _stopScaleAnimation;
  late Animation<double> _restartScaleAnimation;
  late Animation<double> _startPulseAnimation;
  late Animation<double> _stopPulseAnimation;
  late Animation<double> _restartRotateAnimation;
  
  Server? _currentServer;
  ServerStats? _currentStats; // Stats từ WebSocket
  bool _isLoading = false;
  bool _isPowerActionLoading = false;
  bool _isConnecting = false;
  
  WebSocketService? _webSocketService;
  StreamSubscription<String>? _logSubscription;
  StreamSubscription<ServerStats>? _statsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.animation!.isAnimating) {
        setState(() {}); // Chỉ rebuild khi đang chuyển tab
      }
    });
    _currentServer = widget.server;
    
    // Initialize animation controllers
    _startScaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _stopScaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _restartScaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _startPulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _stopPulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _restartRotateController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    // Initialize animations
    _startScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _startScaleController, curve: Curves.easeInOut),
    );
    _stopScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _stopScaleController, curve: Curves.easeInOut),
    );
    _restartScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _restartScaleController, curve: Curves.easeInOut),
    );
    _startPulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _startPulseController, curve: Curves.easeInOut),
    );
    _stopPulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _stopPulseController, curve: Curves.easeInOut),
    );
    _restartRotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _restartRotateController, curve: Curves.linear),
    );
    
    _refreshServerStatus();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _startScaleController.dispose();
    _stopScaleController.dispose();
    _restartScaleController.dispose();
    _startPulseController.dispose();
    _stopPulseController.dispose();
    _restartRotateController.dispose();
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

        // Lắng nghe stats stream để cập nhật resource stats
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

  /// Widget để hiển thị một stat card
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    String? value2,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (value2 != null) ...[
            const SizedBox(height: 6),
            Text(
              value2,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
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
        title: Text(
          widget.server.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue[600]!,
                Colors.blue[800]!,
              ],
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Sliding indicator background
                  AnimatedBuilder(
                    animation: _tabController.animation!,
                    builder: (context, child) {
                      final animationValue = _tabController.animation!.value;
                      final containerWidth = MediaQuery.of(context).size.width - 64;
                      final tabWidth = containerWidth / 2;
                      final leftPosition = animationValue * tabWidth + 4;
                      
                      return Positioned(
                        left: leftPosition,
                        top: 4,
                        bottom: 4,
                        child: RepaintBoundary(
                          child: Container(
                            width: tabWidth - 8,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Tab items
                  TabBar(
                    controller: _tabController,
                    indicator: const BoxDecoration(),
                    labelColor: Colors.transparent,
                    unselectedLabelColor: Colors.transparent,
                    dividerColor: Colors.transparent,
                    tabs: [
                      _buildTabItem(
                        icon: Icons.dashboard,
                        label: 'Thông số',
                        isSelected: _tabController.index == 0,
                      ),
                      _buildTabItem(
                        icon: Icons.terminal,
                        label: 'Console',
                        isSelected: _tabController.index == 1,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(), // Thêm physics mượt hơn
        children: [
          // Tab 1: Thông số + Power buttons
          _buildStatsTab(),
          // Tab 2: Console + Power buttons + Command input
          _buildConsoleTab(),
        ],
      ),
    );
  }
  
  /// Build custom tab item với icon và background trắng khi active - tối ưu performance
  Widget _buildTabItem({
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return Tab(
      child: RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Icon(
                  icon,
                  size: 19,
                  color: isSelected
                      ? const Color(0xFF1E1E1E)
                      : Colors.grey[400],
                ),
              ),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF1E1E1E)
                      : Colors.grey[400],
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tab 1: Thông số resource + Power buttons
  Widget _buildStatsTab() {
    return Column(
      children: [
        // Server status header
        _buildStatusHeader(),
        
        // Resource stats widget
        if (_currentStats != null)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.blue.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.analytics,
                            color: Colors.blue[700],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Resource Usage',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // CPU và RAM
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.speed,
                            label: 'CPU',
                            value: '${_currentStats!.cpuPercent.toStringAsFixed(1)}%',
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.memory,
                            label: 'RAM',
                            value: '${_currentStats!.ramPercent.toStringAsFixed(1)}%',
                            value2: '${_currentStats!.ramUsedFormatted} / ${_currentStats!.ramLimitFormatted}',
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Disk và Network
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.storage,
                            label: 'Disk',
                            value: _currentStats!.diskUsedFormatted,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.network_check,
                            label: 'Network',
                            value: '↑ ${_currentStats!.txBytesFormatted}',
                            value2: '↓ ${_currentStats!.rxBytesFormatted}',
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    if (_currentStats!.uptime != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.shade50,
                              Colors.purple.shade100,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.purple.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.timer,
                                size: 20,
                                color: Colors.purple,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Uptime: ${_currentStats!.uptimeFormatted}',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.purple[900],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Đang chờ dữ liệu...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Kết nối WebSocket để xem thông số real-time',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Power control buttons
        _buildPowerButtons(),
      ],
    );
  }

  /// Tab 2: Console + Power buttons + Command input
  Widget _buildConsoleTab() {
    return Column(
      children: [
        // Server status header
        _buildStatusHeader(),

        // Power control buttons
        _buildPowerButtons(),

        // Console area
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade700,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  // Console header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade700,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: (_webSocketService?.isConnected ?? false)
                                ? Colors.green
                                : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Console',
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.code,
                          size: 18,
                          color: Colors.grey.shade400,
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
                                        'Đang kết nối Console...',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    'Console sẽ hiển thị ở đây...',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
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
                              
                              // Xác định màu mặc định dựa trên loại log (nếu không có ANSI codes)
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
                              
                              // Parse ANSI escape codes và render với RichText
                              final textSpan = AnsiParser.parseAnsi(log, defaultColor: defaultColor);
                              
                              return RichText(
                                text: textSpan,
                              );
                            },
                          ),
                  ),
                ],
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
    );
  }

  /// Widget chung cho status header
  Widget _buildStatusHeader() {
    final isRunning = _currentServer?.isRunning ?? false;
    final isConnected = _webSocketService?.isConnected ?? false;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isRunning
              ? [
                  Colors.green.shade50,
                  Colors.green.shade100.withOpacity(0.3),
                  Colors.white,
                ]
              : [
                  Colors.grey.shade100,
                  Colors.grey.shade50,
                  Colors.white,
                ],
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status indicator với icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isRunning
                    ? [
                        Colors.green.shade100,
                        Colors.green.shade50,
                      ]
                    : [
                        Colors.grey.shade200,
                        Colors.grey.shade100,
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isRunning
                    ? Colors.green.shade300
                    : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isRunning ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isRunning ? Colors.green : Colors.red)
                            .withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  isRunning ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: isRunning ? Colors.green[700] : Colors.red[700],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // Status info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isRunning ? 'Đang chạy' : 'Đã tắt',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isRunning ? Colors.green[700] : Colors.red[700],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isConnected ? Colors.blue : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isConnected ? 'WebSocket đã kết nối' : 'WebSocket chưa kết nối',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Action buttons
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(8),
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.refresh, size: 20),
                    color: Colors.blue[700],
                    iconSize: 20,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      setState(() => _isLoading = true);
                      await _refreshServerStatus();
                      setState(() => _isLoading = false);
                    },
                    tooltip: 'Làm mới',
                  ),
                ),
                if (!isConnected) ...[
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.replay, size: 20),
                      color: Colors.orange[700],
                      iconSize: 20,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      onPressed: _connectWebSocket,
                      tooltip: 'Kết nối lại',
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  /// Widget chung cho power buttons
  Widget _buildPowerButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          // START button
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildAnimatedPowerButton(
                label: 'START',
                icon: Icons.play_arrow,
                colors: [Colors.green[400]!, Colors.green[600]!],
                shadowColor: Colors.green,
                scaleController: _startScaleController,
                scaleAnimation: _startScaleAnimation,
                iconAnimation: _startPulseAnimation,
                iconAnimationType: 'pulse',
                onPressed: () => _handlePowerAction('start'),
              ),
            ),
          ),
          
          // STOP button
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _buildAnimatedPowerButton(
                label: 'STOP',
                icon: Icons.stop,
                colors: [Colors.red[400]!, Colors.red[600]!],
                shadowColor: Colors.red,
                scaleController: _stopScaleController,
                scaleAnimation: _stopScaleAnimation,
                iconAnimation: _stopPulseAnimation,
                iconAnimationType: 'pulse',
                onPressed: () => _handlePowerAction('stop'),
              ),
            ),
          ),
          
          // RESTART button
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _buildAnimatedPowerButton(
                label: 'RESTART',
                icon: Icons.refresh,
                colors: [Colors.orange[400]!, Colors.orange[600]!],
                shadowColor: Colors.orange,
                scaleController: _restartScaleController,
                scaleAnimation: _restartScaleAnimation,
                iconAnimation: _restartRotateAnimation,
                iconAnimationType: 'rotate',
                onPressed: () => _handlePowerAction('restart'),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Widget button với animation
  Widget _buildAnimatedPowerButton({
    required String label,
    required IconData icon,
    required List<Color> colors,
    required Color shadowColor,
    required AnimationController scaleController,
    required Animation<double> scaleAnimation,
    required Animation<double> iconAnimation,
    required String iconAnimationType, // 'pulse' or 'rotate'
    required VoidCallback onPressed,
  }) {
    return ScaleTransition(
      scale: scaleAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: shadowColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTapDown: (_) => scaleController.forward(),
            onTapUp: (_) {
              scaleController.reverse();
              onPressed();
            },
            onTapCancel: () => scaleController.reverse(),
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withOpacity(0.3),
            highlightColor: Colors.white.withOpacity(0.1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              child: _isPowerActionLoading
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: iconAnimation,
                            builder: (context, child) {
                              if (iconAnimationType == 'rotate') {
                                return Transform.rotate(
                                  angle: iconAnimation.value * 2 * 3.14159,
                                  child: Icon(
                                    icon,
                                    color: Colors.white,
                                    size: 22,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                return Transform.scale(
                                  scale: iconAnimation.value,
                                  child: Icon(
                                    icon,
                                    color: Colors.white,
                                    size: 22,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.0,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

