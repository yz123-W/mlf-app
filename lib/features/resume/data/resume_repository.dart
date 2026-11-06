import 'package:dio/dio.dart';

import 'resume_api.dart';
import 'resume_models.dart';

/// 简历仓库：直连接口，不吞异常（由 UI 捕获展示错误）。
class ResumeRepository {
  const ResumeRepository(this._api);

  final ResumeApi _api;

  Future<List<ResumeItem>> list() => _api.list();

  Future<ResumeItem> detail(int id) => _api.detail(id);

  Future<UploadedResumeFile> upload({
    required List<int> bytes,
    required String filename,
  }) =>
      _api.upload(bytes: bytes, filename: filename);

  Future<void> create({
    required String resumeName,
    required String fileUrl,
    required String fileType,
    required int fileSize,
    required String sourceType,
    required bool isDefault,
  }) =>
      _api.create(
        resumeName: resumeName,
        fileUrl: fileUrl,
        fileType: fileType,
        fileSize: fileSize,
        sourceType: sourceType,
        isDefault: isDefault,
      );

  Future<void> setDefault(int id) => _api.setDefault(id);

  Future<void> remove(int id) => _api.remove(id);

  Future<void> triggerParse(int id) => _api.triggerParse(id);

  Future<ResumeParseStatusM> parseStatus(int id, {CancelToken? cancelToken}) =>
      _api.parseStatus(id, cancelToken: cancelToken);
}
