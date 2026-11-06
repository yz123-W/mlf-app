import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'questions_api.dart';
import 'questions_models.dart';
import 'questions_repository.dart';

final questionsApiProvider = Provider<QuestionsApi>(
  (ref) => QuestionsApi(ref.watch(apiClientProvider)),
);

final questionsRepositoryProvider = Provider<QuestionsRepository>(
  (ref) => QuestionsRepository(ref.watch(questionsApiProvider)),
);

/// 筛选项查询键：按「行业 + 题型」分层统计题数。
typedef QuestionOptionsQuery = ({String? industry, String? type});

/// 筛选项（行业 / 题型 / 技能方向 / 难度）。
///
/// 行业计数为全库口径；题型随行业统计，技能方向与难度随「行业 + 题型」统计，
/// 与 Web 学生端题库页的层级联动规则一致。
final questionOptionsProvider =
    FutureProvider.family<QuestionOptions, QuestionOptionsQuery>(
  (ref, query) => ref
      .watch(questionsRepositoryProvider)
      .options(industry: query.industry, type: query.type),
);

/// 高频真题库专场。
final questionPacksProvider = FutureProvider<List<QuestionPack>>(
  (ref) => ref.watch(questionsRepositoryProvider).packs(),
);

/// 题目详情。
final questionDetailProvider = FutureProvider.family<Question, int>(
  (ref, id) => ref.watch(questionsRepositoryProvider).detail(id),
);

/// 当前用户收藏的题目ID集合，支持乐观更新与失败回滚。
class FavoriteIdsNotifier extends AsyncNotifier<Set<int>> {
  @override
  Future<Set<int>> build() =>
      ref.watch(questionsRepositoryProvider).favoriteIds();

  /// 切换收藏状态：先改本地状态让星标立即响应，请求失败再回滚。
  Future<void> toggle(int questionId) async {
    final current = state.asData?.value ?? const <int>{};
    final favorited = current.contains(questionId);
    final next = {...current};
    if (favorited) {
      next.remove(questionId);
    } else {
      next.add(questionId);
    }
    state = AsyncData(next);
    try {
      final repo = ref.read(questionsRepositoryProvider);
      if (favorited) {
        await repo.unfavorite(questionId);
      } else {
        await repo.favorite(questionId);
      }
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

final favoriteIdsProvider =
    AsyncNotifierProvider<FavoriteIdsNotifier, Set<int>>(FavoriteIdsNotifier.new);
