import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<AuthStarted>(_onAuthStarted);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthOtpSubmitted>(_onAuthOtpSubmitted);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
  }

  Future<void> _onAuthStarted(
    AuthStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    // TODO: Check for existing token
    await Future.delayed(const Duration(seconds: 2));
    emit(AuthUnauthenticated());
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthOtpSent(
      phoneNumber: event.phoneNumber,
      email: event.email,
    ));
  }

  Future<void> _onAuthOtpSubmitted(
    AuthOtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    // TODO: Verify OTP with API
    await Future.delayed(const Duration(seconds: 1));
    emit(AuthAuthenticated(
      userId: 'test-user-id',
      phoneNumber: event.phoneNumber,
    ));
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    // TODO: Clear tokens
    emit(AuthUnauthenticated());
  }
}
