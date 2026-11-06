import 'dart:async';

import 'package:dio/dio.dart';

/// GET 幂等重试：仅对连接类错误做有限次重试，避免把业务错误重复提交。
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.maxRetries = 2,
    this.delays = const [
      Duration(milliseconds: 400),
      Duration(milliseconds: 800),
    ],
  });

  final Dio _dio;
  final int maxRetries;
  final List<Duration> delays;

  static const String _retryCountKey = 'retryCount';
  static const String _noRetryKey = 'noRetry';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    final attempt = err.requestOptions.extra[_retryCountKey] as int? ?? 0;
    if (attempt >= maxRetries) {
      handler.next(err);
      return;
    }

    final delay = delays[attempt < delays.length ? attempt : delays.length - 1];
    await Future<void>.delayed(delay);

    final options = err.requestOptions
      ..extra[_retryCountKey] = attempt + 1;
    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } catch (_) {
      // 本轮仍失败：交给下一轮拦截或最终失败。
      handler.next(err);
    }
  }

  bool _shouldRetry(DioException err) {
    if (err.requestOptions.method.toUpperCase() != 'GET') return false;
    if (err.requestOptions.extra[_noRetryKey] == true) return false;
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      default:
        return false;
    }
  }
}
