part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String? phoneNumber;
  final String? email;

  const AuthLoginRequested({
    this.phoneNumber,
    this.email,
  });

  @override
  List<Object?> get props => [phoneNumber, email];
}

class AuthOtpSubmitted extends AuthEvent {
  final String otp;
  final String? phoneNumber;
  final String? email;

  const AuthOtpSubmitted({
    required this.otp,
    this.phoneNumber,
    this.email,
  });

  @override
  List<Object?> get props => [otp, phoneNumber, email];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthCheckRequested extends AuthEvent {}
