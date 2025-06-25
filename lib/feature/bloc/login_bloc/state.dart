import 'package:equatable/equatable.dart';
import 'package:online_doc_savimex/app_import.dart';

abstract class AuthLoginState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthLoginState {}
class AuthLoading extends AuthLoginState {}

class AuthAuthenticated extends AuthLoginState {
  final Employee employee;
  AuthAuthenticated(this.employee);

  @override
  List<Object?> get props => [employee];
}

class AuthFailure extends AuthLoginState {
  final String error;
  AuthFailure(this.error);

  @override
  List<Object?> get props => [error];
}
