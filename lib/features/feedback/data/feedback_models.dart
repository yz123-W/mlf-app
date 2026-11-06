/// 学生反馈工单模型。
///
/// 契约来源：`mlf-stu` 的 `StudentFeedbackController`(`/interview/feedback`)。
class FeedbackItem {
  const FeedbackItem({
    required this.id,
    this.source = '',
    this.content = '',
    this.status = '',
    this.handleBy = '',
    this.handleRemark = '',
    this.handleTime = '',
    this.submitTime = '',
  });

  final int id;

  /// 来源模块（提交时由前端按所在页面带入）。
  final String source;

  /// 反馈内容。
  final String content;

  /// 状态：待处理 / 已解决 / 已忽略。
  final String status;

  /// 处理人。
  final String handleBy;

  /// 处理备注。
  final String handleRemark;

  /// 处理时间（后端已格式化为 yyyy-MM-dd HH:mm）。
  final String handleTime;

  /// 提交时间。
  final String submitTime;

  bool get isPending => status == '待处理';

  bool get isResolved => status == '已解决' || status == '已忽略';

  factory FeedbackItem.fromJson(Map<String, dynamic> json) => FeedbackItem(
    id: _asInt(json['id']),
    source: _asString(json['source']),
    content: _asString(json['content']),
    status: _asString(json['status']),
    handleBy: _asString(json['handleBy']),
    handleRemark: _asString(json['handleRemark']),
    handleTime: _asString(json['handleTime']),
    submitTime: _asString(json['submitTime']),
  );
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

String _asString(Object? value) => value?.toString() ?? '';
