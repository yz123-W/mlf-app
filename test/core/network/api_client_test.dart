import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mlf_app/core/network/api_client.dart';
import 'package:mlf_app/core/network/api_exception.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'http://mock.local',
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    adapter = DioAdapter(dio: dio);
  });

  test('非 JSON 响应（404 HTML）抛格式异常，不再返回空 Map', () async {
    adapter.onGet('/missing', (server) {
      server.reply(
        404,
        '<html>404 not found</html>',
        headers: {'content-type': ['text/html']},
      );
    });
    final client = ApiClient(dio);

    await expectLater(
      client.getJson('/missing'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 404)
            .having((e) => e.message, 'message', contains('服务返回格式异常')),
      ),
    );
  });

  test('JSON 正常响应仍按 RuoYi 信封返回', () async {
    adapter.onGet('/ok', (server) {
      server.reply(200, {'code': 200, 'msg': 'ok', 'data': {'id': 1}});
    });
    final client = ApiClient(dio);

    final res = await client.getJson('/ok');
    expect(res['code'], 200);
    expect(res['data'], {'id': 1});
  });

  test('getBytes 401 触发全局登出并抛出 ApiException', () async {
    var unauthorized = 0;
    adapter.onGet('/report.pdf', (server) {
      server.reply(
        401,
        Uint8List.fromList([1, 2, 3]),
        headers: {'content-type': ['application/octet-stream']},
      );
    });
    final client = ApiClient(dio, onUnauthorized: () => unauthorized++);

    await expectLater(
      client.getBytes('/report.pdf'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 401)),
    );
    expect(unauthorized, 1);
  });

  test('getBytes 静默模式不触发全局登出', () async {
    var unauthorized = 0;
    adapter.onGet('/quiet.pdf', (server) {
      server.reply(
        401,
        Uint8List.fromList([1, 2, 3]),
        headers: {'content-type': ['application/octet-stream']},
      );
    });
    final client = ApiClient(dio, onUnauthorized: () => unauthorized++);

    await expectLater(
      client.getBytes('/quiet.pdf', handleUnauthorized: false),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 401)),
    );
    expect(unauthorized, 0);
  });

  test('getBytes 4xx 抛下载失败并带状态码', () async {
    adapter.onGet('/gone.pdf', (server) {
      server.reply(
        404,
        '<html>404</html>',
        headers: {'content-type': ['text/html']},
      );
    });
    final client = ApiClient(dio);

    await expectLater(
      client.getBytes('/gone.pdf'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 404)
            .having((e) => e.message, 'message', contains('文件下载失败')),
      ),
    );
  });

  test('getBytes 200 返回二进制内容', () async {
    adapter.onGet('/file.bin', (server) {
      server.reply(
        200,
        Uint8List.fromList([9, 8, 7]),
        headers: {'content-type': ['application/octet-stream']},
      );
    });
    final client = ApiClient(dio);

    final bytes = await client.getBytes('/file.bin');
    expect(bytes, [9, 8, 7]);
  });
}
