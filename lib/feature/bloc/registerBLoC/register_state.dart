import 'package:equatable/equatable.dart';
import 'package:online_doc_savimex/app_import.dart';

abstract class RegisterState extends Equatable {
  @override
  List<Object?> get props => [];
}

class RegisterInitial extends RegisterState {}
class RegisterLoading extends RegisterState {}

class DepartmentsLoadSuccess extends RegisterState {
  final List<Department> departments;
  DepartmentsLoadSuccess(this.departments);

  @override
  List<Object?> get props => [departments];
}

class RegisterSuccess extends RegisterState {}

class RegisterFailure extends RegisterState {
  final String error;
  RegisterFailure(this.error);

  @override
  List<Object?> get props => [error];
}