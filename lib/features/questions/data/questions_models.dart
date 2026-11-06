/// 运营公共题库模型（学生端只读）。
///
/// 契约来源：`mlf-stu` 的 `PublicQuestionController`(`/interview/bank/*`)
/// 与 `BizQuestion` / `BizQuestionPack` 领域对象；
/// 筛选项结构与 Web 学生端题库页保持一致（行业 / 题型 / 技能方向带题数）。
library;

import '../../../shared/utils/json.dart';

/// 题库题目。列表接口只回列表所需字段，详情接口补齐 `answer` / `dimensions` / `followup`。
class Question {
  const Question({
    required this.id,
    this.questionNo = '',
    this.type = '',
    this.industry = '',
    this.difficulty = '',
    this.content = '',
    this.answer,
    this.dimensions,
    this.followup,
    this.packId,
    this.skillNames = const [],
  });

  final int id;
  final String questionNo;

  /// 题型（运营端分类体系中文名）。
  final String type;

  /// 行业。
  final String industry;

  /// 难度。
  final String difficulty;

  /// 题目正文。
  final String content;

  /// 参考答案（仅详情）。
  final String? answer;

  /// 考核维度，后端以分隔符拼接的文本（仅详情）。
  final String? dimensions;

  /// 追问预设（仅详情）。
  final String? followup;

  /// 归属专场ID（可为空）。
  final int? packId;

  /// 考点标签（`biz_question_skill` 关联的技能标签名称）。
  final List<String> skillNames;

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: asInt(json['id']),
        questionNo: asString(json['questionNo']),
        type: asString(json['type']),
        industry: asString(json['industry']),
        difficulty: asString(json['difficulty']),
        content: asString(json['content']),
        answer: asNullableString(json['answer']),
        dimensions: asNullableString(json['dimensions']),
        followup: asNullableString(json['followup']),
        packId: json['packId'] == null ? null : asInt(json['packId']),
        skillNames: _asStringList(json['skillNames']),
      );

  /// 拆分为标签列表（维度文本可能以顿号 / 逗号 / 分隔符拼接）。
  List<String> get dimensionTags {
    final raw = dimensions;
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(RegExp(r'[、,，;；|/]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

/// 带题数的分类筛选项（行业 / 题型）。
class NameCountOption {
  const NameCountOption({required this.name, this.count = 0});

  final String name;
  final int count;

  factory NameCountOption.fromJson(Map<String, dynamic> json) => NameCountOption(
        name: asString(json['name']),
        count: asInt(json['count']),
      );
}

/// 技能方向筛选项（带 `id` 与当前口径下的题数）。
class SkillFamilyOption {
  const SkillFamilyOption({required this.id, required this.name, this.count = 0});

  final int id;
  final String name;
  final int count;

  factory SkillFamilyOption.fromJson(Map<String, dynamic> json) => SkillFamilyOption(
        id: asInt(json['id']),
        name: asString(json['name']),
        count: asInt(json['count']),
      );
}

/// 题库筛选项（`/interview/bank/options` 的 `data`）。
///
/// 行业计数为全库口径（顶部行业页签用）；题型 / 技能方向 / 难度按
/// 当前「行业 + 题型」统计，切换上一层后题数随之变化。
class QuestionOptions {
  const QuestionOptions({
    this.industries = const [],
    this.types = const [],
    this.skillFamilies = const [],
    this.difficulties = const [],
  });

  final List<NameCountOption> industries;
  final List<NameCountOption> types;
  final List<SkillFamilyOption> skillFamilies;
  final List<String> difficulties;

  factory QuestionOptions.fromJson(Map<String, dynamic> json) => QuestionOptions(
        industries: asMapList(json['industries']).map(NameCountOption.fromJson).toList(),
        types: asMapList(json['types']).map(NameCountOption.fromJson).toList(),
        skillFamilies: asMapList(json['skillFamilies']).map(SkillFamilyOption.fromJson).toList(),
        difficulties: _asStringList(json['difficulties']),
      );
}

/// 高频真题库专场（`/interview/bank/packs` 的 `data[]`）。
class QuestionPack {
  const QuestionPack({
    required this.id,
    this.name = '',
    this.note = '',
    this.questionCount = 0,
  });

  final int id;
  final String name;

  /// 说明标签。
  final String note;

  /// 该专场下当前可见题目数。
  final int questionCount;

  factory QuestionPack.fromJson(Map<String, dynamic> json) => QuestionPack(
        id: asInt(json['id']),
        name: asString(json['name']),
        note: asString(json['note']),
        questionCount: asInt(json['questionCount']),
      );
}

/// 题库分页结果（TableDataInfo：`rows` / `total`）。
class QuestionPage {
  const QuestionPage({required this.items, required this.total});

  final List<Question> items;
  final int total;

  factory QuestionPage.fromJson(Map<String, dynamic> json) {
    final rows = json['rows'];
    final items = rows is List
        ? rows.whereType<Map>().map((e) => Question.fromJson(Map<String, dynamic>.from(e))).toList()
        : <Question>[];
    return QuestionPage(items: items, total: asInt(json['total']));
  }
}

List<String> _asStringList(Object? value) {
  if (value is List) {
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  return const [];
}
