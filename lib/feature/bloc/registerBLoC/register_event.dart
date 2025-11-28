// lib/bloc/auth/auth_event.dart
import 'dart:io';

abstract class RegisterEvent {}

class LoadDepartments extends RegisterEvent {}
class LoadRoles extends RegisterEvent {}

class RegisterRequested extends RegisterEvent {
  final String employeeName, email, password, employeeID;
  final int departmentID;
  final int? roleId;
  final File? profileImage;
  final bool createNew;
  RegisterRequested(
      this.employeeName,
      this.email,
      this.password,
      this.departmentID,
      this.employeeID,
      {this.profileImage,this.roleId, this.createNew = false}
      );
}

// Event for updating employee (add to your RegisterBloc)
class UpdateEmployeeRequested extends RegisterEvent {
  final int employeeId;
  final String name;
  final String email;
  final String? password;
  final int departmentId;
  final String empId;
  final int? roleId;
  final File? profileImage;

  UpdateEmployeeRequested({
    required this.employeeId,
    required this.name,
    required this.email,
    this.password,
    required this.departmentId,
    required this.empId,
    this.roleId,
    this.profileImage,
  });
}


