import 'dart:convert';

/// Model để lưu thông tin resource stats từ WebSocket stats event
class ServerStats {
  final double? cpuAbsolute; // CPU usage (%)
  final int? memoryBytes; // RAM đang dùng (bytes)
  final int? memoryLimitBytes; // RAM limit (bytes)
  final int? diskBytes; // Disk đang dùng (bytes)
  final int? rxBytes; // Network received (bytes)
  final int? txBytes; // Network transmitted (bytes)
  final String? state; // Server state: 'running', 'offline', etc.
  final int? uptime; // Uptime (milliseconds)

  ServerStats({
    this.cpuAbsolute,
    this.memoryBytes,
    this.memoryLimitBytes,
    this.diskBytes,
    this.rxBytes,
    this.txBytes,
    this.state,
    this.uptime,
  });

  /// Parse từ JSON string (args[0] từ stats event)
  factory ServerStats.fromJson(dynamic json) {
    // Nếu là string, parse nó trước
    Map<String, dynamic> data;
    if (json is String) {
      try {
        data = jsonDecode(json) as Map<String, dynamic>;
      } catch (e) {
        return ServerStats();
      }
    } else if (json is Map) {
      data = Map<String, dynamic>.from(json);
    } else {
      return ServerStats();
    }

    return ServerStats(
      cpuAbsolute: data['cpu_absolute']?.toDouble(),
      memoryBytes: data['memory_bytes']?.toInt(),
      memoryLimitBytes: data['memory_limit_bytes']?.toInt(),
      diskBytes: data['disk_bytes']?.toInt(),
      rxBytes: data['network']?['rx_bytes']?.toInt(),
      txBytes: data['network']?['tx_bytes']?.toInt(),
      state: data['state']?.toString(),
      uptime: data['uptime']?.toInt(),
    );
  }

  /// CPU usage percentage
  double get cpuPercent => cpuAbsolute ?? 0.0;

  /// RAM usage percentage (0-100)
  double get ramPercent {
    if (memoryBytes == null || memoryLimitBytes == null || memoryLimitBytes == 0) {
      return 0.0;
    }
    return (memoryBytes! / memoryLimitBytes!) * 100;
  }

  /// RAM đang dùng (formatted: MB, GB, etc.)
  String get ramUsedFormatted {
    if (memoryBytes == null) return 'N/A';
    return _formatBytes(memoryBytes!);
  }

  /// RAM limit (formatted: MB, GB, etc.)
  String get ramLimitFormatted {
    if (memoryLimitBytes == null) return 'N/A';
    return _formatBytes(memoryLimitBytes!);
  }

  /// Disk đang dùng (formatted: MB, GB, etc.)
  String get diskUsedFormatted {
    if (diskBytes == null) return 'N/A';
    return _formatBytes(diskBytes!);
  }

  /// Network received (formatted)
  String get rxBytesFormatted {
    if (rxBytes == null) return 'N/A';
    return _formatBytes(rxBytes!);
  }

  /// Network transmitted (formatted)
  String get txBytesFormatted {
    if (txBytes == null) return 'N/A';
    return _formatBytes(txBytes!);
  }

  /// Uptime formatted (days, hours, minutes)
  String get uptimeFormatted {
    if (uptime == null) return 'N/A';
    final seconds = uptime! ~/ 1000;
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Format bytes to human readable format
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

