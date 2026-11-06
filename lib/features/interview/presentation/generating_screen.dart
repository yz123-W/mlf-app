import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/async/polling_controller.dart';
import '../../../shared/widgets/cube_mark.dart';
import '../data/interview_providers.dart';

/// 出题过渡页：轮询后端 `generate-status`，就绪后进入作答。
///
/// 轮询间隔 1.5s，最长等待 180s；失败或超时展示原因并允许返回。
class GeneratingScreen extends ConsumerStatefulWidget {
  const GeneratingScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends ConsumerState<GeneratingScreen> {
  static const List<String> _steps = [
    '正在解析目标岗位要求…',
    '正在匹配题库与简历要点…',
    '正在生成面试题目与要点…',
  ];
  static const Duration _pollInterval = Duration(milliseconds: 1500);
  static const int _timeoutSeconds = 180;

  late final PollingController _controller;
  DateTime _startedAt = DateTime.now();
  int _elapsed = 0;
  int _questionCount = 0;
  bool _finished = false;
  String? _failMessage;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _controller = PollingController(
      interval: _pollInterval,
      timeout: const Duration(seconds: _timeoutSeconds),
      onTick: _poll,
      onTimeout: () => _fail('题目生成超时，请返回后重新发起'),
    )..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_finished) return;
    final status = await ref
        .read(interviewRepositoryProvider)
        .generateStatus(widget.sessionId, cancelToken: _controller.cancelToken);
    if (!mounted || _finished) return;
    setState(() => _elapsed = DateTime.now().difference(_startedAt).inSeconds);
    if (status.ready) {
      _finished = true;
      _controller.stop();
      setState(() => _questionCount = status.questionCount);
      context.pushReplacement('/room/${widget.sessionId}');
    } else if (status.failed) {
      _fail(status.message.isEmpty ? '题目生成失败，请稍后重试' : status.message);
    }
  }

  void _fail(String message) {
    if (_finished) return;
    _finished = true;
    _controller.stop();
    if (mounted) setState(() => _failMessage = message);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/interview');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44),
            child: _failMessage == null ? _loading() : _failed(),
          ),
        ),
      ),
    );
  }

  Widget _loading() {
    final step = (_elapsed ~/ 5).clamp(0, _steps.length - 1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CubeMark(size: 84),
        const SizedBox(height: 30),
        const Text(
          'AI 正在为你组卷…',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _steps[step],
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 26),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: const LinearProgressIndicator(
            minHeight: 8,
            backgroundColor: Color(0xFFEDF0F7),
            valueColor: AlwaysStoppedAnimation(AppColors.blue),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _questionCount > 0
              ? '已生成 $_questionCount 题，即将开始…'
              : '已等待 $_elapsed 秒，通常 10-30 秒完成',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _failed() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: AppColors.blue, size: 56),
        const SizedBox(height: 20),
        const Text(
          '组卷未完成',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _failMessage ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 26),
        SizedBox(
          width: 160,
          height: 44,
          child: FilledButton(
            onPressed: _back,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '返回重试',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}
