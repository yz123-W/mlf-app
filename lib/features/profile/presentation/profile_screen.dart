import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/env.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../../auth/data/auth_providers.dart';
import '../../feedback/data/feedback_providers.dart';
import '../../home/data/home_models.dart';
import '../data/profile_providers.dart';
import '../data/student_profile_models.dart';

/// 我的：资料卡 + 等级积分卡 + 菜单（消息中心 / 我的投递 / 面试记录 / 退出登录）。
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(profileDashboardProvider);
    final myProfile = ref.watch(myStudentProfileProvider).asData?.value;
    final pendingFeedback =
        ref
            .watch(myFeedbackProvider)
            .asData
            ?.value
            .where((item) => item.isPending)
            .length ??
        0;

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.blue,
        onRefresh: () async => ref.invalidate(profileDashboardProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            const Text(
              '我的',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            dashboard.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.blue),
                ),
              ),
              error: (error, _) => _errorBlock(ref, '$error'),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _profileCard(context, ref, data, myProfile),
                  const SizedBox(height: 14),
                  _pointsCard(data.points),
                  const SizedBox(height: 18),
                  _menu(context, ref, data.unreadTotal, pendingFeedback),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _logout(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _errorBlock(WidgetRef ref, String message) {
    return MlfCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '加载失败',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: FilledButton(
              onPressed: () => ref.invalidate(profileDashboardProvider),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '重新加载',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard(
    BuildContext context,
    WidgetRef ref,
    ProfileDashboard data,
    StudentProfileM? myProfile,
  ) {
    final user = data.user;
    final profileName = myProfile?.nickname ?? '';
    final name = profileName.isNotEmpty
        ? profileName
        : (user?.displayName.isNotEmpty == true ? user!.displayName : '同学');
    final account = user?.userName.isNotEmpty == true ? user!.userName : '';
    final avatar = myProfile?.avatar ?? '';
    final avatarUrl = avatar.isEmpty
        ? ''
        : (avatar.startsWith('http') ? avatar : '${Env.apiBaseUrl}$avatar');
    return GestureDetector(
      onTap: () => context
          .push('/profile/edit')
          .then((_) => ref.invalidate(profileDashboardProvider)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: AppColors.line),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                top: -52,
                child: IgnorePointer(
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFEDF1FA)),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.blueSoft,
                      backgroundImage: avatarUrl.isEmpty
                          ? null
                          : CachedNetworkImageProvider(avatarUrl),
                      child: avatarUrl.isEmpty
                          ? Text(
                              name.characters.first,
                              style: const TextStyle(
                                color: AppColors.blue,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            account.isEmpty ? '面立方 · 学生用户' : '账号 $account',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_outlined, color: AppColors.muted, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pointsCard(PointsOverview? points) {
    if (points == null) {
      return MlfCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: const [
            Icon(Icons.emoji_events_outlined, color: AppColors.blue),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '积分数据暂不可用，稍后下拉刷新重试',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    final progress = (points.levelProgress.clamp(0, 100)) / 100.0;
    return MlfCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '当前积分',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.wineSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEAD3DA)),
                ),
                child: Text(
                  points.level,
                  style: const TextStyle(
                    color: AppColors.wine,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${points.points}',
                style: const TextStyle(
                  fontFamily: 'serif',
                  color: AppColors.blue,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  points.topLevel || points.nextLevel == null
                      ? '已达最高等级'
                      : '距「${points.nextLevel}」还差 ${points.pointsToNext} 分',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: const Color(0xFFEDF0F7),
              valueColor: const AlwaysStoppedAnimation(AppColors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menu(
    BuildContext context,
    WidgetRef ref,
    int unreadTotal,
    int pendingFeedback,
  ) {
    return MlfCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
      child: Column(
        children: [
          _menuRow(
            icon: Icons.chat_bubble_outline,
            label: '消息中心',
            badge: unreadTotal,
            onTap: () => context
                .push('/profile/messages')
                .then((_) => ref.invalidate(profileDashboardProvider)),
          ),
          const Divider(height: 1, color: AppColors.line),
          _menuRow(
            icon: Icons.assignment_turned_in_outlined,
            label: '我的投递',
            onTap: () => context.push('/jobs/applications'),
          ),
          const Divider(height: 1, color: AppColors.line),
          _menuRow(
            icon: Icons.history_edu_outlined,
            label: '面试记录',
            onTap: () => context.push('/interview/reports'),
          ),
          const Divider(height: 1, color: AppColors.line),
          _menuRow(
            icon: Icons.description_outlined,
            label: '我的简历',
            onTap: () => context.push('/profile/resumes'),
          ),
          const Divider(height: 1, color: AppColors.line),
          _menuRow(
            icon: Icons.bookmark_border,
            label: '我的收藏',
            onTap: () => context.push('/profile/favorites'),
          ),
          const Divider(height: 1, color: AppColors.line),
          _menuRow(
            icon: Icons.my_location,
            label: '目标岗位',
            onTap: () => context.push('/interview/job-profile'),
          ),
          const Divider(height: 1, color: AppColors.line),
          _menuRow(
            icon: Icons.event_available_outlined,
            label: '打卡记录',
            onTap: () => context.push('/profile/checkin'),
          ),
          const Divider(height: 1, color: AppColors.line),
          _menuRow(
            icon: Icons.feedback_outlined,
            label: '我的反馈',
            badge: pendingFeedback,
            onTap: () => context
                .push('/profile/feedback')
                .then((_) => ref.invalidate(myFeedbackProvider)),
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _menuRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int badge = 0,
    bool last = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (badge > 0) ...[
              Container(
                constraints: const BoxConstraints(minWidth: 17),
                height: 17,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _logout(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: () async {
          await ref.read(authRepositoryProvider).logout();
          if (!context.mounted) return;
          context.go('/login');
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: Color(0x33DC3150)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          '退出登录',
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
