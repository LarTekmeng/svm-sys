import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:online_doc_savimex/app_import.dart';

String _baseUrl = getLocalhost();

Future<Map<String, dynamic>> fetchEmployeeByID(String employeeID) async {
  final resp = await http.get(Uri.parse('$_baseUrl/api/employees/$employeeID'));
  if (resp.statusCode != 200) {
    throw Exception('Failed to load user');
  }
  return jsonDecode(resp.body);
}