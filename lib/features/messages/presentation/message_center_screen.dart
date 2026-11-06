import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../data/message_models.dart';
import '../data/message_providers.dart';

/// 消息中心：系统通知聚合卡 + 企业会话列表（全屏独立页，从「我的」进入）。
class MessageCenterScreen extends ConsumerWidget {
  const MessageCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(messageOverviewProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: const Text('消息中心', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.blue)),
        error: (error, _) => _errorView(ref, '$error'),
        data: (data) => RefreshIndicator(
          color: AppColors.blue,
          onRefresh: () async => ref.invalidate(messageOverviewProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              _systemCard(ref, context, data),
              const SizedBox(height: 22),
              const Text('企业会话', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 11),
              if (data.chats.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: Text('暂无企业会话\n投递后企业可主动联系你',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.7)),
                  ),
                )
              else
                for (final chat in data.chats) ...[
                  _chatCard(context, chat),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _systemCard(WidgetRef ref, BuildContext context, MessageOverview data) {
    final preview = data.systemPreview;
    return MlfCard(
      onTap: () => context
          .push('/profile/messages/system')
          .then((_) => ref.invalidate(messageOverviewProvider)),
      child: Row(
        children: [
          _avatar(icon: Icons.notifications_active_outlined, color: AppColors.wine),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('系统通知',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    if (data.systemUnread > 0) ...[
                      const SizedBox(width: 8),
                      _badge(data.systemUnread),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  preview == null || preview.title.isEmpty ? '暂无系统通知' : preview.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }

  Widget _chatCard(BuildContext context, ChatSummary chat) {
    return MlfCard(
      onTap: () => context.push('/profile/messages/chat/${chat.talentId}'),
      child: Row(
        children: [
          _avatar(icon: Icons.business_outlined, color: AppColors.blue),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat.tenantName.isEmpty ? '企业' : chat.tenantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (chat.lastTime.isNotEmpty)
                      Text(chat.lastTime, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                  ],
                ),
                if (chat.positionName.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(chat.positionName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.blue, fontSize: 11.5)),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat.lastContent.isEmpty
                            ? '开始聊天吧'
                            : '${chat.lastIsMine ? '我：' : ''}${chat.lastContent}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ),
                    if (chat.unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      _badge(chat.unreadCount),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar({required IconData icon, required Color color}) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _badge(int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 17),
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(9)),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _errorView(WidgetRef ref, String message) {
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
                onPressed: () => ref.invalidate(messageOverviewProvider),
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
}
