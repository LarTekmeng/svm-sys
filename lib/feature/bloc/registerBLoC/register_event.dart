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
  RegisterRequested(
      this.employeeName,
      this.email,
      this.password,
      this.departmentID,
      this.employeeID,
      {this.profileImage,this.roleId}
      );
}
