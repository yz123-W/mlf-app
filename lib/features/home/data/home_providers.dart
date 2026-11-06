import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'home_api.dart';
import 'home_models.dart';
import 'home_repository.dart';

final homeApiProvider = Provider<HomeApi>(
  (ref) => HomeApi(ref.watch(apiClientProvider)),
);

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepository(ref.watch(homeApiProvider)),
);

/// 首页聚合数据（下拉刷新 / 重试用 `ref.invalidate`）。
final homeDashboardProvider = FutureProvider<HomeDashboard>(
  (ref) => ref.watch(homeRepositoryProvider).loadDashboard(),
);

/// 打卡概览（打卡页进入时读取）。
final checkinSummaryProvider = FutureProvider.autoDispose<CheckinSummary>(
  (ref) => ref.watch(homeApiProvider).checkinSummary(),
);
