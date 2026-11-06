/// 学生简历数据模型。
///
/// 契约来源：`mlf-stu` 的 `StudentResumeController`(`/interview/resume/*`)
/// 与 `CommonController`(`/common/upload`)。
library;

import 'dart:convert';

/// 简历（`/interview/resume/list` 的 `rows[]`）。
class ResumeItem {
  const ResumeItem({
    required this.id,
    this.resumeName = '',
    this.fileUrl = '',
    this.fileType = '',
    this.fileSize = 0,
    this.sourceType = '1',
    this.isDefault = false,
    this.parseStatus = '0',
    this.parseResult = '',
    this.parseTime,
    this.createTime,
  });

  final int id;
  final String resumeName;

  /// 相对地址（`/profile/upload/...`）或历史数据里的完整地址。
  final String fileUrl;
  final String fileType;
  final int fileSize;

  /// 来源：1=本地上传 2=拍照导入
  final String sourceType;

  /// 是否默认简历（投递时优先使用）。
  final bool isDefault;

  /// 解析状态：0 未解析 / 1 解析中 / 2 成功 / 3 失败
  final String parseStatus;

  /// AI 解析结果（JSON 字符串，结构见 [ResumeParsedResult]）。
  final String parseResult;

  final DateTime? parseTime;

  final DateTime? createTime;

  factory ResumeItem.fromJson(Map<String, dynamic> json) => ResumeItem(
        id: _asInt(json['id']),
        resumeName: _asString(json['resumeName']),
        fileUrl: _asString(json['fileUrl']),
        fileType: _asString(json['fileType']),
        fileSize: _asInt(json['fileSize']),
        sourceType: _asString(json['sourceType'], fallback: '1'),
        isDefault: json['isDefault'] == '1' || json['isDefault'] == 1,
        parseStatus: _asString(json['parseStatus'], fallback: '0'),
        parseResult: _asString(json['parseResult']),
        parseTime: _asDateTime(json['parseTime']),
        createTime: _asDateTime(json['createTime']),
      );

  /// 文件类型展示文案。
  String get typeLabel {
    final type = fileType.toUpperCase();
    return type.isEmpty ? '文件' : type;
  }

  /// 文件大小展示文案。
  String get sizeText {
    if (fileSize <= 0) return '大小未知';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(0)} KB';
    return '${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String get sourceText => sourceType == '2' ? '拍照导入' : '本地上传';

  /// 解析状态展示文案。
  String get parseLabel => switch (parseStatus) {
        '1' => '解析中',
        '2' => '已解析',
        '3' => '解析失败',
        _ => '未解析',
      };
}

/// `/interview/resume/{id}/parse` 的解析状态（字段在响应顶层）。
class ResumeParseStatusM {
  const ResumeParseStatusM({required this.id, this.parseStatus = '0', this.parseResult = ''});

  final int id;
  final String parseStatus;
  final String parseResult;

  factory ResumeParseStatusM.fromJson(Map<String, dynamic> json) => ResumeParseStatusM(
        id: _asInt(json['id']),
        parseStatus: _asString(json['parseStatus'], fallback: '0'),
        parseResult: _asString(json['parseResult']),
      );

  bool get parsing => parseStatus == '1';
  bool get success => parseStatus == '2';
  bool get failed => parseStatus == '3';
}

/// `/common/upload` 的响应。
class UploadedResumeFile {
  const UploadedResumeFile({
    required this.fileName,
    required this.originalFilename,
    this.url = '',
  });

  /// 后端相对路径（存库用）。
  final String fileName;
  final String originalFilename;
  final String url;
}

/// AI 简历解析结果（`parseResult` JSON 字符串反序列化）。
class ResumeParsedResult {
  const ResumeParsedResult({
    this.name = '',
    this.gender = '',
    this.phone = '',
    this.email = '',
    this.school = '',
    this.major = '',
    this.education = '',
    this.graduationYear = '',
    this.skills = const [],
    this.workExperiences = const [],
    this.projectExperiences = const [],
    this.summary = '',
    this.overallEvaluation = '',
    this.suggestions = const [],
  });

  final String name;
  final String gender;
  final String phone;
  final String email;
  final String school;
  final String major;
  final String education;
  final String graduationYear;
  final List<String> skills;
  final List<ResumeExperience> workExperiences;
  final List<ResumeExperience> projectExperiences;
  final String summary;
  final String overallEvaluation;
  final List<String> suggestions;

  /// 解析失败或结构异常时返回 null（UI 走空态）。
  static ResumeParsedResult? tryParse(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      return ResumeParsedResult(
        name: _asString(map['name']),
        gender: _asString(map['gender']),
        phone: _asString(map['phone']),
        email: _asString(map['email']),
        school: _asString(map['school']),
        major: _asString(map['major']),
        education: _asString(map['education']),
        graduationYear: _asString(map['graduationYear']),
        skills: _asStringList(map['skills']),
        workExperiences: _asExperienceList(map['workExperiences']),
        projectExperiences: _asExperienceList(map['projectExperiences']),
        summary: _asString(map['summary']),
        overallEvaluation: _asString(map['overallEvaluation']),
        suggestions: _asStringList(map['suggestions']),
      );
    } catch (_) {
      return null;
    }
  }
}

/// 解析结果中的一段经历（工作 / 项目）。
class ResumeExperience {
  const ResumeExperience({
    this.company = '',
    this.position = '',
    this.period = '',
    this.description = '',
  });

  final String company;
  final String position;
  final String period;
  final String description;

  factory ResumeExperience.fromJson(Map<String, dynamic> json) => ResumeExperience(
        company: _asString(json['company']),
        position: _asString(json['position']),
        period: _asString(json['period']),
        description: _asString(json['description']),
      );
}

List<String> _asStringList(Object? value) {
  if (value is List) {
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

List<ResumeExperience> _asExperienceList(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((e) => ResumeExperience.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  return const [];
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

String _asString(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

DateTime? _asDateTime(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
