/// 学生自助档案模型。
///
/// 契约来源：`mlf-stu` 的 `StudentProfileController`(`/interview/my/profile`)。
class StudentProfileM {
  const StudentProfileM({
    this.id,
    this.nickname = '',
    this.avatar = '',
    this.realName = '',
    this.gender = '2',
    this.phone = '',
    this.email = '',
    this.school = '',
    this.major = '',
    this.education = '',
    this.graduationYear = '',
    this.currentLevel = '',
    this.currentPoints = 0,
    this.guideStatus = '0',
  });

  final int? id;
  final String nickname;
  final String avatar;
  final String realName;

  /// 0男 1女 2未知。
  final String gender;
  final String phone;
  final String email;
  final String school;
  final String major;

  /// 1专科 2本科 3硕士 4博士。
  final String education;
  final String graduationYear;

  /// 系统维护字段，只读展示。
  final String currentLevel;
  final int currentPoints;
  final String guideStatus;

  factory StudentProfileM.fromJson(Map<String, dynamic> json) => StudentProfileM(
        id: _asNullableInt(json['id']),
        nickname: _asString(json['nickname']),
        avatar: _asString(json['avatar']),
        realName: _asString(json['realName']),
        gender: _asString(json['gender'], fallback: '2'),
        phone: _asString(json['phone']),
        email: _asString(json['email']),
        school: _asString(json['school']),
        major: _asString(json['major']),
        education: _asString(json['education']),
        graduationYear: _asString(json['graduationYear']),
        currentLevel: _asString(json['currentLevel']),
        currentPoints: _asInt(json['currentPoints']),
        guideStatus: _asString(json['guideStatus'], fallback: '0'),
      );

  StudentProfileM copyWith({
    String? nickname,
    String? avatar,
    String? realName,
    String? gender,
    String? phone,
    String? email,
    String? school,
    String? major,
    String? education,
    String? graduationYear,
  }) =>
      StudentProfileM(
        id: id,
        nickname: nickname ?? this.nickname,
        avatar: avatar ?? this.avatar,
        realName: realName ?? this.realName,
        gender: gender ?? this.gender,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        school: school ?? this.school,
        major: major ?? this.major,
        education: education ?? this.education,
        graduationYear: graduationYear ?? this.graduationYear,
        currentLevel: currentLevel,
        currentPoints: currentPoints,
        guideStatus: guideStatus,
      );

  /// 提交字段白名单：系统维护字段永不提交。
  Map<String, dynamic> toEditableJson() => {
        'nickname': nickname,
        'avatar': avatar,
        'realName': realName,
        'gender': gender,
        'phone': phone,
        'email': email,
        'school': school,
        'major': major,
        'education': education,
        'graduationYear': graduationYear,
      };
}

/// 性别 / 学历字典展示。
class StudentProfileDict {
  StudentProfileDict._();

  static String gender(String? code) => switch (code) {
        '0' => '男',
        '1' => '女',
        _ => '未知',
      };

  static String education(String? code) => switch (code) {
        '1' => '专科',
        '2' => '本科',
        '3' => '硕士',
        '4' => '博士',
        _ => '',
      };
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

int? _asNullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String _asString(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}
