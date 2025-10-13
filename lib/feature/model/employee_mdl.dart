
class Employee{
  final int? id;
  final String employeeName;
  final String email;
  final int? departmentID;
  final String employeeID;
  final String departmentName;
  final String profileImageUrl;

  Employee({
    this.id,
    required this.employeeName,
    required this.email,
    this.departmentID,
    required this.employeeID,
    required this.departmentName,
    required this.profileImageUrl,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as int?,
      employeeName: (json['employee_name'] as String?) ?? '',
      email:  (json['email'] as String?) ?? '',
      departmentID:  json['department_id'] as int?,
      employeeID: (json['em_id'] as String?) ?? '',
      departmentName: (json['department_name'] as String?) ?? '',
      profileImageUrl: (json['profile_image_url'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id' : id,
    'employee_name' : employeeName,
    'email' : email,
    'dp_id' : departmentID,
    'em_id' : employeeID,

  };

  Employee copyWith({
    int? id,
    String? employeeName,
    String? email,
    int? departmentID,
    String? employeeID,
    String? departmentName,
    String? profileImageUrl,
  }) {
    return Employee(
      id: id ?? this.id,
      employeeName: employeeName ?? this.employeeName,
      email: email ?? this.email,
      departmentID: departmentID ?? this.departmentID,
      employeeID: employeeID ?? this.employeeID,
      departmentName: departmentName ?? this.departmentName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}
