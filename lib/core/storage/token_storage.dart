import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 登录令牌的安全存储。
class TokenStorage {
  TokenStorage(this._storage);

  static const String _tokenKey = 'mlf_token';

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _tokenKey);

  Future<void> save(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> clear() => _storage.delete(key: _tokenKey);

  Future<bool> hasToken() async {
    final token = await read();
    return token != null && token.isNotEmpty;
  }
}
