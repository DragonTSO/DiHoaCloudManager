import 'dart:convert';

class Panel {
  final String id;
  final String name;
  final String url;
  final String apiKey;

  Panel({
    required this.id,
    required this.name,
    required this.url,
    required this.apiKey,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'apiKey': apiKey,
  };

  factory Panel.fromJson(Map<String, dynamic> json) => Panel(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    url: json['url'] ?? '',
    apiKey: json['apiKey'] ?? '',
  );

  static String encodeList(List<Panel> panels) {
    return jsonEncode(panels.map((p) => p.toJson()).toList());
  }

  static List<Panel> decodeList(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => Panel.fromJson(json)).toList();
  }
}

