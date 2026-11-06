/// 首页仪表盘数据模型（积分概览 / 最近报告 / 推荐岗位）。
///
/// 契约来源：`mlf-stu` 的 `StudentPointsController`(`/interview/points/overview`)、
/// `InterviewReportController`(`/interview/report/list`)、
/// `StudentJobController`(`/interview/job/list`)。
library;

/// 积分概览（`/interview/points/overview` 的 `data`）。
class PointsOverview {
  const PointsOverview({
    required this.points,
    required this.level,
    required this.levelProgress,
    this.nextLevel,
    required this.pointsToNext,
    required this.topLevel,
  });

  /// 当前累计积分。
  final int points;

  /// 当前等级名称（如「渐入佳境」）。
  final String level;

  /// 当前等级内进度百分比（0–100）。
  final int levelProgress;

  /// 下一等级名称；已满级时为 null。
  final String? nextLevel;

  /// 距离下一等级还差多少分；已满级为 0。
  final int pointsToNext;

  /// 是否已满级。
  final bool topLevel;

  factory PointsOverview.fromJson(Map<String, dynamic> json) => PointsOverview(
        points: _asInt(json['points']),
        level: _asString(json['level']),
        levelProgress: _asInt(json['levelProgress']),
        nextLevel: _asNullableString(json['nextLevel']),
        pointsToNext: _asInt(json['pointsToNext']),
        topLevel: json['topLevel'] == true,
      );
}

/// 复盘报告列表行（`/interview/report/list` 的 `rows[]`）。
class InterviewReportItem {
  const InterviewReportItem({
    required this.id,
    required this.jobName,
    this.sessionId,
    this.totalScore,
    this.startTime,
    this.generateStatus = '',
  });

  final int id;

  /// 关联场次 id（重新生成报告用）。
  final int? sessionId;

  /// 关联场次岗位名（取自 interview_session.job_name）。
  final String jobName;

  /// 总分。
  final double? totalScore;

  /// 场次开始时间。
  final DateTime? startTime;

  /// 生成状态：0 待生成 / 1 生成中 / 2 成功 / 3 失败。
  final String generateStatus;

  factory InterviewReportItem.fromJson(Map<String, dynamic> json) => InterviewReportItem(
        id: _asInt(json['id']),
        sessionId: json['sessionId'] == null ? null : _asInt(json['sessionId']),
        jobName: _asString(json['jobName']),
        totalScore: _asDouble(json['totalScore']),
        startTime: _asDateTime(json['startTime']),
        generateStatus: _asString(json['generateStatus']),
      );

  String get generateLabel => switch (generateStatus) {
        '0' => '待生成',
        '1' => '生成中',
        '2' => '已生成',
        '3' => '生成失败',
        _ => '已生成',
      };
}

/// 打卡概览（`/interview/checkin/summary` 的 `data`）。
class CheckinSummary {
  const CheckinSummary({
    this.todayChecked = false,
    this.continuousDays = 0,
    this.totalDays = 0,
    this.recentDays = const [],
  });

  final bool todayChecked;
  final int continuousDays;
  final int totalDays;

  /// 近 30 天已打卡日期（`yyyy-MM-dd`，升序）。
  final List<String> recentDays;

  factory CheckinSummary.fromJson(Map<String, dynamic> json) => CheckinSummary(
        todayChecked: json['todayChecked'] == true || json['todayChecked'] == '1',
        continuousDays: _asInt(json['continuousDays']),
        totalDays: _asInt(json['totalDays']),
        recentDays: (json['recentDays'] is List)
            ? (json['recentDays'] as List).map((e) => e.toString()).toList()
            : const [],
      );
}

/// 在招岗位（`/interview/job/list` 的 `rows[]`）。
class JobItem {
  const JobItem({
    required this.id,
    required this.jobName,
    this.industry = '',
    this.tenantName = '',
    this.workLocation = '',
    this.recruitCount,
    this.applied = false,
  });

  final int id;
  final String jobName;
  final String industry;

  /// 企业名称（联表 sys_tenant）。
  final String tenantName;
  final String workLocation;
  final int? recruitCount;

  /// 当前学生是否已投递。
  final bool applied;

  factory JobItem.fromJson(Map<String, dynamic> json) => JobItem(
        id: _asInt(json['id']),
        jobName: _asString(json['jobName']),
        industry: _asString(json['industry']),
        tenantName: _asString(json['tenantName']),
        workLocation: _asString(json['workLocation']),
        recruitCount: json['recruitCount'] == null ? null : _asInt(json['recruitCount']),
        applied: json['applied'] == '1' || json['applied'] == 1,
      );
}

/// 首页聚合结果。
class HomeDashboard {
  const HomeDashboard({
    this.points,
    this.checkin,
    required this.reports,
    required this.jobs,
  });

  /// 积分概览；接口异常时为 null。
  final PointsOverview? points;

  /// 打卡概览；接口异常时为 null。
  final CheckinSummary? checkin;
  final List<InterviewReportItem> reports;
  final List<JobItem> jobs;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String _asString(Object? value) => value?.toString() ?? '';

String? _asNullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

DateTime? _asDateTime(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString()) ??
      DateTime.tryParse(value.toString().replaceFirst(' ', 'T'));
}
