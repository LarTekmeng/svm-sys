import 'package:flutter/cupertino.dart';

class Role{
  final int id;
  final String roleCode;

  Role({ required this.id, required this.roleCode });

  factory Role.fromJson(Map<String, dynamic> json){
    return Role(
        id: json['id'] as int,
        roleCode: json['code'] as String,
    );
  }
}