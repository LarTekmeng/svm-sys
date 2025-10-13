import 'package:equatable/equatable.dart';
import 'package:online_doc_savimex/app_import.dart';

enum EmployeeProfileStatus { initial, loading, success, failure }

class EmployeeProfileState extends Equatable {
  final Employee? employee;
  final EmployeeProfileStatus status;
  final String? error;

  const EmployeeProfileState({
    this.employee,
    this.status = EmployeeProfileStatus.initial,
    this.error,
  });

  EmployeeProfileState copyWith({
    Employee? employee,
    EmployeeProfileStatus? status,
    String? error,
  }) {
    return EmployeeProfileState(
      employee: employee ?? this.employee,
      status: status ?? this.status,
      error: error,
    );
  }

  @override
  List<Object?> get props => [employee, status, error];
}
