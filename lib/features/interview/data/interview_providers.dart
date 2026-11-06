import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'interview_api.dart';
import 'interview_models.dart';
import 'interview_repository.dart';

final interviewApiProvider = Provider<InterviewApi>(
  (ref) => InterviewApi(ref.watch(apiClientProvider)),
);

final interviewRepositoryProvider = Provider<InterviewRepository>(
  (ref) => InterviewRepository(ref.watch(interviewApiProvider)),
);

/// 当前学生的岗位画像列表（面试定制页回填用）。
final jobProfileListProvider = FutureProvider<List<JobProfileM>>(
  (ref) => ref.watch(interviewRepositoryProvider).jobProfileList(),
);

/// 面试历史（建场 / 提前结束后用 `ref.invalidate` 刷新）。
final sessionHistoryProvider = FutureProvider<List<InterviewSessionM>>(
  (ref) => ref.watch(interviewRepositoryProvider).sessionList(pageSize: 10),
);

/// 场次详情。
final sessionDetailProvider = FutureProvider.family<InterviewSessionM, int>(
  (ref, id) => ref.watch(interviewRepositoryProvider).sessionDetail(id),
);

/// 本场题目。
final sessionQuestionsProvider =
    FutureProvider.family<List<InterviewQuestionM>, int>(
      (ref, sessionId) =>
          ref.watch(interviewRepositoryProvider).questionList(sessionId),
    );

/// 本场已提交的作答（进入时回填）。
final sessionAnswersProvider = FutureProvider.family<List<InterviewQaM>, int>(
  (ref, sessionId) => ref.watch(interviewRepositoryProvider).qaList(sessionId),
);

/// 报告详情。
final reportDetailProvider = FutureProvider.family<InterviewReportM?, int>(
  (ref, id) => ref.watch(interviewRepositoryProvider).reportDetail(id),
);

/// 报告逐题明细。
final reportQuestionsProvider =
    FutureProvider.family<List<ReportQuestionDetailM>, int>(
      (ref, id) => ref.watch(interviewRepositoryProvider).reportQuestions(id),
    );
