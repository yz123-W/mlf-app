import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'resume_api.dart';
import 'resume_models.dart';
import 'resume_repository.dart';

/// 简历仓库。
final resumeRepositoryProvider = Provider<ResumeRepository>(
  (ref) => ResumeRepository(ResumeApi(ref.watch(apiClientProvider))),
);

/// 当前学生的简历列表（上传/删除/设默认后 invalidate 刷新）。
final resumeListProvider = FutureProvider.autoDispose<List<ResumeItem>>(
  (ref) => ref.watch(resumeRepositoryProvider).list(),
);

/// 单份简历详情（含最新解析结果）。
final resumeDetailProvider = FutureProvider.autoDispose.family<ResumeItem, int>(
  (ref, id) => ref.watch(resumeRepositoryProvider).detail(id),
);
