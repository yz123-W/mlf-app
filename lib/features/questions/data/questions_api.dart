import '../../../core/network/api_client.dart';
import 'questions_models.dart';

/// 题库接口（`/interview/bank/*`，学生端只读）。
///
/// 列表与筛选项参数与 Web 学生端题库页保持一致：
/// `industry` / `type` / `difficulty` 精确匹配分类名称，`skillFamilyId` 按技能方向过滤，
/// `keyword` 同时模糊匹配题号与题干，`packId` 按专场过滤。
class QuestionsApi {
  const QuestionsApi(this._client);

  final ApiClient _client;

  /// 题目分页列表。
  Future<QuestionPage> list({
    int pageNum = 1,
    int pageSize = 10,
    String? type,
    String? industry,
    String? difficulty,
    int? skillFamilyId,
    String? keyword,
    int? packId,
  }) async {
    final res = await _client.getJson(
      '/interview/bank/list',
      query: {
        'pageNum': pageNum,
        'pageSize': pageSize,
        if (_notEmpty(type)) 'type': type,
        if (_notEmpty(industry)) 'industry': industry,
        if (_notEmpty(difficulty)) 'difficulty': difficulty,
        'skillFamilyId': ?skillFamilyId,
        if (_notEmpty(keyword)) 'keyword': keyword,
        'packId': ?packId,
      },
    );
    return QuestionPage.fromJson(res);
  }

  /// 筛选项（行业 / 题型 / 技能方向带题数，难度为取值列表）。
  ///
  /// `industry` 与 `type` 用于分层统计：题型随行业变化，技能方向与难度随「行业 + 题型」变化。
  Future<QuestionOptions> options({String? industry, String? type}) async {
    final res = await _client.getJson(
      '/interview/bank/options',
      query: {
        if (_notEmpty(industry)) 'industry': industry,
        if (_notEmpty(type)) 'type': type,
      },
    );
    final data = res['data'];
    if (data is Map) {
      return QuestionOptions.fromJson(Map<String, dynamic>.from(data));
    }
    return const QuestionOptions();
  }

  /// 高频真题库专场列表。
  Future<List<QuestionPack>> packs() async {
    final res = await _client.getJson('/interview/bank/packs');
    final data = res['data'];
    if (data is List) {
      return data.whereType<Map>().map((e) => QuestionPack.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    return const [];
  }

  /// 题目详情（含参考答案 / 维度 / 追问）。
  Future<Question> detail(int id) async {
    final res = await _client.getJson('/interview/bank/$id');
    final data = res['data'];
    if (data is Map) {
      return Question.fromJson(Map<String, dynamic>.from(data));
    }
    return Question(id: id);
  }

  /// 当前用户收藏的题目ID集合。
  Future<Set<int>> favoriteIds() async {
    final res = await _client.getJson('/interview/favorite/ids');
    final data = res['data'];
    if (data is List) {
      return data.whereType<num>().map((e) => e.toInt()).toSet();
    }
    return <int>{};
  }

  /// 收藏题目（后端幂等）。
  Future<void> favorite(int questionId) async {
    await _client.postJson('/interview/favorite/$questionId');
  }

  /// 取消收藏。
  Future<void> unfavorite(int questionId) async {
    await _client.deleteJson('/interview/favorite/$questionId');
  }

  /// 收藏题目分页列表（只含上架题目）。
  Future<QuestionPage> favoriteList({int pageNum = 1, int pageSize = 10}) async {
    final res = await _client.getJson(
      '/interview/favorite/list',
      query: {'pageNum': pageNum, 'pageSize': pageSize},
    );
    return QuestionPage.fromJson(res);
  }

  static bool _notEmpty(String? value) => value != null && value.trim().isNotEmpty;
}
