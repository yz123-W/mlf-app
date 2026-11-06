import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../data/feedback_models.dart';
import '../data/feedback_providers.dart';

/// 我的反馈：提交反馈 + 反馈记录（对齐学生端 Web 的 FeedbackDialog）。
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _content = TextEditingController();
  bool _submitting = false;
  int? _expandedId;

  @override
  void dispose() {
    _tabs.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _content.text.trim();
    if (content.isEmpty) {
      showToast(context, '请填写反馈内容');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(feedbackApiProvider).submit(content: content);
      if (!mounted) return;
      _content.clear();
      setState(() => _expandedId = null);
      ref.invalidate(myFeedbackProvider);
      showToast(context, '反馈已提交，感谢你的建议');
      _tabs.animateTo(1);
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items =
        ref.watch(myFeedbackProvider).asData?.value ?? const <FeedbackItem>[];
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: const Text(
          '我的反馈',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.blue,
          unselectedLabelColor: AppColors.muted,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: AppColors.wine,
          indicatorWeight: 2,
          tabs: [
            const Tab(text: '提交反馈'),
            Tab(text: items.isEmpty ? '反馈记录' : '反馈记录 (${items.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_submitTab(), _recordsTab()],
      ),
    );
  }

  // ------------------------------------------------------------------ 提交

  Widget _submitTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        const Text(
          '遇到的问题或建议',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: TextField(
            controller: _content,
            maxLines: 6,
            maxLength: 500,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.ink,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '说说你遇到的问题或建议，我们会认真处理',
              hintStyle: TextStyle(
                color: AppColors.muted,
                fontSize: 13.5,
                height: 1.6,
              ),
              counterStyle: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '每天最多提交 5 条反馈；已处理的反馈可在「反馈记录」中查看结果。',
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.7),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: _submitting ? null : AppColors.primaryButton,
              color: _submitting ? AppColors.muted : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _submitting ? null : _submit,
                child: Center(
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '提交反馈',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ 记录

  Widget _recordsTab() {
    final async = ref.watch(myFeedbackProvider);
    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.blue)),
      error: (e, _) => _errorView('$e'),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                '还没有反馈记录\n遇到问题欢迎随时告诉我们',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.7,
                ),
              ),
            ),
          );
        }
        return RefreshIndicator(
          color: AppColors.blue,
          onRefresh: () => ref.refresh(myFeedbackProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _recordCard(items[index]),
          ),
        );
      },
    );
  }

  Widget _recordCard(FeedbackItem item) {
    final expanded = _expandedId == item.id;
    return MlfCard(
      onTap: item.isResolved
          ? () => setState(() => _expandedId = expanded ? null : item.id)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusChip(item.status),
              const Spacer(),
              Text(
                item.submitTime,
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.content,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.7,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          if (item.isPending)
            const Text(
              '运营人员处理后会在这里显示结果',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            )
          else if (expanded) ...[
            const Text(
              '处理结果',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.handleRemark.isEmpty ? '（处理人未填写备注）' : item.handleRemark,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.7,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              [
                item.handleBy,
                item.handleTime,
              ].where((e) => e.isNotEmpty).join(' · '),
              style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
            ),
          ] else
            Text(
              '查看处理结果',
              style: const TextStyle(
                color: AppColors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    late final Color fg;
    late final Color bg;
    switch (status) {
      case '已解决':
        fg = AppColors.success;
        bg = AppColors.mint.withValues(alpha: .5);
        break;
      case '已忽略':
        fg = AppColors.muted;
        bg = const Color(0x1416203B);
        break;
      default:
        fg = const Color(0xFFB26B12);
        bg = const Color(0x1FFFB36B);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.isEmpty ? '待处理' : status,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.muted,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
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
                onPressed: () => ref.invalidate(myFeedbackProvider),
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
      ),
    );
  }
}
