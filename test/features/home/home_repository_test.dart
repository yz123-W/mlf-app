import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mlf_app/core/network/api_client.dart';
import 'package:mlf_app/features/home/data/home_api.dart';
import 'package:mlf_app/features/home/data/home_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late HomeRepository repository;

  setUp(() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'http://mock.local',
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    adapter = DioAdapter(dio: dio);
    repository = HomeRepository(HomeApi(ApiClient(dio)));
  });

  void mockCheckin({bool ok = true}) {
    adapter.onPost(
      '/interview/checkin',
      (server) => server.reply(
        200,
        ok ? {'code': 200, 'msg': 'ok'} : {'code': 500, 'msg': '打卡失败'},
      ),
    );
  }

  void mockPoints({bool ok = true}) {
    adapter.onGet(
      '/interview/points/overview',
      (server) => server.reply(
        200,
        ok
            ? {
                'code': 200,
                'data': {
                  'points': 120,
                  'level': '渐入佳境',
                  'levelProgress': 60,
                  'nextLevel': '游刃有余',
                  'pointsToNext': 80,
                  'topLevel': false,
                },
              }
            : {'code': 500, 'msg': '积分服务异常'},
      ),
    );
  }

  void mockSummary({bool ok = true}) {
    adapter.onGet(
      '/interview/checkin/summary',
      (server) => server.reply(
        200,
        ok
            ? {
                'code': 200,
                'data': {
                  'todayChecked': true,
                  'continuousDays': 3,
                  'totalDays': 10,
                  'recentDays': ['2026-11-02', '2026-11-03'],
                },
              }
            : {'code': 500, 'msg': '打卡概览异常'},
      ),
    );
  }

  void mockReports({bool ok = true}) {
    adapter.onGet(
      '/interview/report/list',
      (server) => server.reply(
        200,
        ok
            ? {
                'code': 200,
                'total': 1,
                'rows': [
                  {
                    'id': 7,
                    'jobName': 'Java 后端',
                    'totalScore': 82.5,
                    'generateStatus': '2',
                  }
                ],
              }
            : {'code': 500, 'msg': '报告服务异常'},
      ),
    );
  }

  void mockJobs({bool ok = true}) {
    adapter.onGet(
      '/interview/job/list',
      (server) => server.reply(
        200,
        ok
            ? {'code': 200, 'total': 0, 'rows': <Map<String, dynamic>>[]}
            : {'code': 500, 'msg': '岗位服务异常'},
      ),
    );
  }

  test('单个接口失败时降级，其余数据正常返回', () async {
    mockCheckin();
    mockPoints(ok: false);
    mockSummary();
    mockReports();
    mockJobs();

    final dashboard = await repository.loadDashboard();

    expect(dashboard.points, isNull);
    expect(dashboard.checkin?.continuousDays, 3);
    expect(dashboard.reports.single.jobName, 'Java 后端');
    expect(dashboard.jobs, isEmpty);
  });

  test('打卡失败不阻断首页', () async {
    mockCheckin(ok: false);
    mockPoints();
    mockSummary();
    mockReports();
    mockJobs();

    final dashboard = await repository.loadDashboard();

    expect(dashboard.points?.points, 120);
    expect(dashboard.checkin?.todayChecked, isTrue);
    expect(dashboard.reports, hasLength(1));
  });

  test('全部接口失败时向上抛错', () async {
    mockCheckin(ok: false);
    mockPoints(ok: false);
    mockSummary(ok: false);
    mockReports(ok: false);
    mockJobs(ok: false);

    await expectLater(
      repository.loadDashboard(),
      throwsA(isA<Exception>()),
    );
  });
}
