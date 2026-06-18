import 'package:flutter/material.dart';
import 'package:marispeaks/screens/ptt/websocket_ptt_controller.dart';

/// Debug widget to show PTT connection status
/// Add this to your app to quickly see if PTT is working
///
/// Usage:
/// FloatingActionButton(
///   onPressed: () => showDialog(
///     context: context,
///     builder: (context) => PTTStatusDialog(),
///   ),
///   child: Icon(Icons.mic),
/// )
class PTTStatusDialog extends StatefulWidget {
  const PTTStatusDialog({Key? key}) : super(key: key);

  @override
  State<PTTStatusDialog> createState() => _PTTStatusDialogState();
}

class _PTTStatusDialogState extends State<PTTStatusDialog> {
  final pttController = WebSocketPTTController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.mic, color: Colors.blue),
          SizedBox(width: 8),
          Text('PTT Status'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusRow(
              'WebSocket Connection',
              pttController.isConnected,
              pttController.isConnected ? 'Connected' : 'Disconnected',
            ),
            const Divider(),
            _buildStatusRow(
              'Recording Status',
              pttController.isRecording,
              pttController.isRecording ? 'Recording' : 'Idle',
            ),
            const Divider(),
            _buildInfoRow('User ID', pttController.senderId ?? 'Not set'),
            _buildInfoRow('Group ID', pttController.groupId ?? 'Not set'),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Connection Details',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Server', 'wss://ptt.visionvivante.in'),
            _buildInfoRow('Codec', 'AAC-LC'),
            _buildInfoRow('Sample Rate', '44.1 kHz'),
            _buildInfoRow('Bit Rate', '128 kbps'),
            _buildInfoRow('Channels', 'Mono'),
            _buildInfoRow('Chunk Interval', '1.5 seconds'),
            const SizedBox(height: 16),
            if (!pttController.isConnected)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Not Connected',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'PTT is not connected to the server. '
                      'This could mean:\n'
                      '• User not logged in\n'
                      '• No internet connection\n'
                      '• Server is down\n'
                      '• WebSocket blocked by firewall',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            if (pttController.isConnected)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PTT is ready! Press and hold the PTT button to talk.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (!pttController.isConnected && pttController.senderId != null)
          TextButton.icon(
            onPressed: () {
              pttController.connect(pttController.senderId!);
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reconnect'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, bool isActive, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: TextStyle(
                  color: isActive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick PTT test button - shows status in a snackbar
class PTTQuickTestButton extends StatelessWidget {
  const PTTQuickTestButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      mini: true,
      onPressed: () {
        final pttController = WebSocketPTTController();

        String message;
        Color backgroundColor;
        IconData icon;

        if (pttController.isConnected) {
          message = '✅ PTT Connected';
          backgroundColor = Colors.green;
          icon = Icons.check_circle;
        } else {
          message = '❌ PTT Disconnected';
          backgroundColor = Colors.red;
          icon = Icons.error;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const PTTStatusDialog(),
                );
              },
            ),
          ),
        );
      },
      tooltip: 'Check PTT Status',
      child: const Icon(Icons.mic),
    );
  }
}
