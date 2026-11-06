import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

/// 统一轮询控制器：可取消、失败退避、前后台感知。
///
/// 页面退出或切后台后不再发请求；回到前台立即执行一次再恢复轮询。
class PollingController with WidgetsBindingObserver {
  PollingController({
    required this.interval,
    required this.onTick,
    this.timeout,
    this.onTimeout,
    this.maxBackoff = const Duration(seconds: 10),
  });

  /// 正常轮询间隔。
  final Duration interval;

  /// 每次轮询执行的请求；抛异常时按 `interval * 2^n` 退避。
  final Future<void> Function() onTick;

  /// 从 [start] 起的总超时；到达后停止并回调 [onTimeout]。
  final Duration? timeout;

  final VoidCallback? onTimeout;

  /// 退避上限。
  final Duration maxBackoff;

  Timer? _timer;
  Timer? _timeoutTimer;
  CancelToken _cancelToken = CancelToken();
  bool _running = false;
  bool _disposed = false;
  int _failures = 0;

  /// 当前轮次使用的取消令牌，由调用方透传给接口。
  CancelToken get cancelToken => _cancelToken;

  bool get isRunning => _running;

  void start() {
    if (_disposed || _running) return;
    _running = true;
    _failures = 0;
    _cancelToken = CancelToken();
    WidgetsBinding.instance.addObserver(this);
    final limit = timeout;
    if (limit != null) _timeoutTimer = Timer(limit, _stopAndNotify);
    _schedule(Duration.zero);
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _cancelToken.cancel('polling stopped');
    _cancelToken = CancelToken();
    WidgetsBinding.instance.removeObserver(this);
  }

  void dispose() {
    if (_disposed) return;
    stop();
    _disposed = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _timer?.cancel();
      _timer = null;
    } else if (state == AppLifecycleState.resumed) {
      _schedule(Duration.zero);
    }
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    if (!_running) return;
    _timer = Timer(delay, _tick);
  }

  Future<void> _tick() async {
    if (!_running) return;
    try {
      await onTick();
      if (!_running) return;
      _failures = 0;
      _schedule(interval);
    } catch (_) {
      if (!_running) return;
      _failures++;
      _schedule(_backoff(_failures));
    }
  }

  Duration _backoff(int failures) {
    final multiplier = math.pow(2, failures).toInt();
    final ms = interval.inMilliseconds * multiplier;
    final cap = maxBackoff.inMilliseconds;
    return Duration(milliseconds: ms > cap ? cap : ms);
  }

  void _stopAndNotify() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _cancelToken.cancel('polling timeout');
    WidgetsBinding.instance.removeObserver(this);
    onTimeout?.call();
  }
}
