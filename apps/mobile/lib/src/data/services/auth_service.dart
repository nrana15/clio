import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import 'secure_storage_service.dart';

/// Custom exceptions for auth errors
class AuthException implements Exception {
  final String message;
  final int? statusCode;

  AuthException(this.message, {this.statusCode});

  @override
  String toString() => 'AuthException: $message';
}

/// AuthService handles all authentication-related API calls
class AuthService {
  late final Dio _dio;

  AuthService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: API_BASE_URL,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors for logging and token refresh
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token if available
          final token = await SecureStorageService.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 - try to refresh token
          if (error.response?.statusCode == 401) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              // Retry the original request
              final token = await SecureStorageService.getAccessToken();
              error.requestOptions.headers['Authorization'] = 'Bearer $token';
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } else {
              // Token refresh failed, clear storage
              await SecureStorageService.clearAll();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Request OTP for phone number
  Future<void> requestPhoneOtp(String phoneNumber) async {
    try {
      final response = await _dio.post(
        '$API_VERSION/auth/otp/phone',
        data: {'phone_number': phoneNumber},
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AuthException(
          response.data['message'] ?? 'Failed to send OTP',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw AuthException(
        e.response?.data['message'] ?? 'Network error. Please try again.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Request OTP for email
  Future<void> requestEmailOtp(String email) async {
    try {
      final response = await _dio.post(
        '$API_VERSION/auth/otp/email',
        data: {'email': email},
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AuthException(
          response.data['message'] ?? 'Failed to send OTP',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw AuthException(
        e.response?.data['message'] ?? 'Network error. Please try again.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Verify OTP and login
  Future<AuthResponse> verifyOtp({
    String? phoneNumber,
    String? email,
    required String otp,
  }) async {
    try {
      final response = await _dio.post(
        '$API_VERSION/auth/verify',
        data: {
          if (phoneNumber != null) 'phone_number': phoneNumber,
          if (email != null) 'email': email,
          'otp': otp,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final authResponse = AuthResponse.fromJson(response.data);
        
        // Store tokens securely
        await SecureStorageService.setAccessToken(authResponse.accessToken);
        await SecureStorageService.setRefreshToken(authResponse.refreshToken);
        await SecureStorageService.setUserId(authResponse.userId);
        if (phoneNumber != null) {
          await SecureStorageService.setUserPhone(phoneNumber);
        }
        if (email != null) {
          await SecureStorageService.setUserEmail(email);
        }
        
        return authResponse;
      } else {
        throw AuthException(
          response.data['message'] ?? 'Invalid OTP',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw AuthException(
        e.response?.data['message'] ?? 'Failed to verify OTP',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Refresh access token
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await SecureStorageService.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _dio.post(
        '$API_VERSION/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final newToken = response.data['access_token'];
        await SecureStorageService.setAccessToken(newToken);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      final token = await SecureStorageService.getAccessToken();
      if (token != null) {
        await _dio.post(
          '$API_VERSION/auth/logout',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      }
    } catch (e) {
      // Ignore errors during logout
    } finally {
      await SecureStorageService.clearAll();
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    return await SecureStorageService.isLoggedIn();
  }

  /// Get current user info
  Future<UserInfo?> getCurrentUser() async {
    try {
      final response = await _dio.get('$API_VERSION/auth/me');
      if (response.statusCode == 200) {
        return UserInfo.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Auth response model
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final DateTime expiresAt;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.expiresAt,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      userId: json['user_id'],
      expiresAt: DateTime.parse(json['expires_at']),
    );
  }
}

/// User info model
class UserInfo {
  final String id;
  final String? phoneNumber;
  final String? email;
  final String? name;
  final DateTime createdAt;

  UserInfo({
    required this.id,
    this.phoneNumber,
    this.email,
    this.name,
    required this.createdAt,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'],
      phoneNumber: json['phone_number'],
      email: json['email'],
      name: json['name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
