import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:online_doc_savimex/app_import.dart';
class HomeView{
  final List<Document> uploadedByMe;
  final List<Document> assignedToMe;
  HomeView({required this.uploadedByMe, required this.assignedToMe});
}

class HomeRepo{
  final AuthRepository authRepo = AuthRepository.instance;
  final String baseUrl = getLocalhost();
  
  Future<HomeView> getView() async {
    
    final token = await authRepo.getPersistedToken();
    final url = Uri.parse('$baseUrl/api/home/overview');
    final res = await http.get(url, headers: { 'Authorization' : 'Bearer $token', 'Content-Type' : 'application/json'});
    if (res.statusCode != 200){
      throw Exception('Failed to fetch home view (${res.statusCode}): ${res.body}');
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final uploaded = (map['uploadedByMe'] as List).map((e) => Document.fromJson(e as Map<String, dynamic>)).toList();
    final assigned = (map['assignedToMe'] as List).map((e) => Document.fromJson(e as Map<String, dynamic>)).toList();

    return HomeView(uploadedByMe: uploaded, assignedToMe: assigned);
  }
}
