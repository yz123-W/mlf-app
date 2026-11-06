import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

/// 版本更新信息。
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.downloadUrl,
    required this.forceUpdate,
    required this.releaseNote,
  });

  final int versionCode;
  final String versionName;
  final String downloadUrl;
  final bool forceUpdate;
  final String releaseNote;
}

/// 版本检查服务。
///
/// 启动后请求 `/interview/app/version`（3 秒超时），与本地 versionCode 比较；
/// 任何异常都静默返回 null，绝不阻塞启动流程。
class AppUpdateService {
  AppUpdateService(this._client);

  static const Duration _timeout = Duration(seconds: 3);

  final ApiClient _client;

  /// 有新版本时返回更新信息，否则返回 null。
  Future<AppUpdateInfo?> check() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(package.buildNumber) ?? 0;
      final response = await _client
          .getJson(
            '/interview/app/version',
            query: {'platform': _platform},
            auth: false,
            handleUnauthorized: false,
          )
          .timeout(_timeout);
      final data = response['data'];
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data);
      final latestCode = _asInt(map['versionCode']);
      final downloadUrl = map['downloadUrl']?.toString().trim() ?? '';
      if (latestCode == null || latestCode <= currentCode || downloadUrl.isEmpty) {
        return null;
      }
      return AppUpdateInfo(
        versionCode: latestCode,
        versionName: map['versionName']?.toString() ?? '',
        downloadUrl: downloadUrl,
        forceUpdate: map['forceUpdate']?.toString() == '1',
        releaseNote: map['releaseNote']?.toString() ?? '',
      );
    } catch (_) {
      // 网络异常 / 超时 / 解析失败一律静默，不打扰用户。
      return null;
    }
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String get _platform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }
}

/// 版本检查服务实例。
final appUpdateServiceProvider = Provider<AppUpdateService>(
  (ref) => AppUpdateService(ref.watch(apiClientProvider)),
);
