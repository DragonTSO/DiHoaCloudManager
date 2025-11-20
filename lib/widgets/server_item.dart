import 'package:flutter/material.dart';
import '../models/server.dart';

class ServerItem extends StatelessWidget {
  final Server server;
  final VoidCallback onTap;

  const ServerItem({
    super.key,
    required this.server,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = server.isRunning;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isRunning
                    ? [
                        Colors.green.shade50,
                        Colors.white,
                      ]
                    : [
                        Colors.grey.shade50,
                        Colors.white,
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isRunning ? Colors.green.shade200 : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Server icon với status indicator
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isRunning
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.dns,
                    color: isRunning ? Colors.green[700] : Colors.grey[600],
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Server name và status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
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
                            isRunning ? 'Đang chạy' : 'Đã tắt',
                            style: TextStyle(
                              fontSize: 14,
                              color: isRunning ? Colors.green[700] : Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Arrow icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}