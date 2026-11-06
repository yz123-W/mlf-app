import '../../../core/network/api_client.dart';
import 'splash_ad_models.dart';

/// 开屏广告接口：复用学生端匿名广告位接口，只取 `mobile_splash`。
class SplashAdApi {
  const SplashAdApi(this._client);

  final ApiClient _client;

  Future<SplashAdvert?> mobileSplash() async {
    final res = await _client.getJson(
      '/interview/advert/active',
      query: {'platform': 'mobile'},
      auth: false,
    );
    final data = res['data'];
    if (data is! Map) return null;
    final list = data['mobile_splash'];
    if (list is! List) return null;
    for (final item in list) {
      if (item is! Map) continue;
      final advert = SplashAdvert.fromJson(Map<String, dynamic>.from(item));
      if (advert.imageUrl.isNotEmpty) return advert;
    }
    return null;
  }
}
