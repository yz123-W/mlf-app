import '../../../core/network/api_client.dart';
import 'feedback_models.dart';

/// 学生反馈接口（`/interview/feedback`）：提交 + 查看本人反馈。
class FeedbackApi {
  const FeedbackApi(this._client);

  final ApiClient _client;

  /// 提交反馈（后端限制每自然日 5 条）。
  Future<void> submit({required String content, String source = '学生端 App'}) =>
      _client.postJson(
        '/interview/feedback',
        data: {'source': source, 'content': content},
      );

  /// 我的反馈列表（仅本人，按提交时间倒序，含运营处理结果）。
  Future<List<FeedbackItem>> myFeedback() async {
    final res = await _client.getJson('/interview/feedback/my');
    final data = res['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => FeedbackItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }
}
