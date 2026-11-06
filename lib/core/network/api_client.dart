import 'package:dio/dio.dart';

import 'api_exception.dart';

/// RuoYi 标准响应封装：`{code, msg, data}` / 分页 `{code, msg, rows, total}`。
///
/// 统一解包与错误处理，业务层拿到的即完整响应体（含 token 等同级字段）。
class ApiClient {
  ApiClient(this._dio, {this.onUnauthorized});

  final Dio _dio;

  /// 收到 401 时触发（由调用方决定清 token / 跳登录）。
  final void Function()? onUnauthorized;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
    bool handleUnauthorized = true,
    CancelToken? cancelToken,
  }) async {
    final response = await _send(
      () => _dio.get(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
        options: Options(extra: {
          'auth': auth,
          'handleUnauthorized': handleUnauthorized,
        }),
      ),
    );
    return _asMap(_unwrap(response), response.statusCode);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? data,
    bool auth = true,
    CancelToken? cancelToken,
  }) async {
    final response = await _send(
      () => _dio.post(
        path,
        data: data,
        cancelToken: cancelToken,
        options: Options(extra: {'auth': auth}),
      ),
    );
    return _asMap(_unwrap(response), response.statusCode);
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Object? data,
    bool auth = true,
    CancelToken? cancelToken,
  }) async {
    final response = await _send(
      () => _dio.put(
        path,
        data: data,
        cancelToken: cancelToken,
        options: Options(extra: {'auth': auth}),
      ),
    );
    return _asMap(_unwrap(response), response.statusCode);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    bool auth = true,
    CancelToken? cancelToken,
  }) async {
    final response = await _send(
      () => _dio.delete(
        path,
        cancelToken: cancelToken,
        options: Options(extra: {'auth': auth}),
      ),
    );
    return _asMap(_unwrap(response), response.statusCode);
  }

  /// 表单上传（multipart/form-data）。
  Future<Map<String, dynamic>> postMultipart(
    String path,
    FormData data, {
    bool auth = true,
    CancelToken? cancelToken,
  }) async {
    final response = await _send(
      () => _dio.post(
        path,
        data: data,
        cancelToken: cancelToken,
        options: Options(extra: {'auth': auth}, contentType: 'multipart/form-data'),
      ),
    );
    return _asMap(_unwrap(response), response.statusCode);
  }

  /// 下载二进制响应体（如报告 PDF），不做 `{code,msg,data}` 信封解包。
  Future<List<int>> getBytes(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
    bool handleUnauthorized = true,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          extra: {'auth': auth, 'handleUnauthorized': handleUnauthorized},
        ),
      );
      final status = response.statusCode;
      if (status == 401) {
        _notifyUnauthorized(response.requestOptions);
        throw ApiException('登录已过期，请重新登录', code: 401);
      }
      if (status != null && status >= 400) {
        throw ApiException('文件下载失败（HTTP $status）', code: status);
      }
      return response.data ?? const [];
    } on DioException catch (e) {
      throw ApiException(_networkMessage(e), code: e.response?.statusCode);
    }
  }

  Future<Response<dynamic>> _send(Future<Response<dynamic>> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map && body['msg'] != null) {
        throw ApiException(body['msg'].toString(), code: _statusCodeOf(body, e));
      }
      throw ApiException(_networkMessage(e), code: e.response?.statusCode);
    }
  }

  int? _statusCodeOf(Map body, DioException e) {
    final code = body['code'];
    if (code is int) return code;
    if (code is String) return int.tryParse(code);
    return e.response?.statusCode;
  }

  dynamic _unwrap(Response<dynamic> response) {
    final data = response.data;
    if (data is Map) {
      final code = _asInt(data['code']);
      if (code != null && code != 200) {
        if (code == 401) _notifyUnauthorized(response.requestOptions);
        throw ApiException(data['msg']?.toString() ?? '请求失败', code: code);
      }
    }
    return data;
  }

  /// 401 统一通知；`handleUnauthorized: false` 的请求（如启动静默校验）由调用方自行处理。
  void _notifyUnauthorized(RequestOptions options) {
    if (options.extra['handleUnauthorized'] == false) return;
    onUnauthorized?.call();
  }

  Map<String, dynamic> _asMap(dynamic data, int? statusCode) {
    if (data is Map) return Map<String, dynamic>.from(data);
    // 网关 404 HTML、空 body 等非 JSON 响应不能被当成「成功但无数据」。
    throw ApiException(
      '服务返回格式异常${statusCode == null ? '' : '（HTTP $statusCode）'}',
      code: statusCode,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String _networkMessage(DioException e) {
    if (const bool.fromEnvironment('NETWORK_DIAG')) {
      final response = e.response;
      final uri = e.requestOptions.uri;
      return '网络异常[${e.type.name}'
          '${response != null ? '/http=${response.statusCode}' : ''} '
          '${uri.host}:${uri.port}${uri.path}]';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '网络超时，请稍后重试';
      case DioExceptionType.connectionError:
        return '无法连接服务器，请检查网络与后端是否已启动';
      default:
        return '网络异常，请稍后重试';
    }
  }
}
