/// 学生端用户信息（`/getInfo` 的 user 字段）。
class StudentUser {
  const StudentUser({this.userId, required this.userName, required this.nickName});

  final int? userId;
  final String userName;
  final String nickName;

  factory StudentUser.fromJson(Map<String, dynamic> json) {
    final rawId = json['userId'];
    return StudentUser(
      userId: rawId is int ? rawId : int.tryParse('$rawId'),
      userName: (json['userName'] ?? '').toString(),
      nickName: (json['nickName'] ?? '').toString(),
    );
  }

  String get displayName => nickName.isNotEmpty ? nickName : userName;
}

/// 发送短信验证码结果（开发期 Mock 通道会回显 `mockCode`）。
class SmsSendResult {
  const SmsSendResult({required this.mock, this.mockCode});

  final bool mock;
  final String? mockCode;

  factory SmsSendResult.fromJson(Map<String, dynamic> json) => SmsSendResult(
        mock: json['mock'] == true,
        mockCode: json['mockCode']?.toString(),
      );
}

/// 短信验证码场景（后端按场景隔离，不可混用）。
class SmsScene {
  SmsScene._();

  static const String login = 'login';
  static const String register = 'register';
  static const String resetPwd = 'resetPwd';
}
