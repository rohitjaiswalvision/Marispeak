import 'package:flutter/material.dart';
import 'package:marispeaks/config/environment.dart';

/// Visual indicator showing which environment the app is running in
/// This helps prevent accidentally testing on production
///
/// Usage:
/// In your main screen or scaffold, add:
/// EnvironmentBanner(child: YourScreen())
class EnvironmentBanner extends StatelessWidget {
  final Widget child;

  const EnvironmentBanner({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Only show banner in non-production environments
    if (Environment.current.isProduction) {
      return child;
    }

    return Stack(
      children: [
        child,
        // Banner at the top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildBanner(),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    final env = Environment.current;
    final Color bannerColor;
    final IconData icon;

    switch (env.type) {
      case EnvironmentType.development:
        bannerColor = Colors.orange;
        icon = Icons.build;
        break;
      case EnvironmentType.staging:
        bannerColor = Colors.blue;
        icon = Icons.science;
        break;
      case EnvironmentType.production:
        bannerColor = Colors.green;
        icon = Icons.check_circle;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bannerColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              '${env.name.toUpperCase()} MODE',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '• PTT: ${_getShortServerUrl(env.pttServerUrl)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getShortServerUrl(String url) {
    if (url.contains('localhost')) return 'localhost';
    if (url.contains('staging')) return 'staging';
    return 'production';
  }
}

/// Corner badge showing environment info
/// Useful for floating indicator that doesn't take screen space
///
/// Usage:
/// Stack(
///   children: [
///     YourScreen(),
///     EnvironmentCornerBadge(),
///   ],
/// )
class EnvironmentCornerBadge extends StatelessWidget {
  final Alignment alignment;
  final bool showInProduction;

  const EnvironmentCornerBadge({
    Key? key,
    this.alignment = Alignment.bottomRight,
    this.showInProduction = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (Environment.current.isProduction && !showInProduction) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: alignment == Alignment.bottomRight ||
              alignment == Alignment.bottomLeft
          ? 80
          : null,
      top: alignment == Alignment.topRight || alignment == Alignment.topLeft
          ? 40
          : null,
      right:
          alignment == Alignment.bottomRight || alignment == Alignment.topRight
              ? 16
              : null,
      left: alignment == Alignment.bottomLeft || alignment == Alignment.topLeft
          ? 16
          : null,
      child: GestureDetector(
        onTap: () {
          _showEnvironmentDialog(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _getEnvironmentColor(),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getEnvironmentIcon(),
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                Environment.current.name.substring(0, 3).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getEnvironmentColor() {
    switch (Environment.current.type) {
      case EnvironmentType.development:
        return Colors.orange;
      case EnvironmentType.staging:
        return Colors.blue;
      case EnvironmentType.production:
        return Colors.green;
    }
  }

  IconData _getEnvironmentIcon() {
    switch (Environment.current.type) {
      case EnvironmentType.development:
        return Icons.build;
      case EnvironmentType.staging:
        return Icons.science;
      case EnvironmentType.production:
        return Icons.check_circle;
    }
  }

  void _showEnvironmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getEnvironmentIcon(), color: _getEnvironmentColor()),
            const SizedBox(width: 8),
            Text('${Environment.current.name} Environment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('PTT Server', Environment.current.pttServerUrl),
            _buildInfoRow('API Server', Environment.current.apiBaseUrl),
            _buildInfoRow('Logging',
                Environment.current.enableLogging ? 'Enabled' : 'Disabled'),
            _buildInfoRow(
                'Debug Features',
                Environment.current.enableDebugFeatures
                    ? 'Enabled'
                    : 'Disabled'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 12),
          ),
          const Divider(),
        ],
      ),
    );
  }
}

/// Simple environment label for testing
/// Shows current environment name at the top of the screen
class EnvironmentLabel extends StatelessWidget {
  const EnvironmentLabel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (Environment.current.isProduction) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      color: Environment.current.isDevelopment ? Colors.orange : Colors.blue,
      child: Text(
        '${Environment.current.name.toUpperCase()} ENVIRONMENT',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
