import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../data/resume_models.dart';
import '../data/resume_providers.dart';
import 'resume_upload_support.dart';

/// 我的简历：列表 + 上传 + 设为默认 + 删除。
class ResumeListScreen extends ConsumerStatefulWidget {
  const ResumeListScreen({super.key});

  @override
  ConsumerState<ResumeListScreen> createState() => _ResumeListScreenState();
}

class _ResumeListScreenState extends ConsumerState<ResumeListScreen> {
  bool _busy = false;
  Timer? _parseTimer;

  @override
  void dispose() {
    _parseTimer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    ref.invalidate(resumeListProvider);
    await ref.read(resumeListProvider.future);
  }

  Future<void> _pickAndUpload() async {
    final source = await showResumeSourceSheet(context);
    if (source == null || !mounted) return;

    PickedResume? picked;
    try {
      picked = source == ResumeSource.camera ? await pickResumePhoto() : await pickResumeFile();
    } on ResumePickException catch (e) {
      if (mounted) showToast(context, e.message);
      return;
    } catch (e) {
      if (mounted) showToast(context, '选择文件失败：$e');
      return;
    }
    if (picked == null || !mounted) return;

    final existing = ref.read(resumeListProvider).value ?? const <ResumeItem>[];
    setState(() => _busy = true);
    try {
      await uploadPickedResume(ref, picked, isDefault: existing.isEmpty);
      if (!mounted) return;
      showToast(context, '简历已上传');
      await _reload();
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setDefault(ResumeItem item) async {
    setState(() => _busy = true);
    try {
      await ref.read(resumeRepositoryProvider).setDefault(item.id);
      if (!mounted) return;
      showToast(context, '已设为默认简历');
      await _reload();
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startParse(ResumeItem item) async {
    setState(() => _busy = true);
    try {
      await ref.read(resumeRepositoryProvider).triggerParse(item.id);
      if (!mounted) return;
      showToast(context, '已开始 AI 解析，请稍候');
      await _reload();
      _watchParse(item.id);
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 每 2s 轮询解析状态，最多 60s；结束或失败后刷新列表。
  void _watchParse(int id) {
    _parseTimer?.cancel();
    var attempts = 0;
    _parseTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      attempts++;
      if (attempts > 30) {
        timer.cancel();
        return;
      }
      try {
        final status = await ref.read(resumeRepositoryProvider).parseStatus(id);
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (status.success || status.failed) {
          timer.cancel();
          showToast(context, status.success ? '简历解析完成' : '简历解析失败，请稍后重试');
          await _reload();
        }
      } catch (_) {
        // 网络抖动继续轮询。
      }
    });
  }

  void _openDetail(ResumeItem item) {
    context.push('/profile/resumes/${item.id}').then((_) {
      if (mounted) _reload();
    });
  }

  Future<void> _remove(ResumeItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除简历'),
        content: Text('确定删除「${item.resumeName}」吗？删除后不可恢复。',
            style: const TextStyle(fontSize: 13.5, height: 1.6)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(resumeRepositoryProvider).remove(item.id);
      if (!mounted) return;
      showToast(context, '简历已删除');
      await _reload();
    } catch (e) {
      if (mounted) showToast(context, '$e');
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
        title: const Text('我的简历', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: ref.watch(resumeListProvider).when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.blue)),
            error: (error, _) => _errorBlock('$error'),
            data: (items) => RefreshIndicator(
              color: AppColors.blue,
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                children: [
                  if (items.isEmpty) _emptyBlock(),
                  for (final item in items) ...[
                    _resumeCard(item),
                    const SizedBox(height: 12),
                  ],
                  if (items.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 4, left: 4, right: 4),
                      child: Text(
                        '投递岗位时会默认使用「默认简历」，可随时切换。',
                        style: TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.6),
                      ),
                    ),
                ],
              ),
            ),
          ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
          child: MlfPrimaryButton(
            label: '上传新简历',
            loading: _busy,
            onPressed: _busy ? null : _pickAndUpload,
          ),
        ),
      ),
    );
  }

  Widget _errorBlock(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.6)),
            const SizedBox(height: 16),
            SizedBox(
              height: 42,
              child: FilledButton(
                onPressed: _reload,
                style: FilledButton.styleFrom(backgroundColor: AppColors.blue),
                child: const Text('重新加载',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
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
            decoration: const BoxDecoration(color: Color(0xFFE7EDFF), shape: BoxShape.circle),
            child: const Icon(Icons.upload_file, color: AppColors.blue, size: 30),
          ),
          const SizedBox(height: 14),
          const Text('还没有上传简历', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('上传一份简历，投递岗位时可直接选用',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.6)),
        ],
      ),
    );
  }

  Widget _resumeCard(ResumeItem item) {
    final (icon, color) = _fileStyle(item.fileType);
    return GestureDetector(
      onTap: () => _openDetail(item),
      child: MlfCard(
        padding: const EdgeInsets.fromLTRB(15, 15, 8, 15),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(item.resumeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                      ),
                      if (item.isDefault) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.mint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('默认',
                              style: TextStyle(
                                  color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                      ],
                      const SizedBox(width: 7),
                      _parseBadge(item),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      item.typeLabel,
                      item.sizeText,
                      item.sourceText,
                      if (item.createTime != null) DateFormat('yyyy-MM-dd').format(item.createTime!),
                    ].join(' · '),
                    style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              enabled: !_busy,
              icon: const Icon(Icons.more_vert, color: AppColors.muted, size: 20),
              onSelected: (value) {
                if (value == 'detail') _openDetail(item);
                if (value == 'default') _setDefault(item);
                if (value == 'parse') _startParse(item);
                if (value == 'delete') _remove(item);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'detail', child: Text('查看详情')),
                if (!item.isDefault)
                  const PopupMenuItem(value: 'default', child: Text('设为默认')),
                if (item.parseStatus != '1')
                  PopupMenuItem(
                    value: 'parse',
                    child: Text(item.parseStatus == '2' ? 'AI 重新解析' : 'AI 解析'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('删除', style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _parseBadge(ResumeItem item) {
    final (Color fg, Color bg) = switch (item.parseStatus) {
      '1' => (AppColors.blue, const Color(0xFFE7EDFF)),
      '2' => (AppColors.success, const Color(0xFFDCF5E6)),
      '3' => (AppColors.danger, const Color(0xFFFFE4D8)),
      _ => (AppColors.muted, const Color(0x0F002B99)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(item.parseLabel,
          style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

(IconData, Color) _fileStyle(String type) {
  switch (type.toLowerCase()) {
    case 'pdf':
      return (Icons.picture_as_pdf_outlined, AppColors.wine);
    case 'doc':
    case 'docx':
      return (Icons.description_outlined, AppColors.blue);
    case 'jpg':
    case 'jpeg':
    case 'png':
      return (Icons.image_outlined, AppColors.success);
    default:
      return (Icons.insert_drive_file_outlined, AppColors.muted);
  }
}
