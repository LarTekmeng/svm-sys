
class Employee{
  final int? id;
  final String employeeName;
  final String email;
  final int? departmentID;
  final String employeeID;
  final String departmentName;

  Employee({
    this.id,
    required this.employeeName,
    required this.email,
    this.departmentID,
    required this.employeeID,
    required this.departmentName,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as int?,
      employeeName: (json['employee_name'] as String?) ?? '',
      email:  (json['email'] as String?) ?? '',
      departmentID:  json['dp_id'] as int?,
      employeeID: (json['em_id'] as String?) ?? '',
      departmentName: (json['dp_name'] as String?) ?? '',
    );
  }
}
