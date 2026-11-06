/// 模拟面试模块模型（场次 / 题目 / 作答 / 报告 / 岗位画像）。
///
/// 契约来源：`mlf-stu` 的 `InterviewSessionController`(`/interview/session`)、
/// `InterviewQuestionController`(`/interview/question`)、`InterviewQaController`(`/interview/qa`)、
/// `InterviewReportController`(`/interview/report`)、`StudentJobProfileController`(`/interview/jobprofile`)。
library;

import 'dart:convert';

/// 字典值域 → 中文标签（与后端 `readConverterExp` 对齐）。
class InterviewDict {
  InterviewDict._();

  /// 场次状态：0未开始 1进行中 2已完成 3已中断。
  static String sessionStatus(String? code) => switch (code) {
    '0' => '未开始',
    '1' => '进行中',
    '2' => '已完成',
    '3' => '已中断',
    _ => '未知',
  };

  /// 行业（与岗位侧 industry_type 字典一致）：
  /// 1互联网 2金融 3制造业 4教育培训 5文化娱乐 6人工智能 7通用 8企业服务。
  static String industry(String? code) => switch (code) {
    '1' => '互联网',
    '2' => '金融',
    '3' => '制造业',
    '4' => '教育培训',
    '5' => '文化娱乐',
    '6' => '人工智能',
    '7' => '通用',
    '8' => '企业服务',
    _ => code ?? '',
  };

  /// 难度：1初级 2中级 3高级。
  static String difficulty(String? code) => switch (code) {
    '1' => '初级',
    '2' => '中级',
    '3' => '高级',
    _ => code ?? '',
  };

  /// 题型：1行为面 2技术面 3HR面 4case面。
  static String questionType(String? code) => switch (code) {
    '1' => '行为面',
    '2' => '技术面',
    '3' => 'HR面',
    '4' => '案例面',
    _ => code ?? '',
  };

  /// 报告生成状态：0待生成 1生成中 2成功 3失败。
  static String generateStatus(String? code) => switch (code) {
    '0' => '待生成',
    '1' => '生成中',
    '2' => '生成成功',
    '3' => '生成失败',
    _ => '未知',
  };
}

/// 学生岗位画像（`/interview/jobprofile/list` 的 `rows[]`）。
class JobProfileM {
  const JobProfileM({
    required this.id,
    this.industry = '',
    this.jobName = '',
    this.city = '',
    this.salary = '',
    this.difficulty = '',
    this.companyType = '',
    this.isDefault = false,
    this.status = '0',
  });

  final int id;

  /// 行业码 1–5，空串表示行业不限。
  final String industry;
  final String jobName;

  /// 工作城市，多选时以逗号分隔；空串表示不限。
  final String city;

  /// 薪资要求；空串表示不限。
  final String salary;

  /// 难度码 1–3（岗位画像已不再让用户选择，保留字段兼容旧数据）。
  final String difficulty;

  /// 目标企业类型码 1–4。
  final String companyType;
  final bool isDefault;
  final String status;

  factory JobProfileM.fromJson(Map<String, dynamic> json) => JobProfileM(
    id: _asInt(json['id']),
    industry: _asString(json['industry']),
    jobName: _asString(json['jobName']),
    city: _asString(json['city']),
    salary: _asString(json['salary']),
    difficulty: _asString(json['difficulty']),
    companyType: _asString(json['companyType']),
    isDefault: json['isDefault'] == '1' || json['isDefault'] == 1,
    status: _asString(json['status']),
  );

  /// 城市列表（多选存储为逗号分隔）。
  List<String> get cities => city
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  /// 列表卡片 / 面试页回填使用的中文摘要。
  String get summary => [
    jobName.isEmpty ? '职位不限' : jobName,
    city.isEmpty ? '城市不限' : cities.join('、'),
    salary.isEmpty ? '薪资不限' : salary,
    industry.isEmpty ? '行业不限' : InterviewDict.industry(industry),
  ].join(' · ');
}

/// 模拟面试场次（`interview_session`）。
class InterviewSessionM {
  const InterviewSessionM({
    required this.id,
    this.sessionNo = '',
    this.jobProfileId,
    this.industry = '',
    this.jobName = '',
    this.difficulty = '',
    this.questionType = '',
    this.interviewType = '1',
    this.totalCount = 0,
    this.answeredCount = 0,
    this.status = '',
    this.score,
    this.startTime,
    this.endTime,
    this.duration = 0,
    this.reportId,
  });

  final int id;
  final String sessionNo;
  final int? jobProfileId;
  final String industry;
  final String jobName;
  final String difficulty;

  /// 多选题型，英文逗号拼接。
  final String questionType;

  /// 面试形式：1文字 2语音 3视频。
  final String interviewType;
  final int totalCount;
  final int answeredCount;

  /// 0未开始 1进行中 2已完成 3已中断。
  final String status;
  final double? score;
  final DateTime? startTime;
  final DateTime? endTime;

  /// 面试时长（秒）。
  final int duration;
  final int? reportId;

  factory InterviewSessionM.fromJson(Map<String, dynamic> json) =>
      InterviewSessionM(
        id: _asInt(json['id']),
        sessionNo: _asString(json['sessionNo']),
        jobProfileId: _asNullableInt(json['jobProfileId']),
        industry: _asString(json['industry']),
        jobName: _asString(json['jobName']),
        difficulty: _asString(json['difficulty']),
        questionType: _asString(json['questionType']),
        interviewType: _asString(json['interviewType'], fallback: '1'),
        totalCount: _asInt(json['totalCount']),
        answeredCount: _asInt(json['answeredCount']),
        status: _asString(json['status']),
        score: _asDouble(json['score']),
        startTime: _asDateTime(json['startTime']),
        endTime: _asDateTime(json['endTime']),
        duration: _asInt(json['duration']),
        reportId: _asNullableInt(json['reportId']),
      );

  /// 未开始（AI 出题中）。
  bool get pending => status == '0';
  bool get ongoing => status == '1';
  bool get finished => status == '2';

  /// 题型标签列表。
  List<String> get questionTypeLabels => questionType
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .map(InterviewDict.questionType)
      .toList();

  /// 语音 / 视频面试场次：走对话式 chat 流程。
  bool get isVoice => interviewType == '2';
  bool get isVideo => interviewType == '3';
  bool get isMedia => isVoice || isVideo;
}

/// 对话式面试一轮结果（`/interview/session/{id}/chat` 的 `data`）。
class ChatReply {
  const ChatReply({
    this.aiMessage = '',
    this.questionAudioUrl,
    this.answeredCount = 0,
    this.totalCount = 0,
    this.mainQuestionCount = 0,
    this.questionNo = 0,
    this.followUpNo = 0,
    this.finished = false,
  });

  final String aiMessage;

  /// 语音/视频场次：AI 题面的 TTS 音频地址（相对路径，可能为空）。
  final String? questionAudioUrl;
  final int answeredCount;
  final int totalCount;
  final int mainQuestionCount;
  final int questionNo;
  final int followUpNo;
  final bool finished;

  factory ChatReply.fromJson(Map<String, dynamic> json) => ChatReply(
    aiMessage: _asString(json['aiMessage']),
    questionAudioUrl: _asNullableString(json['questionAudioUrl']),
    answeredCount: _asInt(json['answeredCount']),
    totalCount: _asInt(json['totalCount']),
    mainQuestionCount: _asInt(json['mainQuestionCount']),
    questionNo: _asInt(json['questionNo']),
    followUpNo: _asInt(json['followUpNo']),
    finished: json['finished'] == true || json['finished'] == 'true',
  );
}

/// 语音上传识别结果（`/interview/session/{id}/audio` 的 `data`）。
class MediaAudioResult {
  const MediaAudioResult({this.audioUrl = '', this.text = ''});

  final String audioUrl;
  final String text;

  factory MediaAudioResult.fromJson(Map<String, dynamic> json) =>
      MediaAudioResult(
        audioUrl: _asString(json['audioUrl']),
        text: _asString(json['text']),
      );
}

/// AI 出题状态（`/interview/session/{id}/generate-status` 的 `data`）。
class GenerateStatusM {
  const GenerateStatusM({
    this.status = 'running',
    this.message = '',
    this.questionCount = 0,
  });

  /// running / ready / failed。
  final String status;
  final String message;
  final int questionCount;

  factory GenerateStatusM.fromJson(Map<String, dynamic> json) =>
      GenerateStatusM(
        status: _asString(json['status'], fallback: 'running'),
        message: _asString(json['message']),
        questionCount: _asInt(json['questionCount']),
      );

  bool get ready => status == 'ready';
  bool get failed => status == 'failed';
}

/// 面试题目（`interview_question`）。
class InterviewQuestionM {
  const InterviewQuestionM({
    required this.id,
    this.sessionId = 0,
    this.questionNo = 0,
    this.questionType = '',
    this.questionContent = '',
    this.referenceAnswer = '',
    this.keyPoints = const [],
    this.isFollowUp = false,
    this.source = '',
  });

  final int id;
  final int sessionId;
  final int questionNo;

  /// 1行为面 2技术面 3HR面 4case面。
  final String questionType;
  final String questionContent;
  final String referenceAnswer;

  /// 关键要点（JSON 数组解析结果）。
  final List<String> keyPoints;
  final bool isFollowUp;

  /// 1AI生成 2题库抽取 3简历解析。
  final String source;

  factory InterviewQuestionM.fromJson(Map<String, dynamic> json) =>
      InterviewQuestionM(
        id: _asInt(json['id']),
        sessionId: _asInt(json['sessionId']),
        questionNo: _asInt(json['questionNo']),
        questionType: _asString(json['questionType']),
        questionContent: _asString(json['questionContent']),
        referenceAnswer: _asString(json['referenceAnswer']),
        keyPoints: _asTextList(json['keyPoints']),
        isFollowUp: json['isFollowUp'] == '1' || json['isFollowUp'] == 1,
        source: _asString(json['source']),
      );
}

/// 面试作答记录（`interview_qa`）。
class InterviewQaM {
  const InterviewQaM({
    required this.id,
    this.sessionId = 0,
    this.questionId = 0,
    this.questionContent = '',
    this.answerContent = '',
    this.answerType = '1',
    this.duration = 0,
    this.score,
    this.aiComment = '',
    this.audioUrl,
  });

  final int id;
  final int sessionId;
  final int questionId;
  final String questionContent;
  final String answerContent;

  /// 1文字 2语音 3视频。
  final String answerType;
  final int duration;
  final double? score;
  final String aiComment;

  /// 语音/视频场次：题面 TTS 音频（AI 消息）或作答录音地址。
  final String? audioUrl;

  factory InterviewQaM.fromJson(Map<String, dynamic> json) => InterviewQaM(
    id: _asInt(json['id']),
    sessionId: _asInt(json['sessionId']),
    questionId: _asInt(json['questionId']),
    questionContent: _asString(json['questionContent']),
    answerContent: _asString(json['answerContent']),
    answerType: _asString(json['answerType']),
    duration: _asInt(json['duration']),
    score: _asDouble(json['score']),
    aiComment: _asString(json['aiComment']),
    audioUrl: _asNullableString(json['audioUrl']),
  );
}

/// `/interview/qa/submit` 的响应：作答记录 + 最新场次状态。
class QaSubmitResult {
  const QaSubmitResult({this.answer, this.session});

  final InterviewQaM? answer;
  final InterviewSessionM? session;
}

/// 复盘报告（`interview_report`，含联表展示字段）。
class InterviewReportM {
  const InterviewReportM({
    required this.id,
    this.reportNo = '',
    this.sessionId = 0,
    this.totalScore,
    this.scoreCompleteness,
    this.scoreLogic,
    this.scoreFluency,
    this.scoreDepth,
    this.scoreConfidence,
    this.summary = '',
    this.weakPoints = const [],
    this.suggest = '',
    this.pdfUrl = '',
    this.generateStatus = '',
    this.sessionNo = '',
    this.jobName = '',
    this.startTime,
  });

  final int id;
  final String reportNo;
  final int sessionId;
  final double? totalScore;
  final double? scoreCompleteness;
  final double? scoreLogic;
  final double? scoreFluency;
  final double? scoreDepth;
  final double? scoreConfidence;
  final String summary;

  /// 薄弱点（JSON 数组解析结果）。
  final List<String> weakPoints;
  final String suggest;
  final String pdfUrl;

  /// 0待生成 1生成中 2成功 3失败。
  final String generateStatus;

  // 联表只读展示字段
  final String sessionNo;
  final String jobName;
  final DateTime? startTime;

  factory InterviewReportM.fromJson(Map<String, dynamic> json) =>
      InterviewReportM(
        id: _asInt(json['id']),
        reportNo: _asString(json['reportNo']),
        sessionId: _asInt(json['sessionId']),
        totalScore: _asDouble(json['totalScore']),
        scoreCompleteness: _asDouble(json['scoreCompleteness']),
        scoreLogic: _asDouble(json['scoreLogic']),
        scoreFluency: _asDouble(json['scoreFluency']),
        scoreDepth: _asDouble(json['scoreDepth']),
        scoreConfidence: _asDouble(json['scoreConfidence']),
        summary: _asString(json['summary']),
        weakPoints: _asTextList(json['weakPoints']),
        suggest: _asString(json['suggest']),
        pdfUrl: _asString(json['pdfUrl']),
        generateStatus: _asString(json['generateStatus']),
        sessionNo: _asString(json['sessionNo']),
        jobName: _asString(json['jobName']),
        startTime: _asDateTime(json['startTime']),
      );

  /// 五维分值（顺序：完整性 / 逻辑性 / 流畅度 / 深度 / 自信度）。
  List<double> get fiveDimensions => [
    scoreCompleteness ?? 0,
    scoreLogic ?? 0,
    scoreFluency ?? 0,
    scoreDepth ?? 0,
    scoreConfidence ?? 0,
  ];

  static const List<String> dimensionLabels = [
    '完整性',
    '逻辑性',
    '流畅度',
    '深度',
    '自信度',
  ];

  /// 报告是否已生成（可导出 PDF）。
  bool get generated => generateStatus == '2';
}

/// 报告逐题明细（`/interview/report/{id}/questions` 的 `data[]`）。
class ReportQuestionDetailM {
  const ReportQuestionDetailM({
    this.questionNo = 0,
    this.questionType = '',
    this.questionContent = '',
    this.myAnswer,
    this.referenceAnswer = '',
    this.score,
    this.comment = '',
    this.answered = false,
    this.keyPoints = const [],
  });

  final int questionNo;
  final String questionType;
  final String questionContent;
  final String? myAnswer;
  final String referenceAnswer;
  final double? score;
  final String comment;
  final bool answered;
  final List<KeyPointM> keyPoints;

  factory ReportQuestionDetailM.fromJson(Map<String, dynamic> json) =>
      ReportQuestionDetailM(
        questionNo: _asInt(json['questionNo']),
        questionType: _asString(json['questionType']),
        questionContent: _asString(json['questionContent']),
        myAnswer: _asNullableString(json['myAnswer']),
        referenceAnswer: _asString(json['referenceAnswer']),
        score: _asDouble(json['score']),
        comment: _asString(json['comment']),
        answered: json['answered'] == true,
        keyPoints: _asKeyPoints(json['keyPoints']),
      );
}

/// 关键要点命中情况。
class KeyPointM {
  const KeyPointM({this.text = '', this.hit = false});

  final String text;
  final bool hit;

  factory KeyPointM.fromJson(Map<String, dynamic> json) =>
      KeyPointM(text: _asString(json['text']), hit: json['hit'] == true);
}

// ---------------------------------------------------------------- 解析工具

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

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String _asString(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

String? _asNullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

DateTime? _asDateTime(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return DateTime.tryParse(text) ??
      DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

/// 把 JSON 数组字符串（或已是 List）解析为文本列表；元素可能是字符串或含 text 的对象。
List<String> _asTextList(Object? value) {
  if (value == null) return const [];
  Object? decoded = value;
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return const [];
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      // 非 JSON：按分隔符拆分兜底
      return text
          .split(RegExp(r'[、,，;；|/]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }
  if (decoded is List) {
    return decoded.map(_asText).where((e) => e.isNotEmpty).toList();
  }
  return const [];
}

String _asText(Object? item) {
  if (item == null) return '';
  if (item is String) return item;
  if (item is Map) {
    for (final key in const [
      'text',
      'name',
      'desc',
      'content',
      'label',
      'value',
    ]) {
      final v = item[key];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }
  return item.toString();
}

/// keyPoints 解析：兼容 `[{text,hit}]` 与纯字符串数组（后者视为未命中）。
List<KeyPointM> _asKeyPoints(Object? value) {
  if (value == null) return const [];
  Object? decoded = value;
  if (value is String) {
    if (value.trim().isEmpty) return const [];
    try {
      decoded = jsonDecode(value);
    } catch (_) {
      return _asTextList(value).map((e) => KeyPointM(text: e)).toList();
    }
  }
  if (decoded is List) {
    return decoded
        .map((e) {
          if (e is Map) return KeyPointM.fromJson(Map<String, dynamic>.from(e));
          return KeyPointM(text: _asText(e));
        })
        .where((e) => e.text.isNotEmpty)
        .toList();
  }
  return const [];
}
