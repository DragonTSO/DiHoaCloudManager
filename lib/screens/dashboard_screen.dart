import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/panel.dart';
import '../models/server.dart';
import '../services/api_service.dart';
import '../utils/storage.dart';
import 'add_panel_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Panel> _panels = [];
  Map<String, List<Server>> _serversByPanel = {};
  Map<String, String> _panelErrors = {}; // Lưu lỗi cho từng panel
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPanels();
  }

  Future<void> _loadPanels() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _panelErrors.clear();
    });

    try {
      final panels = await Storage.getPanels();
      debugPrint('[Dashboard] Found ${panels.length} panels');
      
      setState(() {
        _panels = panels;
      });

      // Load servers for each panel
      for (final panel in panels) {
        debugPrint('[Dashboard] Panel: ${panel.name}, URL: ${panel.url}');
        await _loadServersForPanel(panel);
      }
    } catch (e) {
      debugPrint('[Dashboard] Error loading panels: $e');
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadServersForPanel(Panel panel) async {
    try {
      // Set current panel for API calls
      await Storage.setCurrentPanel(panel.id);
      debugPrint('[Dashboard] Loading servers for panel: ${panel.name} (${panel.url})');
      final servers = await ApiService.getServers();
      debugPrint('[Dashboard] Loaded ${servers.length} servers for ${panel.name}');
      setState(() {
        _serversByPanel[panel.id] = servers;
        _panelErrors.remove(panel.id);
      });
    } catch (e) {
      debugPrint('[Dashboard] Error loading servers for ${panel.name}: $e');
      setState(() {
        _serversByPanel[panel.id] = [];
        _panelErrors[panel.id] = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _showAddPanelSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPanelSheet(
        onPanelAdded: (panel) async {
          await Storage.addPanel(panel);
          _loadPanels();
        },
      ),
    );
  }

  int get _onlineServers {
    int count = 0;
    for (final servers in _serversByPanel.values) {
      count += servers.where((s) => s.isRunning).length;
    }
    return count;
  }

  int get _offlineServers {
    int count = 0;
    for (final servers in _serversByPanel.values) {
      count += servers.where((s) => !s.isRunning).length;
    }
    return count;
  }

  double get _avgCpu {
    double total = 0;
    int count = 0;
    for (final servers in _serversByPanel.values) {
      for (final server in servers) {
        if (server.cpu != null && server.isRunning) {
          total += server.cpu!;
          count++;
        }
      }
    }
    return count > 0 ? total / count : 0;
  }

  double get _avgRam {
    double total = 0;
    int count = 0;
    for (final servers in _serversByPanel.values) {
      for (final server in servers) {
        if (server.ram != null && server.isRunning) {
          // Convert bytes to percentage (assuming 8GB max)
          total += (server.ram! / (8 * 1024 * 1024 * 1024)) * 100;
          count++;
        }
      }
    }
    return count > 0 ? total / count : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStats(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6C8EEF),
                      ),
                    )
                  : _panels.isEmpty
                      ? _buildEmptyState()
                      : _buildServerList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPanelSheet,
        backgroundColor: const Color(0xFF6C8EEF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'My Panels',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/profile');
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F3C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'JD',
                  style: TextStyle(
                    color: Color(0xFF6C8EEF),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatItem(
            value: _onlineServers.toString(),
            label: 'Online',
            color: Colors.green,
          ),
          const SizedBox(width: 24),
          _buildStatItem(
            value: _offlineServers.toString(),
            label: 'Offline',
            color: Colors.red,
          ),
          const SizedBox(width: 24),
          _buildStatItem(
            value: '${_avgCpu.toStringAsFixed(0)}%',
            label: 'Avg CPU',
            color: Colors.orange,
          ),
          const SizedBox(width: 24),
          _buildStatItem(
            value: '${_avgRam.toStringAsFixed(0)}%',
            label: 'Avg RAM',
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 80,
            color: Colors.grey.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            'No panels added yet',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first panel',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerList() {
    // Tính tổng số servers
    int totalServers = 0;
    for (final servers in _serversByPanel.values) {
      totalServers += servers.length;
    }

    return RefreshIndicator(
      onRefresh: _loadPanels,
      color: const Color(0xFF6C8EEF),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Hiển thị từng panel
          for (final panel in _panels) ...[
            _buildPanelSection(panel),
            const SizedBox(height: 16),
          ],
          
          // Nếu không có server nào
          if (totalServers == 0 && _panelErrors.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 48,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No servers found',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Check your API key permissions',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPanelSection(Panel panel) {
    final servers = _serversByPanel[panel.id] ?? [];
    final error = _panelErrors[panel.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Panel header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F3C).withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.dns,
                size: 16,
                color: error != null ? Colors.red : const Color(0xFF6C8EEF),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  panel.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${servers.length} servers',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              // Delete panel button
              GestureDetector(
                onTap: () => _showDeletePanelDialog(panel),
                child: Icon(
                  Icons.more_vert,
                  size: 18,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // Error message if any
        if (error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
                GestureDetector(
                  onTap: () => _loadServersForPanel(panel),
                  child: const Icon(Icons.refresh, color: Colors.red, size: 18),
                ),
              ],
            ),
          ),
        
        // Server cards
        ...servers.map((server) => _buildServerCard(server, panel)),
        
        // Empty state for this panel
        if (servers.isEmpty && error == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F3C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Text(
                  'No servers in this panel',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showDeletePanelDialog(Panel panel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Panel', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "${panel.name}" from the list?',
          style: TextStyle(color: Colors.grey.shade400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Storage.removePanel(panel.id);
              _loadPanels();
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildServerCard(Server server, Panel panel) {
    return GestureDetector(
      onTap: () async {
        await Storage.setCurrentPanel(panel.id);
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/server-control',
            arguments: server,
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: server.isRunning
                ? Colors.green.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: server.isRunning ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        server.isRunning ? 'Running' : 'Offline',
                        style: TextStyle(
                          color: server.isRunning
                              ? Colors.green.shade300
                              : Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!server.isRunning)
                  ElevatedButton(
                    onPressed: () => _startServer(server, panel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Start'),
                  ),
              ],
            ),
            if (server.isRunning) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildResourceItem(
                    'CPU',
                    '${server.cpu?.toStringAsFixed(0) ?? '0'}%',
                    _getCpuColor(server.cpu ?? 0),
                  ),
                  const SizedBox(width: 24),
                  _buildResourceItem(
                    'RAM',
                    _formatRam(server.ram),
                    Colors.blue,
                  ),
                  const SizedBox(width: 24),
                  _buildResourceItem(
                    'DISK',
                    'N/A',
                    Colors.purple,
                  ),
                ],
              ),
            ],
          ],
        ),
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
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getCpuColor(double cpu) {
    if (cpu < 50) return Colors.green;
    if (cpu < 80) return Colors.orange;
    return Colors.red;
  }

  String _formatRam(double? bytes) {
    if (bytes == null) return 'N/A';
    final gb = bytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB';
  }

  Future<void> _startServer(Server server, Panel panel) async {
    await Storage.setCurrentPanel(panel.id);
    try {
      await ApiService.sendPowerSignal(server.id, 'start');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting server...'),
          backgroundColor: Colors.green,
        ),
      );
      _loadPanels();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

