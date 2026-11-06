import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers.dart';
import '../../../shared/utils/toast.dart';
import '../data/interview_providers.dart';
import 'media_room_view.dart';

/// 模拟面试作答页。
///
/// 文字 / 语音 / 视频场次统一走对话式 `/interview/session/{id}/chat`：
/// 文字用输入框作答，语音/视频交由 [MediaRoomView] 的录音与 ASR/TTS 流程。
class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).track('interview_start', {
      'sessionId': widget.sessionId,
    });
  }

  Future<void> _abort() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提前结束本场面试？'),
        content: const Text('已作答的内容会保留，但本场不能再继续作答。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再想想'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '结束',
              style: TextStyle(
                color: AppColors.wine,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(interviewRepositoryProvider)
          .abortSession(widget.sessionId);
      ref.invalidate(sessionHistoryProvider);
      if (!mounted) return;
      showToast(context, '已提前结束本场面试');
      context.go('/interview');
    } catch (e) {
      if (mounted) showToast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionDetailProvider(widget.sessionId));
    final session = sessionAsync.asData?.value;
    final finished = session?.finished ?? false;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(
          session == null || session.jobName.isEmpty ? '模拟面试' : session.jobName,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          if (!finished)
            TextButton(
              onPressed: _abort,
              child: const Text(
                '提前结束',
                style: TextStyle(
                  color: AppColors.wine,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: sessionAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.blue),
        ),
        error: (e, _) => _errorView('$e'),
        data: (data) => MediaRoomView(session: data),
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
                onPressed: () =>
                    ref.invalidate(sessionDetailProvider(widget.sessionId)),
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
