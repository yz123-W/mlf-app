import '../../../shared/utils/json.dart';

/// 开屏广告（`biz_advert` 的 `mobile_splash` 广告位投影）。
class SplashAdvert {
  const SplashAdvert({
    required this.id,
    required this.position,
    required this.title,
    required this.imageUrl,
    required this.jumpType,
    required this.jumpTarget,
    required this.duration,
    required this.skippable,
    required this.frequency,
  });

  final int id;
  final String position;
  final String title;
  final String imageUrl;
  final String jumpType;
  final String jumpTarget;
  final int duration;
  final bool skippable;

  /// 展示频次：session 每次冷启动 / day 每天一次 / always 每次。
  final String frequency;

  factory SplashAdvert.fromJson(Map<String, dynamic> json) {
    return SplashAdvert(
      id: asInt(json['id']),
      position: '${json['position'] ?? ''}',
      title: '${json['title'] ?? ''}',
      imageUrl: '${json['imageUrl'] ?? ''}',
      jumpType: '${json['jumpType'] ?? 'none'}',
      jumpTarget: '${json['jumpTarget'] ?? ''}',
      duration: asInt(json['duration'], fallback: 4),
      skippable: '${json['skippable'] ?? '1'}' == '1',
      frequency: '${json['frequency'] ?? 'session'}',
    );
  }
}
