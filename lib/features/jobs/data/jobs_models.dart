/// 岗位 / 投递 / 邀约数据模型。
///
/// 契约来源：`mlf-stu` 的 `StudentJobController`(`/interview/job/*`)、
/// `StudentInviteController`(`/interview/invite/*`)、`StudentResumeController`(`/interview/resume/*`)。
library;

/// 在招岗位（`/interview/job/list`、`/interview/job/{id}`）。
class JobSummary {
  const JobSummary({
    required this.id,
    this.tenantId = 0,
    this.jobName = '',
    this.industry = '',
    this.tenantName = '',
    this.workLocation = '',
    this.recruitCount,
    this.publishDate = '',
    this.status = '',
    this.applied = false,
    this.applyStatus = '',
    this.recommended = 0,
  });

  final int id;
  final int tenantId;
  final String jobName;
  final String industry;

  /// 企业名称（联表 sys_tenant）。
  final String tenantName;
  final String workLocation;
  final int? recruitCount;

  /// 发布时间（后端为字符串日期）。
  final String publishDate;

  /// 岗位状态（0=在招 等，回退显示原码）。
  final String status;

  /// 当前学生是否已投递。
  final bool applied;

  /// 投递状态（后端回显）。
  final String applyStatus;

  /// 与默认目标岗位画像的命中维度数（0=不匹配）。
  final int recommended;

  /// 是否命中目标画像（用于「推荐」角标）。
  bool get isRecommended => recommended > 0;

  factory JobSummary.fromJson(Map<String, dynamic> json) => JobSummary(
    id: _asInt(json['id']),
    tenantId: _asInt(json['tenantId']),
    jobName: _asString(json['jobName']),
    industry: _asString(json['industry']),
    tenantName: _asString(json['tenantName']),
    workLocation: _asString(json['workLocation']),
    recruitCount: json['recruitCount'] == null
        ? null
        : _asInt(json['recruitCount']),
    publishDate: _asString(json['publishDate']),
    status: _asString(json['status']),
    applied: json['applied'] == '1' || json['applied'] == 1,
    applyStatus: _asString(json['applyStatus']),
    recommended: json['recommended'] == null ? 0 : _asInt(json['recommended']),
  );

  /// 行业展示文案（本地映射，回退原码）。
  String get industryText => _industryLabel(industry);
}

/// 我的投递（`/interview/job/applications` 的 `rows[]`）。
class JobApplication {
  const JobApplication({
    required this.id,
    this.jobId = 0,
    this.resumeId,
    this.status = '',
    this.applyTime,
    this.viewTime,
    this.withdrawTime,
    this.jobName = '',
    this.workLocation = '',
    this.tenantName = '',
    this.inviteId,
    this.inviteStatus = '',
  });

  final int id;
  final int jobId;
  final int? resumeId;

  /// 投递状态：submitted / viewed / withdrawn / …
  final String status;

  final DateTime? applyTime;
  final DateTime? viewTime;
  final DateTime? withdrawTime;
  final String jobName;
  final String workLocation;
  final String tenantName;

  /// 关联邀约 ID（为空表示企业尚未发出邀约）。
  final int? inviteId;
  final String inviteStatus;

  factory JobApplication.fromJson(Map<String, dynamic> json) => JobApplication(
    id: _asInt(json['id']),
    jobId: _asInt(json['jobId']),
    resumeId: json['resumeId'] == null ? null : _asInt(json['resumeId']),
    status: _asString(json['status']),
    applyTime: _asDateTime(json['applyTime']),
    viewTime: _asDateTime(json['viewTime']),
    withdrawTime: _asDateTime(json['withdrawTime']),
    jobName: _asString(json['jobName']),
    workLocation: _asString(json['workLocation']),
    tenantName: _asString(json['tenantName']),
    inviteId: json['inviteId'] == null ? null : _asInt(json['inviteId']),
    inviteStatus: _asString(json['inviteStatus']),
  );

  bool get canWithdraw => status == 'submitted' || status == 'viewed';

  String get statusText => _applicationStatusLabel(status);
}

/// 面试邀约（`/interview/invite/list` 的 `rows[]`）。
class InviteItem {
  const InviteItem({
    required this.id,
    this.jobId,
    this.jobNameSnapshot = '',
    this.inviteType = '',
    this.questionNames = '',
    this.meetingUrl = '',
    this.questionTypes = '',
    this.scheduledTime,
    this.expireTime,
    this.attemptNo,
    this.status = '',
    this.tenantName = '',
    this.sessionId,
    this.reportId,
  });

  final int id;
  final int? jobId;
  final String jobNameSnapshot;

  /// 邀约类型："0"=真人面试 / "1"=AI 面试。
  final String inviteType;
  final String questionNames;
  final String meetingUrl;
  final String questionTypes;
  final DateTime? scheduledTime;
  final DateTime? expireTime;
  final int? attemptNo;

  /// pending / accepted / rejected / expired / completed / cancelled
  final String status;
  final String tenantName;
  final int? sessionId;
  final int? reportId;

  factory InviteItem.fromJson(Map<String, dynamic> json) => InviteItem(
    id: _asInt(json['id']),
    jobId: json['jobId'] == null ? null : _asInt(json['jobId']),
    jobNameSnapshot: _asString(json['jobNameSnapshot']),
    inviteType: _asString(json['inviteType']),
    questionNames: _asString(json['questionNames']),
    meetingUrl: _asString(json['meetingUrl']),
    questionTypes: _asString(json['questionTypes']),
    scheduledTime: _asDateTime(json['scheduledTime']),
    expireTime: _asDateTime(json['expireTime']),
    attemptNo: json['attemptNo'] == null ? null : _asInt(json['attemptNo']),
    status: _asString(json['status']),
    tenantName: _asString(json['tenantName']),
    sessionId: json['sessionId'] == null ? null : _asInt(json['sessionId']),
    reportId: json['reportId'] == null ? null : _asInt(json['reportId']),
  );

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';

  String get typeText =>
      inviteType == '1' ? 'AI 面试' : (inviteType == '0' ? '真人面试' : '面试邀约');

  String get statusText => _inviteStatusLabel(status);
}

/// 简历摘要（`/interview/resume/list` 的 `rows[]`）。
class ResumeBrief {
  const ResumeBrief({
    required this.id,
    this.resumeName = '',
    this.isDefault = false,
  });

  final int id;
  final String resumeName;
  final bool isDefault;

  factory ResumeBrief.fromJson(Map<String, dynamic> json) => ResumeBrief(
    id: _asInt(json['id']),
    resumeName: _asString(json['resumeName']),
    isDefault: json['isDefault'] == '1' || json['isDefault'] == 1,
  );

  String get displayName => resumeName.isNotEmpty ? resumeName : '简历 #$id';
}

// ------------------------------------------------------------------ 字典映射

/// 岗位行业码映射（与后端 `industry_type` 字典一致）。
String _industryLabel(String raw) {
  switch (raw) {
    case '1':
      return '互联网';
    case '2':
      return '金融';
    case '3':
      return '制造业';
    case '4':
      return '教育培训';
    case '5':
      return '文化娱乐';
    case '6':
      return '人工智能';
    case '7':
      return '通用';
    case '8':
      return '企业服务';
    default:
      return raw;
  }
}

String _applicationStatusLabel(String raw) {
  switch (raw) {
    case 'submitted':
      return '已投递';
    case 'viewed':
      return '企业已查看';
    case 'withdrawn':
      return '已撤回';
    case 'invited':
      return '已邀约';
    case 'rejected':
      return '未通过';
    default:
      return raw.isEmpty ? '已投递' : raw;
  }
}

String _inviteStatusLabel(String raw) {
  switch (raw) {
    case 'pending':
      return '待处理';
    case 'accepted':
      return '已接受';
    case 'rejected':
      return '已拒绝';
    case 'expired':
      return '已过期';
    case 'completed':
      return '已完成';
    case 'cancelled':
      return '已取消';
    default:
      return raw.isEmpty ? '待处理' : raw;
  }
}

// ------------------------------------------------------------------ 解析工具

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

String _asString(Object? value) => value?.toString() ?? '';

DateTime? _asDateTime(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return DateTime.tryParse(text) ??
      DateTime.tryParse(text.replaceFirst(' ', 'T'));
}
