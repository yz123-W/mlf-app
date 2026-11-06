import 'dart:async';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import 'auth_api.dart';
import 'auth_models.dart';

/// 启动阶段对本地登录态的判定结果。
enum SessionGate {
  /// token 有效，直接进首页。
  loggedIn,

  /// 未登录或 token 已失效（已清理本地 token）。
  loggedOut,

  /// 网络异常 / 超时：保留 token，按已登录处理，避免误退登录。
  networkError,
}

/// 认证仓库：编排接口调用与令牌落盘。
class AuthRepository {
  const AuthRepository(this._api, this._tokens);

  final AuthApi _api;
  final TokenStorage _tokens;

  Future<SmsSendResult> sendSms({required String phone, required String scene}) =>
      _api.sendSms(phone: phone, scene: scene);

  Future<void> loginBySms({required String phone, required String code}) async {
    final token = await _api.loginBySms(phone: phone, code: code);
    await _tokens.save(token);
  }

  Future<void> loginByPassword({required String phone, required String password}) async {
    final token = await _api.loginByPassword(phone: phone, password: password);
    await _tokens.save(token);
  }

  Future<void> registerBySms({
    required String phone,
    required String code,
    required bool agreed,
  }) async {
    final token = await _api.registerBySms(phone: phone, code: code, agreed: agreed);
    await _tokens.save(token);
  }

  Future<void> resetPassword({
    required String phone,
    required String code,
    required String password,
  }) =>
      _api.resetPassword(phone: phone, code: code, password: password);

  Future<bool> isLoggedIn() => _tokens.hasToken();

  /// 启动静默校验：不弹窗、不跳页，只返回判定结果。
  ///
  /// 注意：本地令牌读取不设超时（冷启动首次读取安全存储可能耗时数秒），
  /// 超时只加在网络校验上，避免把“读取慢”误判成“已登录”。
  Future<SessionGate> validateSession() async {
    bool hasToken;
    try {
      hasToken = await isLoggedIn();
    } catch (_) {
      // 本地令牌不可读：按未登录处理，走正常的广告 / 登录流程。
      return SessionGate.loggedOut;
    }
    if (!hasToken) return SessionGate.loggedOut;
    try {
      await _api
          .getInfo(handleUnauthorized: false)
          .timeout(const Duration(seconds: 5));
      return SessionGate.loggedIn;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _tokens.clear();
        return SessionGate.loggedOut;
      }
      return SessionGate.networkError;
    } catch (_) {
      return SessionGate.networkError;
    }
  }

  /// 已登录时返回用户信息；仅 401 时清理 token，网络异常向上抛出。
  Future<StudentUser?> currentUser() async {
    if (!await isLoggedIn()) return null;
    try {
      return await _api.getInfo();
    } on ApiException catch (e) {
      if (!e.isUnauthorized) rethrow;
      await _tokens.clear();
      return null;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    await _tokens.clear();
  }
}
