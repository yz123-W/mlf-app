import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/data/auth_providers.dart';
import '../../home/data/home_models.dart';
import '../../home/data/home_providers.dart';
import '../../messages/data/message_providers.dart';
import 'student_profile_api.dart';
import 'student_profile_models.dart';

/// 「我的」聚合数据：用户信息 + 积分概览 + 消息未读总数。
class ProfileDashboard {
  const ProfileDashboard({this.user, this.points, this.unreadTotal = 0});

  final StudentUser? user;
  final PointsOverview? points;
  final int unreadTotal;
}

/// 逐项降级：任一分项失败不阻断整页。
final profileDashboardProvider = FutureProvider<ProfileDashboard>((ref) async {
  final authApi = ref.watch(authApiProvider);
  final homeApi = ref.watch(homeApiProvider);
  final messageRepo = ref.watch(messageRepositoryProvider);

  final user = await _guard<StudentUser?>(authApi.getInfo, null);
  final points = await _guard<PointsOverview?>(homeApi.pointsOverview, null);
  final overview = await messageRepo.overviewOrEmpty();

  return ProfileDashboard(user: user, points: points, unreadTotal: overview.unreadTotal);
});

final studentProfileApiProvider = Provider<StudentProfileApi>(
  (ref) => StudentProfileApi(ref.watch(apiClientProvider)),
);

final studentProfileRepositoryProvider = Provider<StudentProfileRepository>(
  (ref) => StudentProfileRepository(ref.watch(studentProfileApiProvider)),
);

/// 当前学生的自助档案（保存后用 `ref.invalidate` 刷新）。
final myStudentProfileProvider = FutureProvider<StudentProfileM>(
  (ref) => ref.watch(studentProfileRepositoryProvider).getMyProfile(),
);

Future<T> _guard<T>(Future<T> Function() run, T fallback) async {
  try {
    return await run();
  } catch (_) {
    return fallback;
  }
}
