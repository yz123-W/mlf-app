import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'splash_ad_api.dart';

/// 开屏广告接口。
final splashAdApiProvider = Provider<SplashAdApi>(
  (ref) => SplashAdApi(ref.watch(apiClientProvider)),
);
