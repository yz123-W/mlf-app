import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/utils/json.dart';
import '../../home/data/home_models.dart';
import 'interview_models.dart';

/// 模拟面试接口（`/interview/session|question|qa|report|jobprofile`）。
class InterviewApi {
  const InterviewApi(this._client);

  final ApiClient _client;

  // ------------------------------------------------------------------ 场次

  /// 创建场次（=「开始挑战」）。
  ///
  /// 自由岗位模式：后端采信 `jobName` / `industry` / `difficulty`，
  /// `questionSource=ai` 时异步出题，`bank` 时建场即抽题完成。
  Future<InterviewSessionM> createSession({
    required String jobName,
    required String industry,
    required String difficulty,
    String questionSource = 'ai',
    int? resumeId,
    String? questionType,
    int totalCount = 5,
    String interviewType = '1',
  }) async {
    final res = await _client.postJson(
      '/interview/session',
      data: {
        'jobName': jobName,
        'industry': industry,
        'difficulty': difficulty,
        'questionSource': questionSource,
        'resumeId': ?resumeId,
        if (_notEmpty(questionType)) 'questionType': questionType,
        'totalCount': totalCount,
        'interviewType': interviewType,
      },
    );
    return InterviewSessionM.fromJson(_dataMap(res));
  }

  /// AI 出题状态（建场后轮询）。
  Future<GenerateStatusM> generateStatus(int sessionId, {CancelToken? cancelToken}) async {
    final res = await _client.getJson(
      '/interview/session/$sessionId/generate-status',
      cancelToken: cancelToken,
    );
    final data = res['data'];
    if (data is Map) {
      return GenerateStatusM.fromJson(Map<String, dynamic>.from(data));
    }
    return const GenerateStatusM();
  }

  /// 场次历史列表。
  Future<List<InterviewSessionM>> sessionList({
    int pageNum = 1,
    int pageSize = 10,
  }) async {
    final res = await _client.getJson(
      '/interview/session/list',
      query: {'pageNum': pageNum, 'pageSize': pageSize},
    );
    return rowsOf(res).map(InterviewSessionM.fromJson).toList();
  }

  /// 场次详情。
  Future<InterviewSessionM> sessionDetail(int id) async {
    final res = await _client.getJson('/interview/session/$id');
    return InterviewSessionM.fromJson(_dataMap(res));
  }

  /// 提前结束场次（进行中 → 已中断）。
  Future<InterviewSessionM> abortSession(int id) async {
    final res = await _client.putJson('/interview/session/abort/$id');
    return InterviewSessionM.fromJson(_dataMap(res));
  }

  // ------------------------------------------------------------------ 题目

  /// 本场题目列表。
  Future<List<InterviewQuestionM>> questionList(
    int sessionId, {
    int pageSize = 20,
  }) async {
    final res = await _client.getJson(
      '/interview/question/list',
      query: {'sessionId': sessionId, 'pageNum': 1, 'pageSize': pageSize},
    );
    return rowsOf(res).map(InterviewQuestionM.fromJson).toList();
  }

  /// 题目详情。
  Future<InterviewQuestionM?> questionDetail(int id) async {
    final res = await _client.getJson('/interview/question/$id');
    final data = res['data'];
    if (data is Map)
      return InterviewQuestionM.fromJson(Map<String, dynamic>.from(data));
    return null;
  }

  // ------------------------------------------------------------------ 作答

  /// 提交一道题的作答。
  ///
  /// 响应 `data` 为作答记录，顶层另有 `session` 键回传场次最新状态。
  Future<QaSubmitResult> submitAnswer({
    required int sessionId,
    required int questionId,
    required String answerContent,
    int duration = 0,
  }) async {
    final res = await _client.postJson(
      '/interview/qa/submit',
      data: {
        'sessionId': sessionId,
        'questionId': questionId,
        'answerContent': answerContent,
        'answerType': '1',
        'duration': duration,
      },
    );

    final data = res['data'];
    final answer = data is Map
        ? InterviewQaM.fromJson(Map<String, dynamic>.from(data))
        : null;
    final session = res['session'];
    final sessionM = session is Map
        ? InterviewSessionM.fromJson(Map<String, dynamic>.from(session))
        : null;
    return QaSubmitResult(answer: answer, session: sessionM);
  }

  /// 本场已提交的作答（用于进入时回填）。
  Future<List<InterviewQaM>> qaList(int sessionId, {int pageSize = 50}) async {
    final res = await _client.getJson(
      '/interview/qa/list',
      query: {'sessionId': sessionId, 'pageNum': 1, 'pageSize': pageSize},
    );
    return rowsOf(res).map(InterviewQaM.fromJson).toList();
  }

  // -------------------------------------------------------------- 语音 / 视频

  /// 对话式作答（语音 / 视频场次）：返回 AI 下一条消息与 TTS 题面音频。
  Future<ChatReply> chat(
    int sessionId, {
    required String answer,
    String answerType = '2',
    String? audioUrl,
    String? videoUrl,
    int? voice,
  }) async {
    final res = await _client.postJson(
      '/interview/session/$sessionId/chat',
      data: {
        'answer': answer,
        'answerType': answerType,
        if (audioUrl != null && audioUrl.isNotEmpty) 'audioUrl': audioUrl,
        if (videoUrl != null && videoUrl.isNotEmpty) 'videoUrl': videoUrl,
        'voice': ?voice,
      },
    );
    final data = res['data'];
    return data is Map
        ? ChatReply.fromJson(Map<String, dynamic>.from(data))
        : const ChatReply();
  }

  /// 上传录音：后端存盘 + 腾讯云 ASR 转文字。
  Future<MediaAudioResult> uploadAudio(
    int sessionId, {
    required String filePath,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
    });
    final res = await _client.postMultipart(
      '/interview/session/$sessionId/audio',
      form,
    );
    final data = res['data'];
    return data is Map
        ? MediaAudioResult.fromJson(Map<String, dynamic>.from(data))
        : const MediaAudioResult();
  }

  /// 上传视频录像（只存文件，不做 ASR）。
  Future<String> uploadVideo(
    int sessionId, {
    required String filePath,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
    });
    final res = await _client.postMultipart(
      '/interview/session/$sessionId/video',
      form,
    );
    final data = res['data'];
    if (data is Map) return data['videoUrl']?.toString() ?? '';
    return '';
  }

  // ------------------------------------------------------------------ 报告

  /// 报告详情。
  Future<InterviewReportM?> reportDetail(int id) async {
    final res = await _client.getJson('/interview/report/$id');
    final data = res['data'];
    if (data is Map)
      return InterviewReportM.fromJson(Map<String, dynamic>.from(data));
    return null;
  }

  /// 报告逐题明细。
  Future<List<ReportQuestionDetailM>> reportQuestions(int id) async {
    final res = await _client.getJson('/interview/report/$id/questions');
    final data = res['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (e) => ReportQuestionDetailM.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    }
    return const [];
  }

  /// 一键生成报告（只传 sessionId）。
  Future<InterviewReportM?> generateReport(int sessionId) async {
    final res = await _client.postJson(
      '/interview/report/generate',
      data: {'sessionId': sessionId},
    );
    final data = res['data'];
    if (data is Map)
      return InterviewReportM.fromJson(Map<String, dynamic>.from(data));
    return null;
  }

  /// 下载报告 PDF（二进制流）。
  Future<List<int>> downloadReportPdf(int reportId) =>
      _client.getBytes('/interview/report/$reportId/pdf');

  /// 复盘报告列表（分页）。
  Future<List<InterviewReportItem>> reportList({
    int pageNum = 1,
    int pageSize = 10,
  }) async {
    final res = await _client.getJson(
      '/interview/report/list',
      query: {'pageNum': pageNum, 'pageSize': pageSize},
    );
    return rowsOf(res).map(InterviewReportItem.fromJson).toList();
  }

  /// 删除自己的报告（专用接口）。
  Future<void> deleteMyReport(int id) =>
      _client.deleteJson('/interview/report/my/$id');

  // -------------------------------------------------------------- 岗位画像

  /// 当前学生的岗位画像列表。
  Future<List<JobProfileM>> jobProfileList({int pageSize = 50}) async {
    final res = await _client.getJson(
      '/interview/jobprofile/list',
      query: {'pageNum': 1, 'pageSize': pageSize},
    );
    return rowsOf(res).map(JobProfileM.fromJson).toList();
  }

  /// 新建岗位画像（后端不返回 id）。难度/企业类型不再由画像填写，走库默认值。
  Future<void> createJobProfile({
    required String industry,
    required String jobName,
    required String city,
    required String salary,
    bool isDefault = false,
  }) => _client.postJson(
    '/interview/jobprofile',
    data: {
      'industry': industry,
      'jobName': jobName,
      'city': city,
      'salary': salary,
      'isDefault': isDefault ? '1' : '0',
    },
  );

  /// 修改岗位画像（空串表示「不限」，后端会把对应列清空）。
  Future<void> updateJobProfile({
    required int id,
    required String industry,
    required String jobName,
    required String city,
    required String salary,
    bool isDefault = false,
  }) => _client.putJson(
    '/interview/jobprofile',
    data: {
      'id': id,
      'industry': industry,
      'jobName': jobName,
      'city': city,
      'salary': salary,
      'isDefault': isDefault ? '1' : '0',
    },
  );

  /// 删除岗位画像（支持单条）。
  Future<void> deleteJobProfile(int id) =>
      _client.deleteJson('/interview/jobprofile/$id');

  // -------------------------------------------------------------- 解包工具

  Map<String, dynamic> _dataMap(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  static bool _notEmpty(String? value) =>
      value != null && value.trim().isNotEmpty;
}
