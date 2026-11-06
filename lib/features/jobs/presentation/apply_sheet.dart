import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../data/jobs_models.dart';
import '../data/jobs_providers.dart';

/// 弹出投递弹窗；投递成功返回 `true`。
Future<bool?> showApplySheet({
  required BuildContext context,
  required JobSummary job,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
    ),
    builder: (_) => _ApplySheet(job: job),
  );
}

class _ApplySheet extends ConsumerStatefulWidget {
  const _ApplySheet({required this.job});

  final JobSummary job;

  @override
  ConsumerState<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends ConsumerState<_ApplySheet> {
  bool _loading = true;
  bool _submitting = false;
  List<ResumeBrief> _resumes = const [];
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadResumes());
  }

  Future<void> _loadResumes() async {
    final rows = await ref.read(jobsRepositoryProvider).resumeList();
    if (!mounted) return;
    setState(() {
      _resumes = rows;
      _loading = false;
      if (rows.isNotEmpty) {
        _selectedId = rows
            .firstWhere((e) => e.isDefault, orElse: () => rows.first)
            .id;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final msg = await ref
          .read(jobsRepositoryProvider)
          .apply(widget.job.id, resumeId: _selectedId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      showToast(context, msg);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showToast(context, '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 6),
            child: Text(
              '投递「${widget.job.jobName}」',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              widget.job.tenantName.isEmpty
                  ? '确认投递后，企业将可以查看你的资料'
                  : '企业：${widget.job.tenantName}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 14),
          _resumeBlock(),
          const SizedBox(height: 12),
          _consentBlock(),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: MlfPrimaryButton(
              label: '确认投递',
              loading: _submitting,
              onPressed: _loading ? null : _submit,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _resumeBlock() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator(color: AppColors.blue)),
      );
    }
    if (_resumes.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 22),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3D6),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0x33FFB36B)),
        ),
        child: Row(
          children: const [
            Icon(Icons.info_outline, size: 18, color: AppColors.wine),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '未获取到你的简历；若还未上传简历，请先上传后再投递',
                style: TextStyle(
                  color: AppColors.wine,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 0, 22, 8),
          child: Text(
            '选择简历',
            style: TextStyle(
              color: AppColors.blue,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        for (final resume in _resumes) _resumeOption(resume),
      ],
    );
  }

  Widget _resumeOption(ResumeBrief resume) {
    final active = _selectedId == resume.id;
    return InkWell(
      onTap: () => setState(() => _selectedId = resume.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        child: Row(
          children: [
            Icon(
              active ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 19,
              color: active ? AppColors.blue : AppColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                resume.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: AppColors.ink),
              ),
            ),
            if (resume.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7EDFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '默认',
                  style: TextStyle(
                    color: AppColors.blue,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _consentBlock() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D6),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0x33FFB36B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline, size: 17, color: AppColors.wine),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '投递即表示你同意企业查看你的简历与相关面试资料，用于本次招聘评估。',
              style: TextStyle(
                color: AppColors.wine,
                fontSize: 11.5,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
