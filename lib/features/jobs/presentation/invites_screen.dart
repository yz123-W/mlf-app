import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../data/jobs_models.dart';
import '../data/jobs_providers.dart';

/// 面试邀约：分页列表 + 接受 / 拒绝 + 进入面试间 / 查看报告。
class InvitesScreen extends ConsumerStatefulWidget {
  const InvitesScreen({super.key});

  @override
  ConsumerState<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends ConsumerState<InvitesScreen> {
  static const int _pageSize = 10;

  final _scroll = ScrollController();
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  final List<InviteItem> _items = [];
  final Set<int> _acting = {};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (!reset && !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _hasMore = true;
        _items.clear();
      }
    });
    try {
      final (rows, total) = await ref
          .read(jobsRepositoryProvider)
          .inviteList(pageNum: _page, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(rows);
        _hasMore = _items.length < total;
        _page += 1;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handle(InviteItem item, {required bool accept}) async {
    setState(() => _acting.add(item.id));
    try {
      final repo = ref.read(jobsRepositoryProvider);
      if (accept) {
        await repo.acceptInvite(item.id);
      } else {
        await repo.rejectInvite(item.id);
      }
      if (!mounted) return;
      setState(() {
        final index = _items.indexWhere((e) => e.id == item.id);
        if (index >= 0)
          _items[index] = _copyWithStatus(
            item,
            accept ? 'accepted' : 'rejected',
          );
      });
      showToast(context, accept ? '已接受邀约' : '已拒绝邀约');
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _acting.remove(item.id));
    }
  }

  /// 本地乐观更新状态（后端未回显新对象）。
  InviteItem _copyWithStatus(InviteItem item, String status) => InviteItem(
    id: item.id,
    jobId: item.jobId,
    jobNameSnapshot: item.jobNameSnapshot,
    inviteType: item.inviteType,
    questionNames: item.questionNames,
    meetingUrl: item.meetingUrl,
    questionTypes: item.questionTypes,
    scheduledTime: item.scheduledTime,
    expireTime: item.expireTime,
    attemptNo: item.attemptNo,
    status: status,
    tenantName: item.tenantName,
    sessionId: item.sessionId,
    reportId: item.reportId,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: const Text(
          '面试邀约',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_items.isEmpty && _loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blue),
      );
    }
    if (_items.isEmpty && _error != null) {
      return _errorView(_error!);
    }
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            '暂时没有面试邀约\n企业查看简历后可能会向你发出邀约',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.7),
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.blue,
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        itemCount: _items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _items.length) return _footer();
          return _card(_items[index]);
        },
      ),
    );
  }

  Widget _footer() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.blue,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          _error != null ? '加载失败，下拉重试' : '没有更多邀约了',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ),
    );
  }

  Widget _card(InviteItem item) {
    return MlfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.jobNameSnapshot.isEmpty ? '面试邀约' : item.jobNameSnapshot,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(item),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _pill(item.typeText, AppColors.blue, const Color(0xFFE7EDFF)),
              if (item.tenantName.isNotEmpty)
                _pill(item.tenantName, AppColors.ink, const Color(0x0F002B99)),
            ],
          ),
          if (item.questionNames.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              '题目：${item.questionNames}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          if (item.scheduledTime != null) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: AppColors.muted),
                const SizedBox(width: 5),
                Text(
                  '面试时间 ${DateFormat('yyyy-MM-dd HH:mm').format(item.scheduledTime!)}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _actions(item),
        ],
      ),
    );
  }

  Widget _actions(InviteItem item) {
    final busy = _acting.contains(item.id);
    if (item.isPending) {
      return Row(
        children: [
          Expanded(
            child: _outlineButton(
              label: '拒绝',
              color: AppColors.muted,
              busy: busy,
              onTap: () => _handle(item, accept: false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _filledButton(
              label: '接受',
              busy: busy,
              onTap: () => _handle(item, accept: true),
            ),
          ),
        ],
      );
    }
    if (item.isAccepted) {
      return Row(
        children: [
          if (item.sessionId != null)
            Expanded(
              child: _filledButton(
                label: '进入面试间',
                busy: false,
                onTap: () => context.push('/room/${item.sessionId}'),
              ),
            ),
          if (item.sessionId != null && item.reportId != null)
            const SizedBox(width: 10),
          if (item.reportId != null)
            Expanded(
              child: _outlineButton(
                label: '查看报告',
                color: AppColors.blue,
                busy: false,
                onTap: () => context.push('/result/${item.reportId}'),
              ),
            ),
          if (item.sessionId == null && item.reportId == null)
            const Text(
              '已接受，等待企业安排面试',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
        ],
      );
    }
    return Text(
      item.statusText,
      style: const TextStyle(color: AppColors.muted, fontSize: 12),
    );
  }

  Widget _filledButton({
    required String label,
    required bool busy,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.primaryButton,
          borderRadius: BorderRadius.circular(11),
        ),
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }

  Widget _outlineButton({
    required String label,
    required Color color,
    required bool busy,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: busy
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }

  Widget _statusBadge(InviteItem item) {
    final (Color fg, Color bg) = switch (item.status) {
      'pending' => (AppColors.orange, const Color(0xFFFFF3D6)),
      'accepted' => (AppColors.success, const Color(0xFFDCF5E6)),
      'rejected' => (AppColors.danger, const Color(0xFFFFE1E7)),
      'completed' => (AppColors.blue, const Color(0xFFE7EDFF)),
      _ => (AppColors.muted, const Color(0x0F002B99)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        item.statusText,
        style: TextStyle(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _pill(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
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
                onPressed: () => _load(reset: true),
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
