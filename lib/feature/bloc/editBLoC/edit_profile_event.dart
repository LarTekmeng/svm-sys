import 'package:equatable/equatable.dart';
import 'package:online_doc_savimex/app_import.dart';

abstract class EmployeeProfileEvent extends Equatable {
  const EmployeeProfileEvent();
  @override
  List<Object?> get props => [];
}

class EmployeeProfileStarted extends EmployeeProfileEvent {
  final String employeeId;
  const EmployeeProfileStarted(this.employeeId);

  @override
  List<Object?> get props => [employeeId];
}

class EmployeeProfileRefreshRequested extends EmployeeProfileEvent {
  const EmployeeProfileRefreshRequested();
}

class EmployeeProfileUpdatedLocally extends EmployeeProfileEvent {
  final Employee employee;
  const EmployeeProfileUpdatedLocally(this.employee);

  @override
  List<Object?> get props => [employee];
}
