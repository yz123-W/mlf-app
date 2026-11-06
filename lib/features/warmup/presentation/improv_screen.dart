import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../features/questions/data/questions_models.dart';
import '../../../features/questions/data/questions_providers.dart';
import '../../../shared/utils/toast.dart';

/// 即兴表达训练（实战热身 · 1/2）。
///
/// 纯前端练习页，不落库：从运营公共题库（`/interview/bank/list`）随机抽题 →
/// 30 秒准备 → 3 分钟作答 → 对照题库参考答案自查。
class ImprovScreen extends ConsumerStatefulWidget {
  const ImprovScreen({super.key});

  @override
  ConsumerState<ImprovScreen> createState() => _ImprovScreenState();
}

enum _ImprovStage { ready, preparing, answering, review }

class _ImprovScreenState extends ConsumerState<ImprovScreen> {
  static const _poolSize = 50;
  static const _prepareSec = 30;
  static const _answerSec = 180;

  _ImprovStage _stage = _ImprovStage.ready;
  bool _loading = false;
  QuestionItem? _question;
  final _answer = TextEditingController();
  int _remain = _prepareSec;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _answer.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    _timer?.cancel();
    setState(() => _loading = true);
    try {
      final page = await ref
          .read(questionsRepositoryProvider)
          .list(pageNum: 1, pageSize: _poolSize);
      final pool = page.items
          .where((e) => e.content.trim().isNotEmpty)
          .toList();
      if (pool.isEmpty) {
        if (mounted) showToast(context, '题库暂无可用于训练的题目，请稍后再试');
        return;
      }
      setState(() {
        _question = _pick(pool, _question?.id);
        _answer.text = '';
        _stage = _ImprovStage.preparing;
        _remain = _prepareSec;
      });
      _countdown(_prepareSec, _beginAnswer);
    } catch (e) {
      if (mounted) showToast(context, '加载题目失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  QuestionItem _pick(List<QuestionItem> pool, int? excludeId) {
    final candidates = excludeId == null
        ? pool
        : pool.where((e) => e.id != excludeId).toList();
    final src = candidates.isNotEmpty ? candidates : pool;
    return (src..shuffle()).first;
  }

  void _countdown(int seconds, VoidCallback onEnd) {
    _timer?.cancel();
    setState(() => _remain = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _remain -= 1;
        if (_remain <= 0) {
          _remain = 0;
          t.cancel();
          onEnd();
        }
      });
    });
  }

  void _beginAnswer() {
    if (!mounted) return;
    setState(() => _stage = _ImprovStage.answering);
    _countdown(_answerSec, _submit);
  }

  void _submit() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _stage = _ImprovStage.review);
  }

  void _goHome() {
    _timer?.cancel();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: _goHome,
        ),
        title: const Text('即兴表达训练',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    switch (_stage) {
      case _ImprovStage.ready:
        return _ReadyView(onStart: _start, loading: _loading);
      case _ImprovStage.preparing:
      case _ImprovStage.answering:
        return _WorkingView(
          stage: _stage,
          question: _question,
          answer: _answer,
          remain: _remain,
          onGoHome: _goHome,
          onBegin: _beginAnswer,
          onSubmit: _submit,
        );
      case _ImprovStage.review:
        return _ReviewView(
          question: _question,
          answer: _answer.text,
          onRestart: _start,
          onGoHome: _goHome,
        );
    }
  }
}

typedef QuestionItem = Question;

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.onStart, required this.loading});
  final VoidCallback onStart;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            color: AppColors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic_none, size: 40, color: AppColors.wine),
                  const SizedBox(height: 10),
                  const Text('即兴表达训练',
                      style: TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 14),
                  Text(
                    '随机抽题，30 秒准备、3 分钟作答，练的是「拿到题就能开口」的即兴表达力。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13.5, color: AppColors.ink.withValues(alpha: 0.72), height: 1.7),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('训练规则',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
                  ),
                  const SizedBox(height: 8),
                  for (final r in const [
                    '抽题后进入 30 秒准备时间，可提前开始作答',
                    '作答限时 3 分钟，时间到自动提交',
                    '提交后对照题库参考答案，自查表达是否到位',
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 8, right: 10),
                            child: CircleAvatar(radius: 3, backgroundColor: AppColors.blue),
                          ),
                          Expanded(child: Text(r, style: const TextStyle(fontSize: 13, height: 1.7))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: loading ? null : onStart,
                      child: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('随机抽题',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkingView extends StatelessWidget {
  const _WorkingView({
    required this.stage,
    required this.question,
    required this.answer,
    required this.remain,
    required this.onGoHome,
    required this.onBegin,
    required this.onSubmit,
  });
  final _ImprovStage stage;
  final Question? question;
  final TextEditingController answer;
  final int remain;
  final VoidCallback onGoHome;
  final VoidCallback onBegin;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final q = question;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _phase(),
          const SizedBox(height: 14),
          _countdown(),
          const SizedBox(height: 16),
          if (q != null) _questionCard(q),
          const SizedBox(height: 16),
          TextField(
            controller: answer,
            maxLines: 8,
            enabled: stage != _ImprovStage.preparing,
            style: const TextStyle(fontSize: 14, height: 1.7),
            decoration: InputDecoration(
              hintText: stage == _ImprovStage.preparing
                  ? '准备阶段先在心里打草稿，30 秒后开始作答…'
                  : '开始你的即兴表达…',
              hintStyle: const TextStyle(color: AppColors.muted),
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.line),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.muted,
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: onGoHome,
                  child: const Text('退出训练', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: stage == _ImprovStage.preparing ? AppColors.blue : AppColors.wine,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: stage == _ImprovStage.preparing ? onBegin : onSubmit,
                  child: Text(
                    stage == _ImprovStage.preparing ? '提前开始作答' : '提交作答',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _phase() {
    final isPrep = stage == _ImprovStage.preparing;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isPrep ? AppColors.orange.withValues(alpha: 0.22) : AppColors.mint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isPrep ? '准备中' : '作答中',
            style: TextStyle(
                color: isPrep ? const Color(0xFFB86500) : AppColors.success,
                fontWeight: FontWeight.w800,
                fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _countdown() {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('$remain',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: remain <= 10 ? AppColors.danger : AppColors.blue,
                  height: 1)),
          const SizedBox(width: 4),
          const Text('秒', style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _questionCard(Question q) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: AppColors.blue, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (q.type.isNotEmpty) _tag(q.type, AppColors.blue),
              const SizedBox(width: 6),
              if (q.difficulty.isNotEmpty) _tag(q.difficulty, Colors.grey),
            ],
          ),
          const SizedBox(height: 8),
          Text(q.content,
              style: const TextStyle(fontSize: 15, height: 1.7, color: AppColors.ink)),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Text(text,
          style: TextStyle(
              fontSize: 11.5, color: color, fontWeight: FontWeight.w700)));
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({
    required this.question,
    required this.answer,
    required this.onRestart,
    required this.onGoHome,
  });
  final Question? question;
  final String answer;
  final VoidCallback onRestart;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final q = question;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (q != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: AppColors.blue, width: 3)),
              ),
              child: Text(q.content,
                  style: const TextStyle(fontSize: 15, height: 1.7, color: AppColors.ink)),
            ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _col('你的表达', answer.trim().isEmpty ? '（未作答）' : answer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _col(
                  '参考答案',
                  (q?.answer?.trim() ?? '题库暂未提供参考答案'),
                  highlight: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onRestart,
                  child: const Text('换一题再来',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onGoHome,
                  child: const Text('返回首页'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _col(String title, String body, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? AppColors.mint.withValues(alpha: 0.55) : AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.muted)),
          const SizedBox(height: 8),
          Text(body,
              style: const TextStyle(fontSize: 13, height: 1.75, color: AppColors.ink),
              softWrap: true),
        ],
      ),
    );
  }
}
