class Server {
  final String id;
  final String name;
  final String status; // 'running' hoặc 'offline'
  final double? cpu;
  final double? ram;

  Server({
    required this.id,
    required this.name,
    required this.status,
    this.cpu,
    this.ram,
  });

  bool get isRunning => status == 'running';

  factory Server.fromJson(Map<String, dynamic> json) {
    // Pterodactyl API trả về status trong resources hoặc trong attributes
    String status = 'offline';
    if (json['current_state'] != null) {
      status = json['current_state'] == 'running' ? 'running' : 'offline';
    } else if (json['status'] != null) {
      status = json['status'] == 'running' ? 'running' : 'offline';
    }

    return Server(
      id: json['identifier'] ?? json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown Server',
      status: status,
      cpu: json['resources']?['cpu_absolute']?.toDouble(),
      ram: json['resources']?['memory_bytes']?.toDouble(),
    );
  }
}

