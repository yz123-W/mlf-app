import '../../../core/network/api_client.dart';
import '../../../shared/utils/json.dart';
import 'jobs_models.dart';

/// 岗位 / 投递 / 邀约接口（`/interview/job|invite|resume`）。
class JobsApi {
  const JobsApi(this._client);

  final ApiClient _client;

  /// 在招岗位分页列表（支持关键词搜索；可携带默认目标岗位画像做推荐置顶）。
  ///
  /// [industry]、[city]、[jobKeyword] 来自默认画像；为空表示该维度「不限」，
  /// 后端按命中维度计分并把匹配岗位排前，命中结果回显在 `recommended`。
  Future<(List<JobSummary>, int)> jobList({
    int pageNum = 1,
    int pageSize = 10,
    String? keyword,
    String? industry,
    String? city,
    String? jobKeyword,
  }) async {
    final res = await _client.getJson(
      '/interview/job/list',
      query: {
        'pageNum': pageNum,
        'pageSize': pageSize,
        if (_notEmpty(keyword)) 'keyword': keyword,
        if (_notEmpty(industry)) 'industry': industry,
        if (_notEmpty(city)) 'city': city,
        if (_notEmpty(jobKeyword)) 'jobKeyword': jobKeyword,
      },
    );
    return (rowsOf(res).map(JobSummary.fromJson).toList(), _total(res));
  }

  /// 岗位详情。
  Future<JobSummary> jobDetail(int id) async {
    final res = await _client.getJson('/interview/job/$id');
    return JobSummary.fromJson(_dataMap(res));
  }

  /// 投递（`resumeId` 可选；后端返回业务提示文案）。
  Future<String> apply(int jobId, {int? resumeId}) async {
    final path = resumeId == null
        ? '/interview/job/apply/$jobId'
        : '/interview/job/apply/$jobId?resumeId=$resumeId';
    final res = await _client.postJson(path);
    final msg = res['msg']?.toString();
    return (msg == null || msg.isEmpty) ? '投递成功，请等待企业查看' : msg;
  }

  /// 我的投递分页列表。
  Future<(List<JobApplication>, int)> myApplications({
    int pageNum = 1,
    int pageSize = 10,
  }) async {
    final res = await _client.getJson(
      '/interview/job/applications',
      query: {'pageNum': pageNum, 'pageSize': pageSize},
    );
    return (rowsOf(res).map(JobApplication.fromJson).toList(), _total(res));
  }

  /// 撤回投递。
  Future<void> withdraw(int applicationId) async {
    await _client.postJson(
      '/interview/job/applications/$applicationId/withdraw',
    );
  }

  /// 面试邀约分页列表。
  Future<(List<InviteItem>, int)> inviteList({
    int pageNum = 1,
    int pageSize = 10,
  }) async {
    final res = await _client.getJson(
      '/interview/invite/list',
      query: {'pageNum': pageNum, 'pageSize': pageSize},
    );
    return (rowsOf(res).map(InviteItem.fromJson).toList(), _total(res));
  }

  /// 接受邀约。
  Future<void> acceptInvite(int id) async {
    await _client.postJson('/interview/invite/$id/accept');
  }

  /// 拒绝邀约。
  Future<void> rejectInvite(int id) async {
    await _client.postJson('/interview/invite/$id/reject');
  }

  /// 简历列表（权限未确认，失败时静默返回空，投递改走默认简历）。
  Future<List<ResumeBrief>> resumeList() async {
    try {
      final res = await _client.getJson(
        '/interview/resume/list',
        query: {'pageNum': 1, 'pageSize': 50},
      );
      return rowsOf(res).map(ResumeBrief.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  // ------------------------------------------------------------------ 解析

  int _total(Map<String, dynamic> res) {
    final total = res['total'];
    if (total is int) return total;
    if (total is num) return total.toInt();
    return int.tryParse('$total') ?? 0;
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  bool _notEmpty(String? value) => value != null && value.trim().isNotEmpty;
}
