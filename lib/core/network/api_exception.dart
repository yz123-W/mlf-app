/// 统一的接口异常（承载后端 `msg` 或网络错误文案）。
class ApiException implements Exception {
  ApiException(this.message, {this.code});

  final String message;
  final int? code;

  /// 令牌失效（后端 RuoYi 约定：HTTP 200 + code 401）。
  bool get isUnauthorized => code == 401;

  @override
  String toString() => message;
}
