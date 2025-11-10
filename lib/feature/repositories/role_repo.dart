import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:online_doc_savimex/feature/model/role_mdl.dart';

class RoleRepository{
  final String baseUrl;
  RoleRepository({required this.baseUrl});

  Future<List<Role>> fetchRole() async {
    final url = Uri.parse('$baseUrl/api/role');
    final respone = await http.get(url);
    if(respone.statusCode != 200) {
      throw Exception('Failed to load Role (status: ${respone.statusCode})');
    }
    final List rawList = jsonDecode(respone.body) as List;
    return rawList.map((json) => Role.fromJson(json as Map<String, dynamic>)).toList();
  }
}