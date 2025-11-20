import 'package:flutter/material.dart';
import '../utils/storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _panelUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final panelUrl = await Storage.getPanelUrl();
    final apiKey = await Storage.getApiKey();
    if (panelUrl != null) {
      _panelUrlController.text = panelUrl;
    }
    if (apiKey != null) {
      _apiKeyController.text = apiKey;
    }
  }

  @override
  void dispose() {
    _panelUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Lưu thông tin đăng nhập
        await Storage.saveCredentials(
          _panelUrlController.text.trim(),
          _apiKeyController.text.trim(),
        );

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/server-list');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo hoặc tiêu đề
                  const Icon(
                    Icons.cloud,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'DiHoaManager',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Panel URL field
                  TextFormField(
                    controller: _panelUrlController,
                    decoration: InputDecoration(
                      labelText: 'Panel URL',
                      hintText: 'https://panel.example.com',
                      prefixIcon: const Icon(Icons.link),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập Panel URL';
                      }
                      if (!value.startsWith('http://') && 
                          !value.startsWith('https://')) {
                        return 'URL phải bắt đầu bằng http:// hoặc https://';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // API Key field
                  TextFormField(
                    controller: _apiKeyController,
                    decoration: InputDecoration(
                      labelText: 'Client API Key',
                      hintText: 'ptlc_xxxxxxxxxxxxx',
                      prefixIcon: const Icon(Icons.key),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập API Key';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  // Login button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.blue,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Đăng nhập',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

