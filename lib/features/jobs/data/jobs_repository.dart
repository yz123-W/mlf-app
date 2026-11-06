import 'jobs_api.dart';
import 'jobs_models.dart';

/// 岗位仓库：直连接口，不吞异常（由 UI 捕获展示错误与重试）。
class JobsRepository {
  const JobsRepository(this._api);

  final JobsApi _api;

  Future<(List<JobSummary>, int)> jobList({
    int pageNum = 1,
    int pageSize = 10,
    String? keyword,
    String? industry,
    String? city,
    String? jobKeyword,
  }) => _api.jobList(
    pageNum: pageNum,
    pageSize: pageSize,
    keyword: keyword,
    industry: industry,
    city: city,
    jobKeyword: jobKeyword,
  );

  Future<JobSummary> jobDetail(int id) => _api.jobDetail(id);

  Future<String> apply(int jobId, {int? resumeId}) =>
      _api.apply(jobId, resumeId: resumeId);

  Future<(List<JobApplication>, int)> myApplications({
    int pageNum = 1,
    int pageSize = 10,
  }) => _api.myApplications(pageNum: pageNum, pageSize: pageSize);

  Future<void> withdraw(int applicationId) => _api.withdraw(applicationId);

  Future<(List<InviteItem>, int)> inviteList({
    int pageNum = 1,
    int pageSize = 10,
  }) => _api.inviteList(pageNum: pageNum, pageSize: pageSize);

  Future<void> acceptInvite(int id) => _api.acceptInvite(id);

  Future<void> rejectInvite(int id) => _api.rejectInvite(id);

  Future<List<ResumeBrief>> resumeList() => _api.resumeList();
}
