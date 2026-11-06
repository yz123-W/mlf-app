import 'questions_api.dart';
import 'questions_models.dart';

/// 题库仓库：仅做接口转发，便于后续加入本地缓存 / 收藏等端能力。
class QuestionsRepository {
  const QuestionsRepository(this._api);

  final QuestionsApi _api;

  Future<QuestionPage> list({
    int pageNum = 1,
    int pageSize = 10,
    String? type,
    String? industry,
    String? difficulty,
    int? skillFamilyId,
    String? keyword,
    int? packId,
  }) =>
      _api.list(
        pageNum: pageNum,
        pageSize: pageSize,
        type: type,
        industry: industry,
        difficulty: difficulty,
        skillFamilyId: skillFamilyId,
        keyword: keyword,
        packId: packId,
      );

  Future<QuestionOptions> options({String? industry, String? type}) =>
      _api.options(industry: industry, type: type);

  Future<List<QuestionPack>> packs() => _api.packs();

  Future<Question> detail(int id) => _api.detail(id);

  Future<Set<int>> favoriteIds() => _api.favoriteIds();

  Future<void> favorite(int questionId) => _api.favorite(questionId);

  Future<void> unfavorite(int questionId) => _api.unfavorite(questionId);

  Future<QuestionPage> favoriteList({int pageNum = 1, int pageSize = 10}) =>
      _api.favoriteList(pageNum: pageNum, pageSize: pageSize);
}
