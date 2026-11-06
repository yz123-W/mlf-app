import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../data/resume_providers.dart';

/// 简历允许的文件类型（与后端 `FileUploadUtils` 白名单一致）。
const List<String> kResumeExtensions = ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'];

/// 后端 `spring.servlet.multipart.max-file-size` 为 10MB。
const int kMaxResumeBytes = 10 * 1024 * 1024;

enum ResumeSource { file, camera }

/// 已选中的本地简历文件。
class PickedResume {
  const PickedResume({
    required this.bytes,
    required this.name,
    required this.extension,
    required this.source,
  });

  /// 文件内容（选中时一次性读入，上限 10MB）。
  final List<int> bytes;
  final String name;
  final String extension;
  final ResumeSource source;

  int get size => bytes.length;

  String get resumeName {
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final trimmed = base.trim();
    if (trimmed.isEmpty) return '我的简历';
    return trimmed.length > 100 ? trimmed.substring(0, 100) : trimmed;
  }

  String get sizeText {
    if (size <= 0) return '大小未知';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String get sourceType => source == ResumeSource.camera ? '2' : '1';
}

/// 选择/上传过程中的可展示错误。
class ResumePickException implements Exception {
  const ResumePickException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 本地文件选择（PDF / Word / 图片）。
Future<PickedResume?> pickResumeFile() async {
  final file = await FilePicker.pickFile(
    dialogTitle: '选择简历文件',
    type: FileType.custom,
    allowedExtensions: kResumeExtensions,
  );
  if (file == null) return null;
  final rawName = file.name;
  final uriName =
      file.uri.pathSegments.isEmpty ? '' : file.uri.pathSegments.last;
  var extension = _extensionOf(rawName);
  if (extension.isEmpty) extension = (file.extension ?? '').toLowerCase();
  if (extension.isEmpty) extension = _extensionOf(uriName);
  final name = _extensionOf(rawName).isEmpty && extension.isNotEmpty
      ? '$rawName.$extension'
      : rawName;
  if (!kResumeExtensions.contains(extension)) {
    throw ResumePickException('仅支持 PDF / Word / 图片格式，当前为 $extension');
  }
  final bytes = await file.readAsBytes();
  _checkSize(bytes.length);
  return PickedResume(
    bytes: bytes,
    name: name,
    extension: extension,
    source: ResumeSource.file,
  );
}

/// 拍照导入。
Future<PickedResume?> pickResumePhoto() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 88);
  if (picked == null) return null;
  final name = picked.name.isEmpty ? '拍照简历.jpg' : picked.name;
  final extension = _extensionOf(name);
  if (!kResumeExtensions.contains(extension)) {
    throw ResumePickException('仅支持 PDF / Word / 图片格式，当前为 $extension');
  }
  final bytes = await picked.readAsBytes();
  _checkSize(bytes.length);
  return PickedResume(
    bytes: bytes,
    name: name,
    extension: extension,
    source: ResumeSource.camera,
  );
}

/// 底部选择「本地文件 / 拍照」。
Future<ResumeSource?> showResumeSourceSheet(BuildContext context) {
  return showModalBottomSheet<ResumeSource>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 18),
          const Text('上传简历', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('支持 PDF / Word / 图片，单个文件不超过 10MB',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          _sourceRow(
            sheetContext,
            icon: Icons.folder_open,
            label: '本地文件上传',
            color: AppColors.blue,
            source: ResumeSource.file,
          ),
          const Divider(height: 1, indent: 22, endIndent: 22, color: AppColors.line),
          _sourceRow(
            sheetContext,
            icon: Icons.camera_alt_outlined,
            label: '拍照导入',
            color: AppColors.wine,
            source: ResumeSource.camera,
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// 上传文件并写入一条简历记录（默认简历由调用方决定）。
Future<void> uploadPickedResume(
  WidgetRef ref,
  PickedResume picked, {
  required bool isDefault,
}) async {
  final repo = ref.read(resumeRepositoryProvider);
  final uploaded = await repo.upload(bytes: picked.bytes, filename: picked.name);
  if (uploaded.fileName.isEmpty) {
    throw const ResumePickException('上传失败：服务器未返回文件地址');
  }
  await repo.create(
    resumeName: picked.resumeName,
    fileUrl: uploaded.fileName,
    fileType: picked.extension,
    fileSize: picked.size,
    sourceType: picked.sourceType,
    isDefault: isDefault,
  );
}

Widget _sourceRow(
  BuildContext sheetContext, {
  required IconData icon,
  required String label,
  required Color color,
  required ResumeSource source,
}) {
  return InkWell(
    onTap: () => Navigator.of(sheetContext).pop(source),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
        ],
      ),
    ),
  );
}

String _extensionOf(String name) {
  final index = name.lastIndexOf('.');
  if (index < 0 || index == name.length - 1) return '';
  return name.substring(index + 1).toLowerCase();
}

void _checkSize(int size) {
  if (size > kMaxResumeBytes) {
    throw const ResumePickException('文件超过 10MB，请压缩后重新上传');
  }
}
