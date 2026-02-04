import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';

/// SecureStorageService handles all secure storage operations
/// Uses flutter_secure_storage to store tokens and sensitive data
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accountName: 'clio_secure_storage',
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Store access token
  static Future<void> setAccessToken(String token) async {
    await _storage.write(key: KEY_ACCESS_TOKEN, value: token);
  }

  /// Get access token
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: KEY_ACCESS_TOKEN);
  }

  /// Store refresh token
  static Future<void> setRefreshToken(String token) async {
    await _storage.write(key: KEY_REFRESH_TOKEN, value: token);
  }

  /// Get refresh token
  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: KEY_REFRESH_TOKEN);
  }

  /// Store user ID
  static Future<void> setUserId(String userId) async {
    await _storage.write(key: KEY_USER_ID, value: userId);
  }

  /// Get user ID
  static Future<String?> getUserId() async {
    return await _storage.read(key: KEY_USER_ID);
  }

  /// Store user phone
  static Future<void> setUserPhone(String phone) async {
    await _storage.write(key: KEY_USER_PHONE, value: phone);
  }

  /// Get user phone
  static Future<String?> getUserPhone() async {
    return await _storage.read(key: KEY_USER_PHONE);
  }

  /// Store user email
  static Future<void> setUserEmail(String email) async {
    await _storage.write(key: KEY_USER_EMAIL, value: email);
  }

  /// Get user email
  static Future<String?> getUserEmail() async {
    return await _storage.read(key: KEY_USER_EMAIL);
  }

  /// Store biometric preference
  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: KEY_BIOMETRIC_ENABLED, value: enabled.toString());
  }

  /// Get biometric preference
  static Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: KEY_BIOMETRIC_ENABLED);
    return value == 'true';
  }

  /// Store first launch flag
  static Future<void> setFirstLaunch(bool isFirst) async {
    await _storage.write(key: KEY_FIRST_LAUNCH, value: isFirst.toString());
  }

  /// Check if first launch
  static Future<bool> isFirstLaunch() async {
    final value = await _storage.read(key: KEY_FIRST_LAUNCH);
    return value == null || value == 'true';
  }

  /// Clear all stored data (logout)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Delete specific key
  static Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
