
class Employee{
  final int? id;
  final String employeeName;
  final String email;
  final int? departmentID;
  final String employeeID;
  final String departmentName;
  final String profileImageUrl;
  final int? roleId;
  final String? roleCode;

  Employee({
    this.id,
    required this.employeeName,
    required this.email,
    this.departmentID,
    required this.employeeID,
    required this.departmentName,
    required this.profileImageUrl,
    this.roleId,
    this.roleCode
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    final dep = json['department_id'] ?? json['dp_id'];
    int? depId;
    if (dep is int) {
      depId = dep;
    } else if (dep is String) {
      depId = int.tryParse(dep);
    }
    return Employee(
      id: json['id'] as int?,
      employeeName: (json['employee_name'] as String?) ?? '',
      email:  (json['email'] as String?) ?? '',
      departmentID:  depId,
      employeeID: (json['em_id'] as String?) ?? '',
      departmentName: (json['department_name'] as String?) ?? '',
      profileImageUrl: (json['profile_image_url'] as String?) ?? '',
      roleId: json['role_id'] as int?,
      roleCode: json['role_code'] as String?,
    );
  }

  Map<String, dynamic> toJson(){
    return{
      'id' : id,
      'employee_name' : employeeName,
      'email' : email,
      'dp_id' : departmentID,
      'em_id' : employeeID,
      'department_name' : departmentName,
      'profile_image_url' : profileImageUrl,
      'role_id' : roleId,
      'role_code' : roleCode,
    };
  }

  Employee copyWith({
    int? id,
    String? employeeName,
    String? email,
    int? departmentID,
    String? employeeID,
    String? departmentName,
    String? profileImageUrl,
    int? roleId,
    String? roleCode,
  }) {
    return Employee(
      id: id ?? this.id,
      employeeName: employeeName ?? this.employeeName,
      email: email ?? this.email,
      departmentID: departmentID ?? this.departmentID,
      employeeID: employeeID ?? this.employeeID,
      departmentName: departmentName ?? this.departmentName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      roleId: roleId ?? this.roleId,
      roleCode: roleCode ?? this.roleCode,
    );
  }
}
