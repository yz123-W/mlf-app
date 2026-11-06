import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'message_api.dart';
import 'message_models.dart';
import 'message_repository.dart';

final messageApiProvider = Provider<MessageApi>(
  (ref) => MessageApi(ref.watch(apiClientProvider)),
);

final messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => MessageRepository(ref.watch(messageApiProvider)),
);

/// 消息概览（消息中心页 / 我的页红点共用；下拉刷新用 `ref.invalidate`）。
final messageOverviewProvider = FutureProvider<MessageOverview>(
  (ref) => ref.watch(messageRepositoryProvider).overview(),
);
