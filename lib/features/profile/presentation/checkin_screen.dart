import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../../home/data/home_models.dart';
import '../../home/data/home_providers.dart';

/// 打卡记录：概览 + 近 30 天日历。
class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  bool _busy = false;

  Future<void> _checkin() async {
    setState(() => _busy = true);
    try {
      await ref.read(homeApiProvider).checkin();
      ref.invalidate(checkinSummaryProvider);
      ref.invalidate(homeDashboardProvider);
      if (mounted) showToast(context, '打卡成功');
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(checkinSummaryProvider);
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: const Text('打卡记录', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.blue)),
        error: (error, _) => _errorBlock('$error'),
        data: (data) => RefreshIndicator(
          color: AppColors.blue,
          onRefresh: () async => ref.invalidate(checkinSummaryProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              _overview(data),
              const SizedBox(height: 18),
              _calendar(data),
              const SizedBox(height: 16),
              const Text(
                '每日打卡可获得成长积分，连续打卡额外加成。',
                style: TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overview(CheckinSummary data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available, color: AppColors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                data.todayChecked ? '今日已打卡' : '今日还未打卡',
                style: const TextStyle(
                    color: AppColors.ink, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _metric('连续打卡', '${data.continuousDays}', '天'),
              const SizedBox(width: 40),
              _metric('累计打卡', '${data.totalDays}', '天'),
            ],
          ),
          if (!data.todayChecked) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton(
                onPressed: _busy ? null : _checkin,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_busy ? '打卡中…' : '立即打卡',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
                style: const TextStyle(
                    fontFamily: 'serif',
                    color: AppColors.blue,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1)),
            Padding(
              padding: const EdgeInsets.only(bottom: 3, left: 3),
              child: Text(unit, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _calendar(CheckinSummary data) {
    final checked = data.recentDays.toSet();
    final today = DateTime.now();
    final days = List.generate(30, (i) {
      final date = DateTime(today.year, today.month, today.day - (29 - i));
      return date;
    });

    return MlfCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('近 30 天打卡',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('已打卡 ${data.recentDays.length} 天',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
            children: days.map((date) {
              final key = DateFormat('yyyy-MM-dd').format(date);
              final isChecked = checked.contains(key);
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isChecked ? AppColors.blue : const Color(0x0F002B99),
                  borderRadius: BorderRadius.circular(9),
                  border: isToday ? Border.all(color: AppColors.wine, width: 1.5) : null,
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    color: isChecked ? Colors.white : AppColors.muted,
                    fontSize: 11.5,
                    fontWeight: isChecked ? FontWeight.w800 : FontWeight.w400,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _legend(AppColors.blue, '已打卡'),
              const SizedBox(width: 16),
              _legend(const Color(0x0F002B99), '未打卡'),
              const SizedBox(width: 16),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: AppColors.wine, width: 1.5),
                ),
              ),
              const SizedBox(width: 4),
              const Text('今天', style: TextStyle(color: AppColors.muted, fontSize: 10.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
      ],
    );
  }

  Widget _errorBlock(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.6)),
            const SizedBox(height: 16),
            SizedBox(
              height: 42,
              child: FilledButton(
                onPressed: () => ref.invalidate(checkinSummaryProvider),
                style: FilledButton.styleFrom(backgroundColor: AppColors.blue),
                child: const Text('重新加载',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
