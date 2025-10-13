// lib/models/department_model.dart
class Department {
  final int id;
  final String name;

  Department({ required this.id, required this.name });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}
