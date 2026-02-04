import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/services/secure_storage_service.dart';
import '../../../data/services/auth_service.dart';

// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {}
class AuthLoginRequested extends AuthEvent {
  final String? phoneNumber;
  final String? email;
  const AuthLoginRequested({this.phoneNumber, this.email});
  @override
  List<Object?> get props => [phoneNumber, email];
}

class AuthOtpSubmitted extends AuthEvent {
  final String otp;
  final String? phoneNumber;
  final String? email;
  const AuthOtpSubmitted({required this.otp, this.phoneNumber, this.email});
  @override
  List<Object?> get props => [otp, phoneNumber, email];
}

class AuthLogoutRequested extends AuthEvent {}
class AuthCheckRequested extends AuthEvent {}

// States
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthUnauthenticated extends AuthState {}

class AuthOtpSent extends AuthState {
  final String? phoneNumber;
  final String? email;
  const AuthOtpSent({this.phoneNumber, this.email});
  @override
  List<Object?> get props => [phoneNumber, email];
}

class AuthAuthenticated extends AuthState {
  final String userId;
  final String? phoneNumber;
  final String? email;
  const AuthAuthenticated({required this.userId, this.phoneNumber, this.email});
  @override
  List<Object?> get props => [userId, phoneNumber, email];
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService = AuthService();

  AuthBloc() : super(AuthInitial()) {
    on<AuthStarted>(_onAuthStarted);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthOtpSubmitted>(_onAuthOtpSubmitted);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthCheckRequested>(_onAuthCheckRequested);
  }

  Future<void> _onAuthStarted(AuthStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final isLoggedIn = await _authService.isAuthenticated();
      if (isLoggedIn) {
        final userId = await SecureStorageService.getUserId();
        final phone = await SecureStorageService.getUserPhone();
        final email = await SecureStorageService.getUserEmail();
        emit(AuthAuthenticated(userId: userId!, phoneNumber: phone, email: email));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(const AuthError('Failed to check authentication status'));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthLoginRequested(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      if (event.phoneNumber != null) {
        await _authService.requestPhoneOtp(event.phoneNumber!);
      } else if (event.email != null) {
        await _authService.requestEmailOtp(event.email!);
      }
      emit(AuthOtpSent(phoneNumber: event.phoneNumber, email: event.email));
    } catch (e) {
      emit(const AuthError('Failed to send OTP. Please try again.'));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthOtpSubmitted(AuthOtpSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _authService.verifyOtp(
        phoneNumber: event.phoneNumber,
        email: event.email,
        otp: event.otp,
      );
      emit(AuthAuthenticated(userId: response.userId, phoneNumber: event.phoneNumber, email: event.email));
    } catch (e) {
      emit(const AuthError('Failed to verify OTP. Please try again.'));
      if (event.phoneNumber != null || event.email != null) {
        emit(AuthOtpSent(phoneNumber: event.phoneNumber, email: event.email));
      } else {
        emit(AuthUnauthenticated());
      }
    }
  }

  Future<void> _onAuthLogoutRequested(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authService.logout();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(const AuthError('Failed to logout'));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) async {
    try {
      final isLoggedIn = await _authService.isAuthenticated();
      if (isLoggedIn && state is! AuthAuthenticated) {
        final userId = await SecureStorageService.getUserId();
        final phone = await SecureStorageService.getUserPhone();
        final email = await SecureStorageService.getUserEmail();
        emit(AuthAuthenticated(userId: userId!, phoneNumber: phone, email: email));
      }
    } catch (e) {
      // Silent fail
    }
  }
}
