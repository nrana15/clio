import 'dart:io';

import 'package:jailbreak_root_detection/jailbreak_root_detection.dart';

/// Security check result
class SecurityCheckResult {
  final bool isSecure;
  final List<SecurityThreat> threats;
  final String? message;

  const SecurityCheckResult({
    required this.isSecure,
    required this.threats,
    this.message,
  });
}

/// Types of security threats
enum SecurityThreat {
  jailbreak,      // iOS jailbreak
  root,           // Android root
  emulator,       // Running on emulator
  debugged,       // App is being debugged
  mockLocation,   // Mock location is enabled
  tampered,       // App may be tampered with
}

/// Service for detecting compromised devices
class SecurityCheckService {
  static final JailbreakRootDetection _jailbreakDetector = JailbreakRootDetection();

  /// Check if device is jailbroken (iOS) or rooted (Android)
  static Future<bool> isCompromised() async {
    try {
      return await _jailbreakDetector.isJailBroken;
    } catch (e) {
      print('Security check error: $e');
      return false;
    }
  }

  /// Check if running on emulator
  static Future<bool> isEmulator() async {
    try {
      return await _jailbreakDetector.isRealDevice == false;
    } catch (e) {
      print('Emulator check error: $e');
      return false;
    }
  }

  /// Check if app is being debugged
  static Future<bool> isDebugged() async {
    try {
      return await _jailbreakDetector.isDebuggerAttached;
    } catch (e) {
      print('Debug check error: $e');
      return false;
    }
  }

  /// Check if mock location is enabled
  static Future<bool> hasMockLocation() async {
    try {
      return await _jailbreakDetector.isMockLocationEnabled;
    } catch (e) {
      print('Mock location check error: $e');
      return false;
    }
  }

  /// Check if app is installed from official store
  static Future<bool> isInstalledFromStore() async {
    try {
      return await _jailbreakDetector.isOnExternalStorage == false;
    } catch (e) {
      print('Store check error: $e');
      return true; // Assume valid if check fails
    }
  }

  /// Perform comprehensive security check
  static Future<SecurityCheckResult> performSecurityCheck() async {
    final List<SecurityThreat> threats = [];
    final List<String> messages = [];

    // Check jailbreak/root
    if (await isCompromised()) {
      threats.add(Platform.isIOS ? SecurityThreat.jailbreak : SecurityThreat.root);
      messages.add(Platform.isIOS 
        ? 'This device appears to be jailbroken.' 
        : 'This device appears to be rooted.'
      );
    }

    // Check emulator
    if (await isEmulator()) {
      threats.add(SecurityThreat.emulator);
      messages.add('This app is running on an emulator.');
    }

    // Check debugging
    if (await isDebugged()) {
      threats.add(SecurityThreat.debugged);
      messages.add('This app is being debugged.');
    }

    // Check mock location
    if (await hasMockLocation()) {
      threats.add(SecurityThreat.mockLocation);
      messages.add('Mock location is enabled.');
    }

    return SecurityCheckResult(
      isSecure: threats.isEmpty,
      threats: threats,
      message: messages.isNotEmpty ? messages.join(' ') : null,
    );
  }

  /// Get user-friendly threat description
  static String getThreatDescription(SecurityThreat threat) {
    switch (threat) {
      case SecurityThreat.jailbreak:
        return 'Device is jailbroken (iOS)';
      case SecurityThreat.root:
        return 'Device is rooted (Android)';
      case SecurityThreat.emulator:
        return 'Running on emulator';
      case SecurityThreat.debugged:
        return 'App is being debugged';
      case SecurityThreat.mockLocation:
        return 'Mock location enabled';
      case SecurityThreat.tampered:
        return 'App may be tampered with';
    }
  }

  /// Check if security checks should block app usage
  static bool shouldBlockUsage(SecurityCheckResult result, {
    bool blockOnJailbreak = true,
    bool blockOnRoot = true,
    bool blockOnEmulator = false,  // Allow in development
    bool blockOnDebug = false,      // Allow in development
  }) {
    for (final threat in result.threats) {
      switch (threat) {
        case SecurityThreat.jailbreak:
          if (blockOnJailbreak) return true;
          break;
        case SecurityThreat.root:
          if (blockOnRoot) return true;
          break;
        case SecurityThreat.emulator:
          if (blockOnEmulator) return true;
          break;
        case SecurityThreat.debugged:
          if (blockOnDebug) return true;
          break;
        default:
          break;
      }
    }
    return false;
  }
}
