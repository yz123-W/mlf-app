/// 运行期环境配置。
///
/// 默认指向云端生产后端（经 Nginx 网关转发）：
/// `http://121.43.250.238/stu/prod-api`
///
/// 本地开发需要覆盖时通过编译期变量传入：
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8082`
/// `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8082`
class Env {
  Env._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// 后端 API 根地址。默认云端，编译期可覆盖。
  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    return 'http://121.43.250.238/stu/prod-api';
  }

  /// 本端应用域（与后端 `mlf.app-scope` 一致）。学生端固定为 stu。
  static const String appScope = 'stu';
}
