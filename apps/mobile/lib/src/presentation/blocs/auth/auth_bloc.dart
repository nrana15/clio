import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/services/secure_storage_service.dart';
import '../../../data/services/auth_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService = AuthService();

  AuthBloc() : super(AuthInitial()) {
    on<AuthStarted>(_onAuthStarted);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthOtpSubmitted>(_onAuthOtpSubmitted);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthCheckRequested>(_onAuthCheckRequested);
  }

  Future<void> _onAuthStarted(
    AuthStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      // Check if user is already authenticated
      final isLoggedIn = await _authService.isAuthenticated();
      
      if (isLoggedIn) {
        final userId = await SecureStorageService.getUserId();
        final phone = await SecureStorageService.getUserPhone();
        final email = await SecureStorageService.getUserEmail();
        
        emit(AuthAuthenticated(
          userId: userId!,
          phoneNumber: phone,
          email: email,
        ));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(const AuthError('Failed to check authentication status'));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      // Request OTP
      if (event.phoneNumber != null) {
        await _authService.requestPhoneOtp(event.phoneNumber!);
      } else if (event.email != null) {
        await _authService.requestEmailOtp(event.email!);
      }
      
      emit(AuthOtpSent(
        phoneNumber: event.phoneNumber,
        email: event.email,
      ));
    } on AuthException catch (e) {
      emit(AuthError(e.message));
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(const AuthError('Failed to send OTP. Please try again.'));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthOtpSubmitted(
    AuthOtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      final response = await _authService.verifyOtp(
        phoneNumber: event.phoneNumber,
        email: event.email,
        otp: event.otp,
      );
      
      emit(AuthAuthenticated(
        userId: response.userId,
        phoneNumber: event.phoneNumber,
        email: event.email,
      ));
    } on AuthException catch (e) {
      emit(AuthError(e.message));
      // Revert to OTP sent state so user can retry
      if (event.phoneNumber != null || event.email != null) {
        emit(AuthOtpSent(
          phoneNumber: event.phoneNumber,
          email: event.email,
        ));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(const AuthError('Failed to verify OTP. Please try again.'));
      if (event.phoneNumber != null || event.email != null) {
        emit(AuthOtpSent(
          phoneNumber: event.phoneNumber,
          email: event.email,
        ));
      } else {
        emit(AuthUnauthenticated());
      }
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      await _authService.logout();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(const AuthError('Failed to logout'));
      // Force logout even if API call fails
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Similar to AuthStarted but doesn't show loading state
    try {
      final isLoggedIn = await _authService.isAuthenticated();
      
      if (isLoggedIn) {
        final currentState = state;
        if (currentState is! AuthAuthenticated) {
          final userId = await SecureStorageService.getUserId();
          final phone = await SecureStorageService.getUserPhone();
          final email = await SecureStorageService.getUserEmail();
          
          emit(AuthAuthenticated(
            userId: userId!,
            phoneNumber: phone,
            email: email,
          ));
        }
      }
    } catch (e) {
      // Silent fail
    }
  }
}
