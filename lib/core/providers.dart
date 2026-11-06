import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'analytics/analytics.dart';
import 'env.dart';
import 'network/api_client.dart';
import 'network/retry_interceptor.dart';
import 'session/session_events.dart';
import 'storage/token_storage.dart';

/// 令牌存储。
final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(const FlutterSecureStorage()),
);

/// 全局 Dio 实例（统一注入 `Authorization: Bearer <token>`）。
final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
      // 后端始终返回响应体（错误也带 msg），避免 Dio 抛裸异常
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // `auth: false` 的请求（登录/注册/找回）不注入令牌
        if (options.extra['auth'] != false) {
          final token = await tokenStorage.read();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
    ),
  );

  // 鉴权之后：GET 连接类错误有限重试。
  dio.interceptors.add(RetryInterceptor(dio));

  return dio;
});

/// 埋点上报（首次使用时注册前后台监听）。
final analyticsProvider = Provider<Analytics>(
  (ref) => Analytics(ref.watch(apiClientProvider)),
);

/// 统一接口客户端。
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    ref.watch(dioProvider),
    // 收到 401：先清除本地令牌，再通知全局回登录页（避免清理与重新登录的竞态）
    onUnauthorized: () async {
      await ref.read(tokenStorageProvider).clear();
      ref.read(sessionExpiredProvider.notifier).notifyExpired();
    },
  ),
);
