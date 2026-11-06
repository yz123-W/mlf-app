/// 消息中心数据模型（`/interview/message/*`）。
library;

/// 消息概览（`/interview/message/overview` 的 `data`）。
class MessageOverview {
  const MessageOverview({
    this.systemUnread = 0,
    this.systemPreview,
    this.chats = const [],
  });

  final int systemUnread;
  final SystemPreview? systemPreview;
  final List<ChatSummary> chats;

  /// 未读总数 = 系统未读 + 各会话未读之和（我的页入口红点用）。
  int get unreadTotal => systemUnread + chats.fold<int>(0, (sum, c) => sum + c.unreadCount);

  factory MessageOverview.fromJson(Map<String, dynamic> json) {
    final preview = json['systemPreview'];
    final chats = json['chats'];
    return MessageOverview(
      systemUnread: _asInt(json['systemUnread']),
      systemPreview: preview is Map ? SystemPreview.fromJson(Map<String, dynamic>.from(preview)) : null,
      chats: chats is List
          ? chats.whereType<Map>().map((e) => ChatSummary.fromJson(Map<String, dynamic>.from(e))).toList()
          : const [],
    );
  }
}

/// 系统通知预览（概览内的 `systemPreview`）。
class SystemPreview {
  const SystemPreview({this.time = '', this.type = '', this.title = ''});

  final String time;

  /// invite / notice
  final String type;
  final String title;

  factory SystemPreview.fromJson(Map<String, dynamic> json) => SystemPreview(
        time: _asString(json['time']),
        type: _asString(json['type']),
        title: _asString(json['title']),
      );
}

/// 企业会话摘要（概览的 `chats[]`）。
class ChatSummary {
  const ChatSummary({
    required this.talentId,
    this.tenantName = '',
    this.positionName = '',
    this.unreadCount = 0,
    this.lastTime = '',
    this.lastContent = '',
    this.lastIsMine = false,
  });

  final int talentId;
  final String tenantName;
  final String positionName;
  final int unreadCount;
  final String lastTime;
  final String lastContent;

  /// 最后一条是否由本人发出（"1"=我）。
  final bool lastIsMine;

  factory ChatSummary.fromJson(Map<String, dynamic> json) => ChatSummary(
        talentId: _asInt(json['talentId']),
        tenantName: _asString(json['tenantName']),
        positionName: _asString(json['positionName']),
        unreadCount: _asInt(json['unreadCount']),
        lastTime: _asString(json['lastTime']),
        lastContent: _asString(json['lastContent']),
        lastIsMine: json['lastSender'] == '1' || json['lastSender'] == 1,
      );
}

/// 系统通知明细（`/interview/message/system/list` 的 `data[]`）。
class SystemMessage {
  const SystemMessage({
    this.type = '',
    required this.id,
    this.title = '',
    this.content = '',
    this.createTime,
    this.isRead = false,
    this.tenantName = '',
  });

  /// invite / notice
  final String type;
  final int id;
  final String title;
  final String content;
  final DateTime? createTime;
  final bool isRead;
  final String tenantName;

  SystemMessage copyWith({bool? isRead}) => SystemMessage(
        type: type,
        id: id,
        title: title,
        content: content,
        createTime: createTime,
        isRead: isRead ?? this.isRead,
        tenantName: tenantName,
      );

  factory SystemMessage.fromJson(Map<String, dynamic> json) => SystemMessage(
        type: _asString(json['type']),
        id: _asInt(json['id']),
        title: _asString(json['title']),
        content: _asString(json['content']),
        createTime: _asDateTime(json['createTime']),
        isRead: json['isRead'] == true || json['isRead'] == '1',
        tenantName: _asString(json['tenantName']),
      );
}

/// 会话详情（`/interview/message/chat/list` 的 `data`）。
class ChatDetail {
  const ChatDetail({this.talent = const {}, this.messages = const []});

  final Map<String, dynamic> talent;
  final List<ChatMessage> messages;

  String get tenantName => _asString(talent['tenantName']);
  String get positionName => _asString(talent['positionName']);

  factory ChatDetail.fromJson(Map<String, dynamic> json) {
    final talent = json['talent'];
    final messages = json['messages'];
    return ChatDetail(
      talent: talent is Map ? Map<String, dynamic>.from(talent) : const {},
      messages: messages is List
          ? messages.whereType<Map>().map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e))).toList()
          : const [],
    );
  }
}

/// 会话单条消息。
class ChatMessage {
  const ChatMessage({required this.id, this.isMine = false, this.content = '', this.createTime});

  final int id;

  /// 是否本人发出（"1"=我）。
  final bool isMine;
  final String content;
  final DateTime? createTime;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: _asInt(json['id']),
        isMine: json['sender'] == '1' || json['sender'] == 1,
        content: _asString(json['content']),
        createTime: _asDateTime(json['createTime']),
      );
}

// ------------------------------------------------------------------ 解析工具

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

String _asString(Object? value) => value?.toString() ?? '';

DateTime? _asDateTime(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return DateTime.tryParse(text) ?? DateTime.tryParse(text.replaceFirst(' ', 'T'));
}
