import 'package:shared_preferences/shared_preferences.dart';

class Storage {
  static const String _keyPanelUrl = 'panel_url';
  static const String _keyApiKey = 'api_key';

  static Future<void> saveCredentials(String panelUrl, String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPanelUrl, panelUrl);
    await prefs.setString(_keyApiKey, apiKey);
  }

  static Future<String?> getPanelUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPanelUrl);
  }

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiKey);
  }

  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPanelUrl);
    await prefs.remove(_keyApiKey);
  }
}