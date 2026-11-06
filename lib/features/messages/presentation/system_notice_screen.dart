import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../data/message_models.dart';
import '../data/message_providers.dart';

/// 系统通知明细：列表 + 单条已读 + 全部已读 + 「去处理」跳邀约。
class SystemNoticeScreen extends ConsumerStatefulWidget {
  const SystemNoticeScreen({super.key});

  @override
  ConsumerState<SystemNoticeScreen> createState() => _SystemNoticeScreenState();
}

class _SystemNoticeScreenState extends ConsumerState<SystemNoticeScreen> {
  bool _loading = true;
  String? _error;
  bool _markingAll = false;
  List<SystemMessage> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (rows, _) = await ref.read(messageRepositoryProvider).systemList();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _readOne(SystemMessage item) async {
    if (item.isRead) return;
    setState(() {
      _items = _items.map((e) => e.id == item.id ? e.copyWith(isRead: true) : e).toList();
    });
    try {
      await ref.read(messageRepositoryProvider).readSystem(msgType: item.type, refId: item.id);
      ref.invalidate(messageOverviewProvider);
    } catch (_) {
      // 已读失败不打断浏览，静默处理
    }
  }

  Future<void> _readAll() async {
    setState(() => _markingAll = true);
    try {
      await ref.read(messageRepositoryProvider).readAllSystem();
      if (!mounted) return;
      setState(() => _items = _items.map((e) => e.copyWith(isRead: true)).toList());
      ref.invalidate(messageOverviewProvider);
      showToast(context, '已全部标为已读');
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _items.any((e) => !e.isRead);
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: const Text('系统通知', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markingAll ? null : _readAll,
              child: const Text('全部已读',
                  style: TextStyle(color: AppColors.blue, fontSize: 13, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, color: AppColors.muted, size: 34),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5)),
              const SizedBox(height: 14),
              SizedBox(
                height: 42,
                child: FilledButton(
                  onPressed: _load,
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
    if (_items.isEmpty) {
      return const Center(
        child: Text('暂无系统通知', style: TextStyle(color: AppColors.muted, fontSize: 13)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _card(_items[index]),
    );
  }

  Widget _card(SystemMessage item) {
    return MlfCard(
      onTap: () => _readOne(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _typeTag(item),
              const SizedBox(width: 8),
              if (!item.isRead)
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle)),
              const Spacer(),
              if (item.createTime != null)
                Text(DateFormat('MM-dd HH:mm').format(item.createTime!),
                    style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            item.title.isEmpty ? '系统通知' : item.title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          if (item.content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.content, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.6)),
          ],
          if (item.type == 'invite') ...[
            const SizedBox(height: 11),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () async {
                  await _readOne(item);
                  if (!mounted) return;
                  context.push('/jobs/invites');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryButton,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Text('去处理',
                      style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _typeTag(SystemMessage item) {
    final isInvite = item.type == 'invite';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isInvite ? const Color(0xFFFFE4D8) : const Color(0xFFE7EDFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isInvite ? '面试邀约' : '通知',
        style: TextStyle(
          color: isInvite ? AppColors.wine : AppColors.blue,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
