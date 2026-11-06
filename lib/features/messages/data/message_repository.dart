import 'package:dio/dio.dart';

import 'message_api.dart';
import 'message_models.dart';

/// 消息仓库：直连接口（概览失败时降级为空概览，避免阻断整页）。
class MessageRepository {
  const MessageRepository(this._api);

  final MessageApi _api;

  Future<MessageOverview> overview() => _api.overview();

  /// 概览的降级版本（我的页红点不因单点异常而阻断）。
  Future<MessageOverview> overviewOrEmpty() async {
    try {
      return await _api.overview();
    } catch (_) {
      return const MessageOverview();
    }
  }

  Future<(List<SystemMessage>, int)> systemList() => _api.systemList();

  Future<void> readSystem({required String msgType, required int refId}) =>
      _api.readSystem(msgType: msgType, refId: refId);

  Future<void> readAllSystem() => _api.readAllSystem();

  Future<ChatDetail> chatList(int talentId, {CancelToken? cancelToken}) =>
      _api.chatList(talentId, cancelToken: cancelToken);

  Future<void> sendChat({required int talentId, required String content}) =>
      _api.sendChat(talentId: talentId, content: content);

  Future<void> readChat(int talentId) => _api.readChat(talentId);
}
