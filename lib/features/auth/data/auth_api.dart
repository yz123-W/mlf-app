import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'auth_models.dart';

/// 学生端认证接口（`/interview/auth/*` 与 `/getInfo`）。
///
/// 契约见 `mlf-stu` 的 `StudentAuthController`。
class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  /// 发送短信验证码。scene ∈ {login, register, resetPwd}。
  Future<SmsSendResult> sendSms({required String phone, required String scene}) async {
    final res = await _client.postJson(
      '/interview/auth/sms/send',
      data: {'phone': phone, 'scene': scene},
      auth: false,
    );
    return SmsSendResult.fromJson(res);
  }

  /// 手机号 + 验证码登录，返回令牌。
  Future<String> loginBySms({required String phone, required String code}) async {
    final res = await _client.postJson(
      '/interview/auth/login/sms',
      data: {'phone': phone, 'code': code},
      auth: false,
    );
    return _extractToken(res);
  }

  /// 手机号 + 密码登录，返回令牌。
  Future<String> loginByPassword({required String phone, required String password}) async {
    final res = await _client.postJson(
      '/interview/auth/login/password',
      data: {'phone': phone, 'password': password},
      auth: false,
    );
    return _extractToken(res);
  }

  /// 手机号 + 验证码注册（注册即用，直接返回令牌）。
  Future<String> registerBySms({
    required String phone,
    required String code,
    required bool agreed,
  }) async {
    final res = await _client.postJson(
      '/interview/auth/register/sms',
      data: {'phone': phone, 'code': code, 'agreed': agreed},
      auth: false,
    );
    return _extractToken(res);
  }

  /// 忘记密码：手机号 + 验证码（场景 resetPwd）重置密码。
  Future<void> resetPassword({
    required String phone,
    required String code,
    required String password,
  }) async {
    await _client.postJson(
      '/interview/auth/resetPwd',
      data: {'phone': phone, 'code': code, 'password': password},
      auth: false,
    );
  }

  /// 拉取当前登录用户信息。
  ///
  /// [handleUnauthorized] 为 false 时，401 不触发全局“跳登录”回调，
  /// 供启动阶段静默校验使用。
  Future<StudentUser> getInfo({bool handleUnauthorized = true}) async {
    final res = await _client.getJson(
      '/getInfo',
      handleUnauthorized: handleUnauthorized,
    );
    final user = res['user'];
    if (user is Map) {
      return StudentUser.fromJson(Map<String, dynamic>.from(user));
    }
    throw ApiException('登录信息解析失败');
  }

  /// 退出登录（后端失败不阻塞本地清理）。
  Future<void> logout() async {
    try {
      await _client.postJson('/logout');
    } on ApiException {
      // 忽略：令牌可能已失效
    }
  }

  String _extractToken(Map<String, dynamic> res) {
    final token = res['token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('登录响应缺少令牌');
    }
    return token;
  }
}
