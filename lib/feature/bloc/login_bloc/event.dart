// lib/bloc/auth/auth_event.dart
abstract class AuthLoginEvent {}

class LoginRequested extends AuthLoginEvent {
  final String employeeID, password;
  LoginRequested(this.employeeID, this.password);
}
