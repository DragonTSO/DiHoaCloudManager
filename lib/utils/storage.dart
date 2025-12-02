import 'package:shared_preferences/shared_preferences.dart';
import '../models/panel.dart';

class Storage {
  static const String _keyPanels = 'panels';
  static const String _keyCurrentPanelId = 'current_panel_id';
  
  // Legacy keys (for migration)
  static const String _keyPanelUrl = 'panel_url';
  static const String _keyApiKey = 'api_key';

  /// Lưu danh sách panels
  static Future<void> savePanels(List<Panel> panels) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPanels, Panel.encodeList(panels));
  }

  /// Lấy danh sách panels
  static Future<List<Panel>> getPanels() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyPanels);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      return Panel.decodeList(jsonString);
    } catch (e) {
      return [];
    }
  }

  /// Thêm panel mới
  static Future<void> addPanel(Panel panel) async {
    final panels = await getPanels();
    panels.add(panel);
    await savePanels(panels);
  }

  /// Xóa panel
  static Future<void> removePanel(String panelId) async {
    final panels = await getPanels();
    panels.removeWhere((p) => p.id == panelId);
    await savePanels(panels);
  }

  /// Cập nhật panel
  static Future<void> updatePanel(Panel panel) async {
    final panels = await getPanels();
    final index = panels.indexWhere((p) => p.id == panel.id);
    if (index != -1) {
      panels[index] = panel;
      await savePanels(panels);
    }
  }

  /// Set panel hiện tại
  static Future<void> setCurrentPanel(String panelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentPanelId, panelId);
  }

  /// Lấy panel hiện tại
  static Future<Panel?> getCurrentPanel() async {
    final prefs = await SharedPreferences.getInstance();
    final panelId = prefs.getString(_keyCurrentPanelId);
    if (panelId == null) return null;
    
    final panels = await getPanels();
    try {
      return panels.firstWhere((p) => p.id == panelId);
    } catch (e) {
      return panels.isNotEmpty ? panels.first : null;
    }
  }

  // Legacy methods for compatibility
  static Future<void> saveCredentials(String panelUrl, String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPanelUrl, panelUrl);
    await prefs.setString(_keyApiKey, apiKey);
  }

  static Future<String?> getPanelUrl() async {
    // Try to get from current panel first
    final currentPanel = await getCurrentPanel();
    if (currentPanel != null) {
      return currentPanel.url;
    }
    // Fallback to legacy storage
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPanelUrl);
  }

  static Future<String?> getApiKey() async {
    // Try to get from current panel first
    final currentPanel = await getCurrentPanel();
    if (currentPanel != null) {
      return currentPanel.apiKey;
    }
    // Fallback to legacy storage
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiKey);
  }

  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPanelUrl);
    await prefs.remove(_keyApiKey);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
