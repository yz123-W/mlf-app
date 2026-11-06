import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../data/questions_models.dart';
import '../data/questions_providers.dart';

/// 题目详情：题目正文 + 考核维度 + 参考答案 + 追问预设。
///
/// 收藏状态由 `/interview/favorite/*` 持久化；「文字作答」需结合场次，属 M3。
class QuestionDetailScreen extends ConsumerStatefulWidget {
  const QuestionDetailScreen({super.key, required this.questionId});

  final int questionId;

  @override
  ConsumerState<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends ConsumerState<QuestionDetailScreen> {
  Future<void> _toggleFavorite() async {
    final favorited = ref
            .read(favoriteIdsProvider)
            .asData
            ?.value
            .contains(widget.questionId) ??
        false;
    try {
      await ref.read(favoriteIdsProvider.notifier).toggle(widget.questionId);
      if (!mounted) return;
      showToast(context, favorited ? '已取消收藏' : '已收藏');
    } catch (_) {
      if (!mounted) return;
      showToast(context, '操作失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(questionDetailProvider(widget.questionId));
    final favorited = ref
            .watch(favoriteIdsProvider)
            .asData
            ?.value
            .contains(widget.questionId) ??
        false;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('题目详情', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            tooltip: '收藏',
            onPressed: _toggleFavorite,
            icon: Icon(
              favorited ? Icons.bookmark : Icons.bookmark_border,
              color: favorited ? AppColors.wine : AppColors.blue,
            ),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.blue)),
        error: (error, _) => _errorView('$error'),
        data: _content,
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
            const Icon(Icons.cloud_off_outlined, color: AppColors.muted, size: 34),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5)),
            const SizedBox(height: 14),
            SizedBox(
              height: 42,
              child: FilledButton(
                onPressed: () => ref.invalidate(questionDetailProvider(widget.questionId)),
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
      ),
    );
  }

  Widget _content(Question question) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            if (question.type.isNotEmpty) _pill(question.type, AppColors.blue, const Color(0xFFE7EDFF)),
            if (question.difficulty.isNotEmpty) _pill(question.difficulty, AppColors.wine, const Color(0xFFFFE4D8)),
            if (question.industry.isNotEmpty) _pill(question.industry, AppColors.ink, const Color(0x0F002B99)),
          ],
        ),
        const SizedBox(height: 14),
        MlfCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _SectionTitle('题目'),
                  const Spacer(),
                  if (question.questionNo.isNotEmpty)
                    Text(question.questionNo,
                        style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 12),
              Text(question.content,
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.7)),
            ],
          ),
        ),
        if (question.dimensionTags.isNotEmpty) ...[
          const SizedBox(height: 14),
          MlfCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('考核维度'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: question.dimensionTags
                      .map((tag) => _pill(tag, AppColors.success, const Color(0xFFDCF5E6)))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
        if (question.skillNames.isNotEmpty) ...[
          const SizedBox(height: 14),
          MlfCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('考点'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: question.skillNames
                      .map((tag) => _pill(tag, AppColors.blue, const Color(0xFFE7EDFF)))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        MlfCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.lightbulb_outline, size: 18, color: AppColors.wine),
                  SizedBox(width: 6),
                  _SectionTitle('参考答案'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                question.answer?.trim().isNotEmpty == true ? question.answer! : '该题暂未配置参考答案',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.8,
                  color: question.answer?.trim().isNotEmpty == true ? AppColors.ink : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        if (question.followup?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 14),
          MlfCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.forum_outlined, size: 18, color: AppColors.blue),
                    SizedBox(width: 6),
                    _SectionTitle('可能的追问'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(question.followup!,
                    style: const TextStyle(fontSize: 14, height: 1.8, color: AppColors.ink)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        MlfPrimaryButton(
          label: '开始答题',
          onPressed: () => showToast(context, '开发阶段：结合场次的文字作答将在 M3 接入'),
        ),
      ],
    );
  }

  Widget _pill(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800));
  }
}
