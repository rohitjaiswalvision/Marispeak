/// Environment configuration for switching between development and production
///
/// Usage:
/// 1. Change Environment.current to switch environments
/// 2. Use Environment.current.pttServerUrl in your code
/// 3. Build flags can be added later for automated switching

enum EnvironmentType {
  development,
  staging,
  production,
}

class Environment {
  final EnvironmentType type;
  final String name;
  final String pttServerUrl;
  final String apiBaseUrl;
  final bool enableLogging;
  final bool enableDebugFeatures;

  const Environment({
    required this.type,
    required this.name,
    required this.pttServerUrl,
    required this.apiBaseUrl,
    required this.enableLogging,
    required this.enableDebugFeatures,
  });

  // 🔧 CHANGE THIS TO SWITCH ENVIRONMENTS
  // ⚠️  IMPORTANT: Set to production before releasing to app stores!
  static Environment current = production; // <-- Change this line

  // ============================================
  // ENVIRONMENT CONFIGURATIONS
  // ============================================

  /// Development Environment
  /// - Uses development PTT server
  /// - Enables all logging
  /// - Enables debug features
  static const Environment development = Environment(
    type: EnvironmentType.development,
    name: 'Development',
    pttServerUrl:
        'ws://192.168.3.192:3010', // Local development server (Mac's IP)
    apiBaseUrl: 'https://dev-api.marispeak.com',
    enableLogging: true,
    enableDebugFeatures: true,
  );

  /// Staging Environment
  /// - Uses staging PTT server
  /// - Enables logging
  /// - Enables some debug features
  static const Environment staging = Environment(
    type: EnvironmentType.staging,
    name: 'Staging',
    pttServerUrl: 'wss://ptt-staging.visionvivante.in', // Staging server
    apiBaseUrl: 'https://staging-api.marispeak.com',
    enableLogging: true,
    enableDebugFeatures: true,
  );

  /// Production Environment
  /// - Uses production PTT server
  /// - Minimal logging
  /// - No debug features
  static const Environment production = Environment(
    type: EnvironmentType.production,
    name: 'Production',
    pttServerUrl: 'wss://ptt.visionvivante.in', // Production server
    apiBaseUrl: 'https://api.marispeak.com',
    enableLogging: false,
    enableDebugFeatures: false,
  );

  // ============================================
  // HELPER METHODS
  // ============================================

  bool get isDevelopment => type == EnvironmentType.development;
  bool get isStaging => type == EnvironmentType.staging;
  bool get isProduction => type == EnvironmentType.production;

  /// Get environment info as a formatted string
  String get info {
    return '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Environment: $name
  PTT Server: $pttServerUrl
  API Server: $apiBaseUrl
  Logging: ${enableLogging ? 'Enabled' : 'Disabled'}
  Debug: ${enableDebugFeatures ? 'Enabled' : 'Disabled'}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';
  }

  /// Check if PTT server URL is valid
  bool get hasValidPttUrl {
    return pttServerUrl.startsWith('ws://') ||
        pttServerUrl.startsWith('wss://');
  }

  /// Get warning message if in non-production mode
  String? get warningMessage {
    if (isProduction) return null;
    return '⚠️ Running in ${name.toUpperCase()} mode - Do not release to production!';
  }
}

/// Print environment info at app startup
void printEnvironmentInfo() {
  print(Environment.current.info);
  final warning = Environment.current.warningMessage;
  if (warning != null) {
    print(warning);
  }
}
