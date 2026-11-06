import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 会话失效事件：每次通知代表“需要重新登录”，根组件监听后统一跳转登录页。
final sessionExpiredProvider = NotifierProvider<SessionExpiredNotifier, int>(
  SessionExpiredNotifier.new,
);

/// 计数器每次自增，保证重复失效也能触发监听。
class SessionExpiredNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// 标记会话已失效。
  void notifyExpired() => state++;
}
