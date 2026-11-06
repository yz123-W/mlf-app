import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/cube_mark.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../data/home_models.dart';
import '../data/home_providers.dart';

/// 首页：积分概览 / 最近报告 / 岗位推荐接真实接口；运营位（实战热身等）保持本地 mock。
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(homeDashboardProvider);

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.blue,
        onRefresh: () async => ref.invalidate(homeDashboardProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            _topBar(context),
            const SizedBox(height: 6),
            _greeting(),
            const SizedBox(height: 14),
            dashboard.when(
              loading: _loadingBlocks,
              error: (error, _) => _errorBlock(ref, '$error'),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _pointsCard(data.points),
                  if (data.checkin != null) ...[
                    const SizedBox(height: 12),
                    _checkinStrip(context, data.checkin!),
                  ],
                  const SizedBox(height: 24),
                  _sectionTitle('实战热身'),
                  const SizedBox(height: 11),
                  _mockWarmup(context),
                  const SizedBox(height: 24),
                  _sectionTitle('最近报告'),
                  const SizedBox(height: 11),
                  _reportsBlock(context, data.reports),
                  const SizedBox(height: 24),
                  _sectionTitle('岗位推荐'),
                  const SizedBox(height: 11),
                  _jobsBlock(context, data.jobs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        const CubeMark(size: 38),
        const Spacer(),
        IconButton(
          onPressed: () => context.push('/profile/messages'),
          icon: const Icon(Icons.notifications_none, color: AppColors.blue),
        ),
      ],
    );
  }

  Widget _greeting() {
    return Row(
      children: const [
        CircleAvatar(
          radius: 25,
          backgroundColor: Color(0xFFDCE4FF),
          child: Icon(Icons.person, color: AppColors.blue),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hi，同学', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text('每一次开口，都离理想更近', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _loadingBlocks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 132,
          decoration: BoxDecoration(
            color: const Color(0x1A002B99),
            borderRadius: BorderRadius.circular(23),
          ),
          child: const Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.blue),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('正在加载你的成长数据…',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
      ],
    );
  }

  Widget _errorBlock(WidgetRef ref, String message) {
    return MlfCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('数据加载失败', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5)),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: FilledButton(
              onPressed: () => ref.invalidate(homeDashboardProvider),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('重新加载',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
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
              child: Text('积分数据暂不可用，稍后下拉刷新重试',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    final progress = (points.levelProgress.clamp(0, 100)) / 100.0;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: AppColors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _PointsBackdropPainter()),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('当前积分',
                              style: TextStyle(color: AppColors.muted, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text('${points.points}',
                              style: const TextStyle(
                                  color: AppColors.blue,
                                  fontFamily: 'serif',
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  height: 1)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.wineSoft,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: const Color(0xFFEAD3DA)),
                        ),
                        child: Text(points.level,
                            style: const TextStyle(
                                color: AppColors.wine,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFEDF0F7),
                      valueColor: const AlwaysStoppedAnimation(AppColors.blue),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    points.topLevel || points.nextLevel == null
                        ? '已达最高等级，继续保持'
                        : '距离「${points.nextLevel}」还差 ${points.pointsToNext} 分',
                    style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkinStrip(BuildContext context, CheckinSummary checkin) {
    return MlfCard(
      onTap: () => context.push('/profile/checkin'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: checkin.todayChecked ? const Color(0xFFDCF5E6) : const Color(0xFFE7EDFF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              checkin.todayChecked ? Icons.check_circle_outline : Icons.event_available_outlined,
              color: checkin.todayChecked ? AppColors.success : AppColors.blue,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checkin.todayChecked ? '今日已打卡' : '今日还未打卡',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '连续 ${checkin.continuousDays} 天 · 累计 ${checkin.totalDays} 天',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
        ],
      ),
    );
  }

  /// 实战热身（纯前端练习页，复用运营公共题库拉题池）。
  Widget _mockWarmup(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _warmCard(
            context,
            '1 分钟速答',
            '快速破冰 · 10 题',
            const Color(0xFFE3EBFF),
            AppColors.blue,
            onTap: () => context.push('/warmup/speed'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _warmCard(
            context,
            '即兴表达',
            '临场叙述 · 5 题',
            const Color(0xFFF7ECF0),
            AppColors.wine,
            onTap: () => context.push('/warmup/improv'),
          ),
        ),
      ],
    );
  }

  Widget _warmCard(
    BuildContext context,
    String title,
    String sub,
    Color bg,
    Color fg, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () => showToast(context, '开发阶段：实战热身以本地示例呈现'),
      child: Container(
        height: 83,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(17)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text(sub, style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _reportsBlock(BuildContext context, List<InterviewReportItem> reports) {
    if (reports.isEmpty) {
      return const _EmptyHint(icon: Icons.description_outlined, text: '还没有面试报告，完成一场模拟面试后就能看到复盘');
    }
    return MlfCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < reports.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.line),
            _reportRow(context, reports[i]),
          ],
        ],
      ),
    );
  }

  Widget _reportRow(BuildContext context, InterviewReportItem report) {
    final date = report.startTime;
    final timeText = date == null ? '时间未知' : DateFormat('yyyy-MM-dd HH:mm').format(date);
    return InkWell(
      onTap: () => context.push('/result/${report.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE7EDFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.assignment_outlined, color: AppColors.blue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(report.jobName.isEmpty ? '模拟面试' : report.jobName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(timeText, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              report.totalScore == null ? '-' : '${report.totalScore!.toStringAsFixed(1)} 分',
              style: const TextStyle(color: AppColors.wine, fontSize: 15, fontWeight: FontWeight.w900),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _jobsBlock(BuildContext context, List<JobItem> jobs) {
    if (jobs.isEmpty) {
      return const _EmptyHint(icon: Icons.work_outline, text: '暂无在招岗位，稍后再来看看');
    }
    return Column(
      children: [
        for (final job in jobs) ...[
          _jobCard(context, job),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _jobCard(BuildContext context, JobItem job) {
    return MlfCard(
      onTap: () => context.push('/jobs/${job.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(job.jobName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              if (job.applied)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCF5E6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('已投递',
                      style: TextStyle(color: AppColors.success, fontSize: 10.5, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [job.tenantName, job.workLocation].where((e) => e.isNotEmpty).join(' · '),
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              if (job.industry.isNotEmpty) _tag(job.industry),
              if (job.recruitCount != null) ...[
                const SizedBox(width: 8),
                _tag('招 ${job.recruitCount} 人'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EDFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: const TextStyle(color: AppColors.blue, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800));
  }
}

/// 空态提示。
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return MlfCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(icon, color: AppColors.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

/// 积分卡的极淡蓝色几何底纹：斜向细线 + 右上角同心圆环。
class _PointsBackdropPainter extends CustomPainter {
  const _PointsBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final hairline = Paint()
      ..color = const Color(0x0A002B99)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 11) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), hairline);
    }

    final center = Offset(size.width + 8, -26);
    canvas.drawCircle(
      center,
      74,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x1A002B99),
    );
    canvas.drawCircle(
      center,
      96,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x0D002B99),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
