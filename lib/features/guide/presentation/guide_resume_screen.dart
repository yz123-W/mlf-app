import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/utils/toast.dart';
import '../../resume/presentation/resume_upload_support.dart';

/// 新用户引导 · 第二步：上传简历
///
/// 已接入 `/common/upload` + `/interview/resume`：本地文件或拍照导入，
/// 上传成功后写入一条默认简历记录，再进入首页。
class GuideResumeScreen extends ConsumerStatefulWidget {
  const GuideResumeScreen({super.key});

  @override
  ConsumerState<GuideResumeScreen> createState() => _GuideResumeScreenState();
}

class _GuideResumeScreenState extends ConsumerState<GuideResumeScreen> {
  PickedResume? _picked;
  bool _uploading = false;

  Future<void> _pick(ResumeSource source) async {
    if (_uploading) return;
    try {
      final picked = source == ResumeSource.camera ? await pickResumePhoto() : await pickResumeFile();
      if (picked == null || !mounted) return;
      setState(() => _picked = picked);
    } on ResumePickException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (e) {
      if (mounted) showToast(context, '选择文件失败：$e');
    }
  }

  Future<void> _submit() async {
    final picked = _picked;
    if (picked == null) {
      showToast(context, '请先选择简历文件');
      return;
    }
    setState(() => _uploading = true);
    try {
      await uploadPickedResume(ref, picked, isDefault: true);
      if (!mounted) return;
      showToast(context, '简历已上传');
      context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        showToast(context, '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _back(context),
                  const Spacer(),
                  const Text('02 / 03',
                      style: TextStyle(color: AppColors.wine, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                height: 170,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Icon(Icons.file_upload_outlined, color: AppColors.blue, size: 68),
              ),
              const SizedBox(height: 18),
              const Text('带上你的简历',
                  style: TextStyle(fontSize: 27, letterSpacing: -1, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('AI 会提取你的经历与能力，生成更具针对性的追问。',
                  style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.65)),
              Expanded(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    height: 155,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.blueSoft,
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(color: const Color(0xFF91A9E8), width: 1.5),
                    ),
                    child: _picked == null ? _sourceRow() : _pickedFile(),
                  ),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 15, color: AppColors.muted),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '你的简历仅用于生成面试练习与个性化建议，我们会妥善保护信息。',
                      style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 51,
                      child: OutlinedButton(
                        onPressed: () => context.go('/home'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFE7EDFF),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text('跳过此步',
                            style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: SizedBox(
                      height: 51,
                      child: FilledButton(
                        onPressed: _uploading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: _uploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('确认上传',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _way(Icons.folder_open, '本地文件上传', AppColors.blue, ResumeSource.file),
        const SizedBox(width: 13),
        _way(Icons.camera_alt_outlined, '拍照导入', AppColors.wine, ResumeSource.camera),
      ],
    );
  }

  Widget _pickedFile() {
    final picked = _picked!;
    final isImage = ['jpg', 'jpeg', 'png'].contains(picked.extension);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFE7EDFF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(isImage ? Icons.image_outlined : Icons.description_outlined,
                  color: AppColors.blue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_picked!.resumeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${picked.extension.toUpperCase()} · ${picked.sizeText}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                ],
              ),
            ),
            IconButton(
              onPressed: _uploading ? null : () => setState(() => _picked = null),
              icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
              tooltip: '移除',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _uploading ? null : () => _pick(ResumeSource.file),
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('重新选择'),
              style: TextButton.styleFrom(foregroundColor: AppColors.blue),
            ),
          ],
        ),
      ],
    );
  }

  Widget _back(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/guide/1'),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.line),
        ),
        child: const Icon(Icons.arrow_back, size: 18, color: AppColors.blue),
      ),
    );
  }

  Widget _way(IconData icon, String label, Color color, ResumeSource source) {
    return GestureDetector(
      onTap: () => _pick(source),
      child: Container(
        width: 116,
        height: 106,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0D002B99), blurRadius: 13, offset: Offset(0, 5))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 7),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
