import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import 'package:online_doc_savimex/app_import.dart';


class DepartmentRepository {

  final String _bashUrl = getLocalhost();
  /// Fetches all departments from GET /api/departments/department
  Future<List<Department>> fetchDepartments() async {
    final url = Uri.parse('$_bashUrl/api/departments/all');
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load departments (status: ${response.statusCode})'
      );
    }

    // Parse as a List since your controller does `res.json(rows)` directly
    final List rawList = jsonDecode(response.body) as List;
    return rawList.map((json) => Department.fromJson(json as Map<String,dynamic>)).toList();
  }
}
