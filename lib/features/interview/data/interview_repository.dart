import 'package:dio/dio.dart';

import '../../home/data/home_models.dart';
import 'interview_api.dart';
import 'interview_models.dart';

/// 模拟面试仓库：接口转发。
class InterviewRepository {
  const InterviewRepository(this._api);

  final InterviewApi _api;

  Future<InterviewSessionM> createSession({
    required String jobName,
    required String industry,
    required String difficulty,
    String questionSource = 'ai',
    int? resumeId,
    String? questionType,
    int totalCount = 5,
    String interviewType = '1',
  }) => _api.createSession(
    jobName: jobName,
    industry: industry,
    difficulty: difficulty,
    questionSource: questionSource,
    resumeId: resumeId,
    questionType: questionType,
    totalCount: totalCount,
    interviewType: interviewType,
  );

  Future<GenerateStatusM> generateStatus(int sessionId, {CancelToken? cancelToken}) =>
      _api.generateStatus(sessionId, cancelToken: cancelToken);

  Future<List<InterviewReportItem>> reportList({
    int pageNum = 1,
    int pageSize = 10,
  }) => _api.reportList(pageNum: pageNum, pageSize: pageSize);

  Future<void> deleteMyReport(int id) => _api.deleteMyReport(id);

  Future<List<InterviewSessionM>> sessionList({
    int pageNum = 1,
    int pageSize = 10,
  }) => _api.sessionList(pageNum: pageNum, pageSize: pageSize);

  Future<InterviewSessionM> sessionDetail(int id) => _api.sessionDetail(id);

  Future<InterviewSessionM> abortSession(int id) => _api.abortSession(id);

  Future<List<InterviewQuestionM>> questionList(int sessionId) =>
      _api.questionList(sessionId);

  Future<InterviewQuestionM?> questionDetail(int id) => _api.questionDetail(id);

  Future<QaSubmitResult> submitAnswer({
    required int sessionId,
    required int questionId,
    required String answerContent,
    int duration = 0,
  }) => _api.submitAnswer(
    sessionId: sessionId,
    questionId: questionId,
    answerContent: answerContent,
    duration: duration,
  );

  Future<List<InterviewQaM>> qaList(int sessionId) => _api.qaList(sessionId);

  Future<ChatReply> chat(
    int sessionId, {
    required String answer,
    String answerType = '2',
    String? audioUrl,
    String? videoUrl,
    int? voice,
  }) => _api.chat(
    sessionId,
    answer: answer,
    answerType: answerType,
    audioUrl: audioUrl,
    videoUrl: videoUrl,
    voice: voice,
  );

  Future<MediaAudioResult> uploadAudio(
    int sessionId, {
    required String filePath,
    required String filename,
  }) => _api.uploadAudio(sessionId, filePath: filePath, filename: filename);

  Future<String> uploadVideo(
    int sessionId, {
    required String filePath,
    required String filename,
  }) => _api.uploadVideo(sessionId, filePath: filePath, filename: filename);

  Future<InterviewReportM?> reportDetail(int id) => _api.reportDetail(id);

  Future<List<ReportQuestionDetailM>> reportQuestions(int id) =>
      _api.reportQuestions(id);

  Future<InterviewReportM?> generateReport(int sessionId) =>
      _api.generateReport(sessionId);

  Future<List<int>> downloadReportPdf(int reportId) =>
      _api.downloadReportPdf(reportId);

  Future<List<JobProfileM>> jobProfileList() => _api.jobProfileList();

  Future<void> createJobProfile({
    required String industry,
    required String jobName,
    required String city,
    required String salary,
    bool isDefault = false,
  }) => _api.createJobProfile(
    industry: industry,
    jobName: jobName,
    city: city,
    salary: salary,
    isDefault: isDefault,
  );

  Future<void> updateJobProfile({
    required int id,
    required String industry,
    required String jobName,
    required String city,
    required String salary,
    bool isDefault = false,
  }) => _api.updateJobProfile(
    id: id,
    industry: industry,
    jobName: jobName,
    city: city,
    salary: salary,
    isDefault: isDefault,
  );

  Future<void> deleteJobProfile(int id) => _api.deleteJobProfile(id);
}
