import '../../../core/network/api_client.dart';
import '../../../shared/utils/json.dart';
import 'home_models.dart';

/// 首页数据接口：积分概览 / 最近报告 / 岗位推荐。
class HomeApi {
  const HomeApi(this._client);

  final ApiClient _client;

  /// 积分概览（对象接口，取 `data`）。
  Future<PointsOverview> pointsOverview() async {
    final res = await _client.getJson('/interview/points/overview');
    final data = res['data'];
    if (data is Map) {
      return PointsOverview.fromJson(Map<String, dynamic>.from(data));
    }
    return const PointsOverview(
      points: 0,
      level: '面试小白',
      levelProgress: 0,
      pointsToNext: 0,
      topLevel: false,
    );
  }

  /// 今日打卡（幂等，重复调用不报错）。
  Future<void> checkin() async {
    await _client.postJson('/interview/checkin');
  }

  /// 打卡概览（对象接口，取 `data`）。
  Future<CheckinSummary> checkinSummary() async {
    final res = await _client.getJson('/interview/checkin/summary');
    final data = res['data'];
    if (data is Map) {
      return CheckinSummary.fromJson(Map<String, dynamic>.from(data));
    }
    return const CheckinSummary();
  }

  /// 最近报告（分页接口，取 `rows`）。
  Future<List<InterviewReportItem>> recentReports({int limit = 3}) async {
    final res = await _client.getJson(
      '/interview/report/list',
      query: {'pageNum': 1, 'pageSize': limit},
    );
    return rowsOf(res).map(InterviewReportItem.fromJson).toList();
  }

  /// 推荐岗位（分页接口，取 `rows`）。
  Future<List<JobItem>> recommendJobs({int limit = 3}) async {
    final res = await _client.getJson(
      '/interview/job/list',
      query: {'pageNum': 1, 'pageSize': limit},
    );
    return rowsOf(res).map(JobItem.fromJson).toList();
  }
}
