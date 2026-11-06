import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlf_app/core/async/polling_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('启动立即执行一次，并按间隔轮询；停止后不再请求', () {
    fakeAsync((async) {
      var ticks = 0;
      final controller = PollingController(
        interval: const Duration(milliseconds: 100),
        onTick: () async => ticks++,
      );

      controller.start();
      async.elapse(Duration.zero);
      expect(ticks, 1);

      async.elapse(const Duration(milliseconds: 300));
      expect(ticks, 4);

      controller.stop();
      async.elapse(const Duration(seconds: 5));
      expect(ticks, 4);
      expect(controller.isRunning, isFalse);

      controller.dispose();
    });
  });

  test('onTick 失败按 2^n 退避，且不超过 maxBackoff', () {
    fakeAsync((async) {
      var ticks = 0;
      final controller = PollingController(
        interval: const Duration(milliseconds: 100),
        maxBackoff: const Duration(milliseconds: 300),
        onTick: () async {
          ticks++;
          throw Exception('boom');
        },
      );

      controller.start();
      async.elapse(Duration.zero);
      expect(ticks, 1);

      // 第一次失败退避 200ms
      async.elapse(const Duration(milliseconds: 199));
      expect(ticks, 1);
      async.elapse(const Duration(milliseconds: 1));
      expect(ticks, 2);

      // 第二次失败退避 400ms，被上限压到 300ms
      async.elapse(const Duration(milliseconds: 299));
      expect(ticks, 2);
      async.elapse(const Duration(milliseconds: 1));
      expect(ticks, 3);

      // 第三次失败仍按上限 300ms
      async.elapse(const Duration(milliseconds: 299));
      expect(ticks, 3);
      async.elapse(const Duration(milliseconds: 1));
      expect(ticks, 4);

      controller.dispose();
    });
  });

  test('切后台暂停请求，回前台立即恢复', () {
    fakeAsync((async) {
      var ticks = 0;
      final controller = PollingController(
        interval: const Duration(milliseconds: 100),
        onTick: () async => ticks++,
      );

      controller.start();
      async.elapse(Duration.zero);
      expect(ticks, 1);

      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      async.elapse(const Duration(seconds: 5));
      expect(ticks, 1);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      async.elapse(Duration.zero);
      expect(ticks, 2);

      async.elapse(const Duration(milliseconds: 100));
      expect(ticks, 3);

      controller.dispose();
    });
  });

  test('超时回调并停止轮询', () {
    fakeAsync((async) {
      var ticks = 0;
      var timedOut = false;
      final controller = PollingController(
        interval: const Duration(seconds: 1),
        timeout: const Duration(seconds: 3),
        onTick: () async => ticks++,
        onTimeout: () => timedOut = true,
      );

      controller.start();
      async.elapse(Duration.zero);
      expect(ticks, 1);

      async.elapse(const Duration(seconds: 2));
      expect(ticks, 3);
      expect(timedOut, isFalse);

      async.elapse(const Duration(seconds: 1));
      expect(timedOut, isTrue);
      expect(controller.isRunning, isFalse);

      async.elapse(const Duration(minutes: 1));
      expect(ticks, 3);

      controller.dispose();
    });
  });
}
