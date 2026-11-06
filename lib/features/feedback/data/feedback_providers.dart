import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'feedback_api.dart';
import 'feedback_models.dart';

final feedbackApiProvider = Provider<FeedbackApi>(
  (ref) => FeedbackApi(ref.watch(apiClientProvider)),
);

/// 我的反馈列表（提交后 `ref.invalidate` 刷新）。
final myFeedbackProvider = FutureProvider<List<FeedbackItem>>(
  (ref) => ref.watch(feedbackApiProvider).myFeedback(),
);
