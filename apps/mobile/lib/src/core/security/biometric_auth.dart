import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_ios/local_auth_ios.dart';

import '../services/secure_storage_service.dart';

/// Biometric authentication types
enum BiometricType {
  none,
  fingerprint,
  face,
  iris,
  unknown,
}

/// Result of biometric authentication
class BiometricAuthResult {
  final bool success;
  final String? error;
  final BiometricType typeUsed;

  const BiometricAuthResult({
    required this.success,
    this.error,
    this.typeUsed = BiometricType.none,
  });
}

/// Service for handling biometric authentication
class BiometricAuthService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if device supports biometric authentication
  static Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException catch (e) {
      print('Biometric check error: ${e.message}');
      return false;
    }
  }

  /// Check if biometrics are available on this device
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException catch (e) {
      print('Biometric check error: ${e.message}');
      return false;
    }
  }

  /// Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      return availableBiometrics.map((biometric) {
        switch (biometric) {
          case AuthenticationType.fingerprint:
          case AuthenticationType.weak:
            return BiometricType.fingerprint;
          case AuthenticationType.face:
            return BiometricType.face;
          case AuthenticationType.iris:
            return BiometricType.iris;
          default:
            return BiometricType.unknown;
        }
      }).toList();
    } on PlatformException catch (e) {
      print('Biometric check error: ${e.message}');
      return [];
    }
  }

  /// Check if fingerprint authentication is available
  static Future<bool> hasFingerprint() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.fingerprint);
  }

  /// Check if face authentication is available
  static Future<bool> hasFaceAuth() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.face);
  }

  /// Get the primary biometric type available
  static Future<BiometricType> getPrimaryBiometricType() async {
    final biometrics = await getAvailableBiometrics();
    
    if (biometrics.isEmpty) return BiometricType.none;
    
    // Prefer face on iOS, fingerprint on Android
    if (Platform.isIOS && biometrics.contains(BiometricType.face)) {
      return BiometricType.face;
    }
    
    if (biometrics.contains(BiometricType.fingerprint)) {
      return BiometricType.fingerprint;
    }
    
    return biometrics.first;
  }

  /// Authenticate using biometrics
  static Future<BiometricAuthResult> authenticate({
    String localizedReason = 'Please authenticate to access CLIO',
    bool useErrorDialogs = true,
    bool stickyAuth = false,
    bool sensitiveTransaction = true,
  }) async {
    try {
      final isAvailable = await canCheckBiometrics();
      if (!isAvailable) {
        return const BiometricAuthResult(
          success: false,
          error: 'Biometric authentication not available',
        );
      }

      final primaryType = await getPrimaryBiometricType();
      
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'CLIO Authentication',
            cancelButton: 'Cancel',
            biometricHint: 'Verify your identity',
            biometricNotRecognized: 'Not recognized, try again',
            biometricRequiredTitle: 'Biometric authentication required',
            biometricSuccess: 'Authentication successful',
            deviceCredentialsRequiredTitle: 'Device credentials required',
            deviceCredentialsSetupDescription: 'Please set up device credentials',
            goToSettingsButton: 'Go to Settings',
            goToSettingsDescription: 'Please set up biometric authentication in Settings',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancel',
            goToSettingsButton: 'Go to Settings',
            goToSettingsDescription: 'Please set up biometric authentication in Settings',
            lockOut: 'Please re-enable biometric authentication',
          ),
        ],
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          sensitiveTransaction: sensitiveTransaction,
          biometricOnly: false, // Allow fallback to PIN/pattern
        ),
      );

      return BiometricAuthResult(
        success: didAuthenticate,
        typeUsed: didAuthenticate ? primaryType : BiometricType.none,
      );
    } on PlatformException catch (e) {
      return BiometricAuthResult(
        success: false,
        error: e.message ?? 'Authentication failed',
      );
    }
  }

  /// Stop authentication
  static Future<bool> stopAuthentication() async {
    try {
      return await _localAuth.stopAuthentication();
    } on PlatformException catch (e) {
      print('Stop authentication error: ${e.message}');
      return false;
    }
  }

  /// Check if biometric lock is enabled in settings
  static Future<bool> isBiometricLockEnabled() async {
    return await SecureStorageService.isBiometricEnabled();
  }

  /// Enable biometric lock
  static Future<void> enableBiometricLock() async {
    await SecureStorageService.setBiometricEnabled(true);
  }

  /// Disable biometric lock
  static Future<void> disableBiometricLock() async {
    await SecureStorageService.setBiometricEnabled(false);
  }

  /// Authenticate with biometrics if enabled
  static Future<BiometricAuthResult> authenticateIfEnabled() async {
    final isEnabled = await isBiometricLockEnabled();
    
    if (!isEnabled) {
      return const BiometricAuthResult(
        success: true,
        typeUsed: BiometricType.none,
      );
    }

    return await authenticate();
  }

  /// Get localized biometric name
  static Future<String> getBiometricName() async {
    final type = await getPrimaryBiometricType();
    
    switch (type) {
      case BiometricType.fingerprint:
        return Platform.isIOS ? 'Touch ID' : 'Fingerprint';
      case BiometricType.face:
        return Platform.isIOS ? 'Face ID' : 'Face Recognition';
      case BiometricType.iris:
        return 'Iris Recognition';
      default:
        return 'Biometric';
    }
  }
}
