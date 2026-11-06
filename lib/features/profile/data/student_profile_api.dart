import '../../../core/network/api_client.dart';
import 'student_profile_models.dart';

/// 学生自助档案接口：只读写当前登录学生自己的档案。
class StudentProfileApi {
  const StudentProfileApi(this._client);

  final ApiClient _client;

  Future<StudentProfileM> getMyProfile() async {
    final res = await _client.getJson('/interview/profile/my');
    final data = res['data'];
    if (data is Map) {
      return StudentProfileM.fromJson(Map<String, dynamic>.from(data));
    }
    return const StudentProfileM();
  }

  /// 保存白名单字段；后端忽略等级 / 积分等系统字段。
  Future<void> updateMyProfile(StudentProfileM profile) =>
      _client.putJson('/interview/profile/my', data: profile.toEditableJson());
}

/// 档案仓库：直连接口，不吞异常（由 UI 捕获并展示）。
class StudentProfileRepository {
  const StudentProfileRepository(this._api);

  final StudentProfileApi _api;

  Future<StudentProfileM> getMyProfile() => _api.getMyProfile();

  Future<void> updateMyProfile(StudentProfileM profile) => _api.updateMyProfile(profile);
}
