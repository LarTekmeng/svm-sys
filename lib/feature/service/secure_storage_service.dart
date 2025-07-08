import 'package:online_doc_savimex/app_import.dart';

class SecureStorageService{


  static const _keyToken = 'jwt_token';
  static const _keyEmployee = 'employee_json';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> writeToken(String token) =>
      _storage.write(key: _keyToken, value: token);

  Future<String?> readToken() =>
      _storage.read(key: _keyToken);

  Future<void> deleteToken() =>
      _storage.delete(key: _keyToken);

  Future<void> writeEmployee(String json) =>
      _storage.write(key: _keyEmployee, value: json);

  Future<String?> readEmployee() =>
      _storage.read(key: _keyEmployee);

  Future<void> deleteEmployee() =>
      _storage.delete(key: _keyEmployee);

  Future<void> clearAll() async{
    await _storage.deleteAll();
  }
}