import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'message_models.dart';

/// 消息中心接口（`/interview/message/*`）。
class MessageApi {
  const MessageApi(this._client);

  final ApiClient _client;

  /// 消息概览（系统未读 + 企业会话列表）。
  Future<MessageOverview> overview() async {
    final res = await _client.getJson('/interview/message/overview');
    final data = res['data'];
    if (data is Map) return MessageOverview.fromJson(Map<String, dynamic>.from(data));
    return const MessageOverview();
  }

  /// 系统通知列表（返回明细 + 顶层 `unreadCount`）。
  Future<(List<SystemMessage>, int)> systemList() async {
    final res = await _client.getJson('/interview/message/system/list');
    final data = res['data'];
    final list = data is List
        ? data.whereType<Map>().map((e) => SystemMessage.fromJson(Map<String, dynamic>.from(e))).toList()
        : <SystemMessage>[];
    return (list, _asInt(res['unreadCount']));
  }

  /// 单条系统通知标为已读。
  Future<void> readSystem({required String msgType, required int refId}) async {
    await _client.postJson(
      '/interview/message/system/read?msgType=$msgType&refId=$refId',
    );
  }

  /// 全部系统通知标为已读。
  Future<void> readAllSystem() async {
    await _client.postJson('/interview/message/system/read-all');
  }

  /// 企业会话消息列表。
  Future<ChatDetail> chatList(int talentId, {CancelToken? cancelToken}) async {
    final res = await _client.getJson(
      '/interview/message/chat/list',
      query: {'talentId': talentId},
      cancelToken: cancelToken,
    );
    final data = res['data'];
    if (data is Map) return ChatDetail.fromJson(Map<String, dynamic>.from(data));
    return const ChatDetail();
  }

  /// 发送会话消息。
  Future<void> sendChat({required int talentId, required String content}) async {
    await _client.postJson(
      '/interview/message/chat/send',
      data: {'talentId': talentId, 'content': content},
    );
  }

  /// 会话标为已读。
  Future<void> readChat(int talentId) async {
    await _client.postJson('/interview/message/chat/read', data: {'talentId': talentId});
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
