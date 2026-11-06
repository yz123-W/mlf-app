import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../interview/data/interview_api.dart';
import '../../interview/data/interview_providers.dart';

/// 登录后「是否跳过新手引导」的判定（方案 B）。
///
/// 依据 = 该账号是否已存在岗位画像：已有画像说明是老用户，直接进首页；
/// 没有画像则走新手引导。判定失败（网络异常等）时安全回退为「走引导」，
/// 避免因接口抖动把新用户直接放进首页。
final onboardingGateProvider = Provider<OnboardingGate>(
  (ref) => OnboardingGate(ref.watch(interviewApiProvider)),
);

class OnboardingGate {
  const OnboardingGate(this._api);

  final InterviewApi _api;

  /// 返回 true 表示已完成过引导（存在岗位画像），应跳过引导。
  Future<bool> completedGuide() async {
    try {
      final profiles = await _api.jobProfileList(pageSize: 1);
      return profiles.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
