import 'package:flutter/material.dart';
import '../models/server.dart';
import '../widgets/server_item.dart';
import '../services/api_service.dart';

class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  List<Server> _servers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final servers = await ApiService.getServers();
      setState(() {
        _servers = servers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateToControl(Server server) {
    Navigator.pushNamed(
      context,
      '/server-control',
      arguments: server,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách Server'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadServers,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadServers,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                : _servers.isEmpty
                    ? const Center(
                        child: Text('Chưa có server nào'),
                      )
                    : ListView.builder(
                        itemCount: _servers.length,
                        itemBuilder: (context, index) {
                          return ServerItem(
                            server: _servers[index],
                            onTap: () => _navigateToControl(_servers[index]),
                          );
                        },
                      ),
      ),
    );
  }
}

