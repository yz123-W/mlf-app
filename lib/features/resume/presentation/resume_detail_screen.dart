import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/async/polling_controller.dart';
import '../../../shared/utils/toast.dart';
import '../data/resume_models.dart';
import '../data/resume_providers.dart';

/// 简历详情：文件信息 + AI 解析结果（基本信息 / 技能 / 经历 / 总结 / 评价建议）。
///
/// 解析中自动轮询 `/interview/resume/{id}/parse`，完成后刷新详情。
class ResumeDetailScreen extends ConsumerStatefulWidget {
  const ResumeDetailScreen({super.key, required this.resumeId});

  final int resumeId;

  @override
  ConsumerState<ResumeDetailScreen> createState() => _ResumeDetailScreenState();
}

class _ResumeDetailScreenState extends ConsumerState<ResumeDetailScreen> {
  bool _busy = false;
  PollingController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    ref.invalidate(resumeDetailProvider(widget.resumeId));
    await ref.read(resumeDetailProvider(widget.resumeId).future);
  }

  Future<void> _startParse() async {
    setState(() => _busy = true);
    try {
      await ref.read(resumeRepositoryProvider).triggerParse(widget.resumeId);
      if (!mounted) return;
      showToast(context, '已开始 AI 解析，请稍候');
      await _reload();
      _watchParse();
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 每 2s 轮询，最多 60s；完成或失败后刷新详情。
  void _watchParse() {
    _controller?.dispose();
    final controller = PollingController(
      interval: const Duration(seconds: 2),
      timeout: const Duration(seconds: 60),
      onTick: _pollParse,
      onTimeout: () {
        _controller = null;
        if (mounted) showToast(context, '解析时间较长，请稍后下拉刷新查看结果');
      },
    );
    _controller = controller;
    controller.start();
  }

  Future<void> _pollParse() async {
    final controller = _controller;
    if (controller == null) return;
    final status = await ref
        .read(resumeRepositoryProvider)
        .parseStatus(widget.resumeId, cancelToken: controller.cancelToken);
    if (!mounted) return;
    if (status.success || status.failed) {
      controller.stop();
      _controller = null;
      showToast(context, status.success ? '简历解析完成' : '简历解析失败，请稍后重试');
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.ink,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: () => context.pop(),
        ),
        title: const Text('简历详情',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: ref.watch(resumeDetailProvider(widget.resumeId)).when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.blue)),
            error: (error, _) => _errorBlock('$error'),
            data: (item) {
              if (item.parseStatus == '1') _ensurePolling(item.id);
              return RefreshIndicator(
                color: AppColors.blue,
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                  children: [
                    _fileCard(item),
                    const SizedBox(height: 14),
                    ..._resultBlocks(item),
                  ],
                ),
              );
            },
          ),
    );
  }

  void _ensurePolling(int id) {
    if (_controller != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller == null) _watchParse();
    });
  }

  Widget _errorBlock(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 44, color: AppColors.muted),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.6)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _reload,
                style: FilledButton.styleFrom(backgroundColor: AppColors.blue),
                child: const Text('重新加载',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );

  Widget _fileCard(ResumeItem item) {
    final (icon, color) = _fileStyle(item.fileType);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.resumeName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (item.isDefault) _badge('默认简历', AppColors.success, const Color(0xFFDCF5E6)),
                    _parseBadge(item),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    item.typeLabel,
                    item.sizeText,
                    item.sourceText,
                    if (item.createTime != null)
                      '上传于 ${DateFormat('yyyy-MM-dd HH:mm').format(item.createTime!)}',
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.6),
                ),
                if (item.parseTime != null)
                  Text('解析于 ${DateFormat('yyyy-MM-dd HH:mm').format(item.parseTime!)}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _resultBlocks(ResumeItem item) {
    final parsed = ResumeParsedResult.tryParse(item.parseResult);
    if (parsed == null) {
      return [
        _emptyResult(item),
      ];
    }
    return [
      _section(
        '基本信息',
        Column(
          children: [
            _infoRow('姓名', parsed.name, '性别', parsed.gender),
            _infoRow('电话', parsed.phone, '邮箱', parsed.email),
            _infoRow('学校', parsed.school, '专业', parsed.major),
            _infoRow('学历', parsed.education, '毕业年份', parsed.graduationYear),
          ],
        ),
      ),
      if (parsed.skills.isNotEmpty)
        _section(
          '技能标签',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: parsed.skills
                .map((skill) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7EDFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(skill,
                          style: const TextStyle(
                              color: AppColors.blue,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700)),
                    ))
                .toList(),
          ),
        ),
      if (parsed.workExperiences.isNotEmpty)
        _section('工作经历', _experienceList(parsed.workExperiences)),
      if (parsed.projectExperiences.isNotEmpty)
        _section('项目经历', _experienceList(parsed.projectExperiences)),
      if (parsed.summary.isNotEmpty) _section('个人总结', _paragraph(parsed.summary)),
      if (parsed.overallEvaluation.isNotEmpty || parsed.suggestions.isNotEmpty)
        _section(
          'AI 评价与建议',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (parsed.overallEvaluation.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.mint.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(parsed.overallEvaluation,
                      style: const TextStyle(fontSize: 12.5, height: 1.7, color: AppColors.ink)),
                ),
              if (parsed.suggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final suggestion in parsed.suggestions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6, right: 8),
                          child: CircleAvatar(radius: 2.5, backgroundColor: AppColors.wine),
                        ),
                        Expanded(
                          child: Text(suggestion,
                              style: const TextStyle(
                                  fontSize: 12.5, height: 1.7, color: AppColors.ink)),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
    ];
  }

  Widget _emptyResult(ResumeItem item) {
    final parsing = item.parseStatus == '1';
    final failed = item.parseStatus == '3';
    final (IconData icon, String title, String hint) = switch (item.parseStatus) {
      '1' => (Icons.hourglass_top, '正在解析中，请稍等', 'AI 正在提取简历里的信息，通常几十秒内完成'),
      '3' => (Icons.error_outline, '简历解析失败', '可能是文件内容无法识别，可重新解析或更换文件'),
      '2' => (Icons.description_outlined, '暂无解析结果', '该简历的解析结果为空，可重新触发 AI 解析'),
      _ => (Icons.auto_awesome, '尚未进行 AI 解析', '解析后可查看提取的个人信息、经历与改进建议'),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 30),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: parsing ? AppColors.blue : AppColors.muted),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 6),
          Text(hint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.6)),
          if (parsing) ...[
            const SizedBox(height: 16),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.blue),
            ),
          ] else ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 42,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                ),
                onPressed: _busy ? null : _startParse,
                child: Text(
                  failed || item.parseStatus == '2' ? '重新 AI 解析' : '开始 AI 解析',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String leftLabel, String leftValue, String rightLabel, String rightValue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: _infoCell(leftLabel, leftValue)),
          Expanded(child: _infoCell(rightLabel, rightValue)),
        ],
      ),
    );
  }

  Widget _infoCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        const SizedBox(height: 3),
        Text(value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.5)),
      ],
    );
  }

  Widget _experienceList(List<ResumeExperience> experiences) {
    return Column(
      children: [
        for (final exp in experiences)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FB),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [exp.company, exp.position].where((e) => e.isNotEmpty).join(' · '),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                if (exp.period.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(exp.period,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
                if (exp.description.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(exp.description,
                      style: const TextStyle(fontSize: 12.5, height: 1.7, color: AppColors.ink)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _paragraph(String text) => Text(text,
      style: const TextStyle(fontSize: 12.5, height: 1.75, color: AppColors.ink));

  Widget _badge(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800)),
      );

  Widget _parseBadge(ResumeItem item) {
    final (Color fg, Color bg) = switch (item.parseStatus) {
      '1' => (AppColors.blue, const Color(0xFFE7EDFF)),
      '2' => (AppColors.success, const Color(0xFFDCF5E6)),
      '3' => (AppColors.danger, const Color(0xFFFFE1E7)),
      _ => (AppColors.muted, const Color(0x0F002B99)),
    };
    return _badge(item.parseLabel, fg, bg);
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
