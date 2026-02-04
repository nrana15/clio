part of 'auth_bloc.dart';

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

  const AuthOtpSent({
    this.phoneNumber,
    this.email,
  });

  @override
  List<Object?> get props => [phoneNumber, email];
}

class AuthAuthenticated extends AuthState {
  final String userId;
  final String? phoneNumber;
  final String? email;

  const AuthAuthenticated({
    required this.userId,
    this.phoneNumber,
    this.email,
  });

  @override
  List<Object?> get props => [userId, phoneNumber, email];
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
