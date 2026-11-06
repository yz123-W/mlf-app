import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_colors.dart';
import '../../../features/questions/data/questions_models.dart';
import '../../../features/questions/data/questions_providers.dart';
import '../../../shared/utils/toast.dart';

/// 1 分钟速答挑战（实战热身 · 2/2）。
///
/// 纯前端练习页，不落库、不产生场次/报告；从公共题库拉 20 道题前端洗牌，
/// 历史最佳写入 `SharedPreferences`（仅本机可见）。
class SpeedScreen extends ConsumerStatefulWidget {
  const SpeedScreen({super.key});

  @override
  ConsumerState<SpeedScreen> createState() => _SpeedScreenState();
}

enum _SpeedStage { ready, running, done }

const kSpeedBestKey = 'interview_warmup_speed_best';

class _SpeedScreenState extends ConsumerState<SpeedScreen> {
  static const _poolSize = 20;
  static const _limitSec = 60;

  _SpeedStage _stage = _SpeedStage.ready;
  bool _loading = false;
  List<Question> _questions = const [];
  int _index = 0;
  final _answer = TextEditingController();
  int _answered = 0;
  int _remain = _limitSec;
  int _best = 0;
  bool _isNewRecord = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadBest();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _answer.dispose();
    super.dispose();
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    final best = prefs.getInt(kSpeedBestKey) ?? 0;
    if (mounted) setState(() => _best = best);
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
          .toList()
        ..shuffle();
      if (pool.isEmpty) {
        if (mounted) showToast(context, '题库暂无可用于速答的题目，请稍后再试');
        return;
      }
      setState(() {
        _questions = pool;
        _index = 0;
        _answer.text = '';
        _answered = 0;
        _remain = _limitSec;
        _isNewRecord = false;
        _stage = _SpeedStage.running;
      });
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
            _finish();
          }
        });
      });
    } catch (e) {
      if (mounted) showToast(context, '加载题目失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _flushCurrentAnswer() {
    if (_answer.text.trim().isNotEmpty) _answered += 1;
    _answer.text = '';
  }

  void _next() {
    _flushCurrentAnswer();
    if (_index >= _questions.length - 1) {
      _finish();
      return;
    }
    setState(() => _index += 1);
  }

  void _finish() {
    _timer?.cancel();
    _flushCurrentAnswer();
    setState(() {
      _stage = _SpeedStage.done;
      if (_answered > _best) {
        _best = _answered;
        _isNewRecord = true;
        SharedPreferences.getInstance().then((p) => p.setInt(kSpeedBestKey, _answered));
      }
    });
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
        title: const Text('1 分钟速答挑战',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: SafeArea(
          child: switch (_stage) {
        _SpeedStage.ready => _ReadyView(
            loading: _loading,
            best: _best,
            totalHint: _poolSize,
            onStart: _start,
          ),
        _SpeedStage.running => _RunningView(
            total: _questions.length,
            index: _index,
            answered: _answered,
            remain: _remain,
            question: _questions[_index],
            answer: _answer,
            onNext: _next,
            onFinish: _finish,
          ),
        _SpeedStage.done => _DoneView(
            answered: _answered,
            best: _best,
            isNewRecord: _isNewRecord,
            onRestart: _start,
            onGoHome: _goHome,
          ),
      }),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView(
      {required this.loading,
      required this.best,
      required this.totalHint,
      required this.onStart});
  final bool loading;
  final int best;
  final int totalHint;
  final VoidCallback onStart;

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
                  const Icon(Icons.timer, size: 40, color: AppColors.blue),
                  const SizedBox(height: 10),
                  const Text('1 分钟速答挑战',
                      style: TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 14),
                  Text(
                    '60 秒内尽可能多地完成面试快问快答，锻炼临场反应与要点表达。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13.5, color: AppColors.ink.withValues(alpha: 0.72), height: 1.7),
                  ),
                  const SizedBox(height: 16),
                  for (final r in [
                    '限时 60 秒，时间到自动结算',
                    '题目随机抽取，一次性准备 $totalHint 道题',
                    '只统计答完的题数，不落库，可以放心反复练',
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
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('历史最佳',
                          style: TextStyle(fontSize: 13, color: AppColors.muted)),
                      const SizedBox(width: 6),
                      Text('$best 题',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB86500))),
                    ],
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
                          : const Text('开始挑战',
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

class _RunningView extends StatelessWidget {
  const _RunningView({
    required this.total,
    required this.index,
    required this.answered,
    required this.remain,
    required this.question,
    required this.answer,
    required this.onNext,
    required this.onFinish,
  });
  final int total;
  final int index;
  final int answered;
  final int remain;
  final Question question;
  final TextEditingController answer;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final progress = remain.clamp(0, 60) / 60;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$remain',
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: remain <= 10 ? AppColors.danger : AppColors.blue,
                      height: 1)),
              const SizedBox(width: 4),
              const Text('秒', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: AppColors.line,
              valueColor: AlwaysStoppedAnimation(
                  remain <= 10 ? AppColors.danger : AppColors.blue),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('第 ${index + 1} / $total 题',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              Text('已答 $answered 题',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
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
                    if (question.type.isNotEmpty) _tag(question.type),
                    const SizedBox(width: 6),
                    if (question.difficulty.isNotEmpty) _tag(question.difficulty),
                  ],
                ),
                const SizedBox(height: 8),
                Text(question.content,
                    style: const TextStyle(fontSize: 15, height: 1.7, color: AppColors.ink)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: answer,
            maxLines: 5,
            style: const TextStyle(fontSize: 14, height: 1.65),
            decoration: InputDecoration(
              hintText: '用要点式短句快速作答，答完点「下一题」继续',
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
                  onPressed: onFinish,
                  child: const Text('结束挑战', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: onNext,
                  child: const Text('下一题',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.blue.withValues(alpha: 0.22))),
      child: Text(text,
          style: TextStyle(
              fontSize: 11.5,
              color: AppColors.blue,
              fontWeight: FontWeight.w700)));
}

class _DoneView extends StatelessWidget {
  const _DoneView(
      {required this.answered,
      required this.best,
      required this.isNewRecord,
      required this.onRestart,
      required this.onGoHome});
  final int answered;
  final int best;
  final bool isNewRecord;
  final VoidCallback onRestart;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 56, color: Color(0xFFB86500)),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.ink, fontWeight: FontWeight.w700),
                  children: [
                    const TextSpan(text: '本轮完成 '),
                    TextSpan(
                        text: '$answered',
                        style: const TextStyle(
                            fontSize: 38, fontWeight: FontWeight.w900, color: AppColors.blue)),
                    const TextSpan(text: ' 题'),
                  ]),
            ),
            if (isNewRecord) ...[
              const SizedBox(height: 10),
              const Text('🎉 刷新了历史最佳纪录',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFB86500),
                      fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 8),
            Text('历史最佳：$best 题',
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onRestart,
                    child: const Text('再来一轮',
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
      ),
    );
  }
}
