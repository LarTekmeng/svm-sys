// lib/bloc/auth/auth_event.dart
abstract class AuthLoginEvent {}

class LoginRequested extends AuthLoginEvent {
  final String employeeID, password;
  final bool rememberMe;
  LoginRequested(this.employeeID, this.password, {this.rememberMe = false});
}

class AppStarted extends AuthLoginEvent {}

class LogoutRequested extends AuthLoginEvent {}
