import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'resume_models.dart';

/// 简历接口：通用上传 `/common/upload` + 简历 CRUD `/interview/resume`。
class ResumeApi {
  const ResumeApi(this._client);

  final ApiClient _client;

  /// 当前学生的简历列表（后端按登录用户隔离）。
  Future<List<ResumeItem>> list() async {
    final res = await _client.getJson(
      '/interview/resume/list',
      query: {'pageNum': 1, 'pageSize': 50},
    );
    final rows = res['rows'];
    if (rows is List) {
      return rows
          .whereType<Map>()
          .map((e) => ResumeItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  /// 简历详情（含最新 `parseResult`）。
  Future<ResumeItem> detail(int id) async {
    final res = await _client.getJson('/interview/resume/$id');
    final data = res['data'];
    if (data is Map) {
      return ResumeItem.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('简历详情不存在');
  }

  /// 上传文件到服务器，返回后端相对路径。
  Future<UploadedResumeFile> upload({
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _client.postMultipart('/common/upload', form);
    return UploadedResumeFile(
      fileName: res['fileName']?.toString() ?? '',
      originalFilename: res['originalFilename']?.toString() ?? filename,
      url: res['url']?.toString() ?? '',
    );
  }

  /// 新增简历记录。
  Future<void> create({
    required String resumeName,
    required String fileUrl,
    required String fileType,
    required int fileSize,
    required String sourceType,
    required bool isDefault,
  }) async {
    await _client.postJson('/interview/resume', data: {
      'resumeName': resumeName,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileSize': fileSize,
      'sourceType': sourceType,
      'isDefault': isDefault ? '1' : '0',
    });
  }

  /// 设为默认简历（后端会自动取消其他默认）。
  Future<void> setDefault(int id) async {
    await _client.putJson('/interview/resume', data: {'id': id, 'isDefault': '1'});
  }

  /// 删除简历。
  Future<void> remove(int id) async {
    await _client.deleteJson('/interview/resume/$id');
  }

  /// 触发 AI 解析（异步，需轮询 [parseStatus]）。
  Future<void> triggerParse(int id) async {
    await _client.postJson('/interview/resume/$id/parse');
  }

  /// 查询解析状态（字段在响应顶层，不在 `data` 内）。
  Future<ResumeParseStatusM> parseStatus(int id, {CancelToken? cancelToken}) async {
    final res = await _client.getJson('/interview/resume/$id/parse', cancelToken: cancelToken);
    return ResumeParseStatusM.fromJson(Map<String, dynamic>.from(res));
  }
}
