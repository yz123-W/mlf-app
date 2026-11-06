import 'home_api.dart';
import 'home_models.dart';

/// 首页仓库：并行聚合积分 / 报告 / 岗位。
///
/// 任一分项失败不阻断整页（对应项降级为空 / null），仅在全部失败时向上抛错。
class HomeRepository {
  const HomeRepository(this._api);

  final HomeApi _api;

  Future<HomeDashboard> loadDashboard() async {
    // 打卡（幂等）与四个首屏接口并行，省掉一次串行等待；打卡失败不阻断首页。
    final results = await Future.wait<Object?>([
      _safeCheckin(),
      _guard<PointsOverview?>(_api.pointsOverview, null),
      _guard<CheckinSummary?>(_api.checkinSummary, null),
      _guard<List<InterviewReportItem>>(_api.recentReports, const []),
      _guard<List<JobItem>>(_api.recommendJobs, const []),
    ]);

    final points = results[1] as PointsOverview?;
    final checkin = results[2] as CheckinSummary?;
    final reports = results[3] as List<InterviewReportItem>;
    final jobs = results[4] as List<JobItem>;

    // 全部为空时视为整页失败，交由 UI 展示错误并提供重试。
    if (points == null && checkin == null && reports.isEmpty && jobs.isEmpty) {
      throw Exception('首页数据加载失败');
    }
    return HomeDashboard(
      points: points,
      checkin: checkin,
      reports: reports,
      jobs: jobs,
    );
  }

  /// 打卡是幂等的，失败只忽略，不影响首页其余数据。
  Future<void> _safeCheckin() async {
    try {
      await _api.checkin();
    } catch (_) {}
  }

  Future<T> _guard<T>(Future<T> Function() run, T fallback) async {
    try {
      return await run();
    } catch (_) {
      return fallback;
    }
  }
}
