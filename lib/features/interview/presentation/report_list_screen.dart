import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../../home/data/home_models.dart';
import '../data/interview_providers.dart';

/// 面试记录：复盘报告列表（查看 / 重新生成 / 删除 / 导出 PDF）。
class ReportListScreen extends ConsumerStatefulWidget {
  const ReportListScreen({super.key});

  @override
  ConsumerState<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends ConsumerState<ReportListScreen> {
  static const int _pageSize = 10;

  final List<InterviewReportItem> _items = [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (reset) {
        _page = 1;
        _hasMore = true;
        _error = null;
      }
    });
    try {
      final list = await ref
          .read(interviewRepositoryProvider)
          .reportList(pageNum: _page, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(list);
        _hasMore = list.length == _pageSize;
        if (_hasMore) _page++;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(InterviewReportItem item) {
    if (item.generateStatus == '1') {
      showToast(context, '报告生成中，请稍后再查看');
      return;
    }
    context.push('/result/${item.id}').then((_) => _load(reset: true));
  }

  Future<void> _regenerate(InterviewReportItem item) async {
    final sessionId = item.sessionId;
    if (sessionId == null) {
      showToast(context, '缺少关联场次，无法重新生成');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(interviewRepositoryProvider).generateReport(sessionId);
      if (!mounted) return;
      showToast(context, '已提交重新生成，请稍后刷新查看');
      await _load(reset: true);
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(InterviewReportItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除报告'),
        content: Text(
          '确定删除「${item.jobName.isEmpty ? '这次面试' : item.jobName}」的复盘报告吗？',
          style: const TextStyle(fontSize: 13.5, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '删除',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(interviewRepositoryProvider).deleteMyReport(item.id);
      if (!mounted) return;
      showToast(context, '报告已删除');
      await _load(reset: true);
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportPdf(InterviewReportItem item) async {
    setState(() => _busy = true);
    try {
      final bytes = await ref
          .read(interviewRepositoryProvider)
          .downloadReportPdf(item.id);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/report-${item.id}.pdf');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      showToast(context, '报告已保存至：${file.path}');
    } catch (e) {
      if (mounted) showToast(context, '导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: const Text(
          '面试记录',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.blue,
        onRefresh: () => _load(reset: true),
        child: _items.isEmpty && _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.blue),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  if (_error != null) _errorBlock(_error!),
                  if (_items.isEmpty && !_loading && _error == null)
                    _emptyBlock(),
                  for (final item in _items) ...[
                    _reportCard(item),
                    const SizedBox(height: 12),
                  ],
                  if (_items.isNotEmpty) _footer(),
                ],
              ),
      ),
    );
  }

  Widget _reportCard(InterviewReportItem item) {
    final (Color fg, Color bg) = switch (item.generateStatus) {
      '0' => (AppColors.muted, const Color(0x0F002B99)),
      '1' => (AppColors.blue, const Color(0xFFE7EDFF)),
      '3' => (AppColors.wine, const Color(0xFFFFE4D8)),
      _ => (AppColors.success, const Color(0xFFDCF5E6)),
    };
    return MlfCard(
      padding: const EdgeInsets.fromLTRB(15, 15, 6, 15),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _open(item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.jobName.isEmpty ? '模拟面试' : item.jobName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.generateLabel,
                          style: TextStyle(
                            color: fg,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.startTime == null
                        ? '时间未知'
                        : DateFormat('yyyy-MM-dd HH:mm')
                              .format(item.startTime!),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.totalScore == null
                            ? '--'
                            : item.totalScore!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: AppColors.wine,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 2, left: 3),
                        child: Text(
                          '分',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            enabled: !_busy,
            icon: const Icon(Icons.more_vert, color: AppColors.muted, size: 20),
            onSelected: (value) {
              if (value == 'open') _open(item);
              if (value == 'regenerate') _regenerate(item);
              if (value == 'pdf') _exportPdf(item);
              if (value == 'delete') _remove(item);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'open', child: Text('查看复盘')),
              if (item.sessionId != null)
                const PopupMenuItem(value: 'regenerate', child: Text('重新生成报告')),
              if (item.generateStatus == '2')
                const PopupMenuItem(value: 'pdf', child: Text('导出 PDF')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('删除', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: AppColors.blue)),
      );
    }
    if (_hasMore) {
      return Center(
        child: TextButton(
          onPressed: () => _load(),
          child: const Text(
            '加载更多',
            style: TextStyle(
              color: AppColors.blue,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.only(top: 4),
      child: Center(
        child: Text(
          '已加载全部报告',
          style: TextStyle(color: AppColors.muted, fontSize: 11.5),
        ),
      ),
    );
  }

  Widget _emptyBlock() {
    return MlfCard(
      padding: const EdgeInsets.fromLTRB(22, 34, 22, 34),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: Color(0xFFE7EDFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_edu_outlined,
              color: AppColors.blue,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '还没有面试报告',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            '完成一场模拟面试后，这里会生成复盘报告',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => context.go('/interview'),
            child: const Text(
              '去面试',
              style: TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBlock(String message) {
    return MlfCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.muted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _load(reset: true),
            child: const Text(
              '重试',
              style: TextStyle(
                color: AppColors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
