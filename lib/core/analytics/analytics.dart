import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

import '../network/api_client.dart';

/// 轻量埋点上报。
///
/// 内存队列缓冲，「满 10 条 / 间隔 30 秒 / App 切后台」任一条件触发批量上报；
/// 上报失败直接丢弃，不重试、不阻塞业务。
/// 属性只允许放非敏感的枚举/ID 类信息，禁止携带手机号、token、简历内容等。
class Analytics with WidgetsBindingObserver {
  Analytics(this._client) {
    WidgetsBinding.instance.addObserver(this);
  }

  static const String _batchPath = '/interview/event/batch';
  static const int _batchSize = 10;
  static const int _maxQueue = 50;
  static const Duration _flushInterval = Duration(seconds: 30);

  final ApiClient _client;
  final List<Map<String, Object?>> _queue = [];
  Timer? _timer;
  bool _flushing = false;

  /// 记录一个事件；达到批量阈值立即上报，否则交给定时器。
  void track(String event, [Map<String, Object?>? props]) {
    _queue.add({
      'event': event,
      'platform': _platform,
      if (props != null && props.isNotEmpty) 'props': props,
    });
    while (_queue.length > _maxQueue) {
      _queue.removeAt(0);
    }
    if (_queue.length >= _batchSize) {
      _cancelTimer();
      unawaited(flush());
    } else {
      _timer ??= Timer(_flushInterval, () {
        _timer = null;
        unawaited(flush());
      });
    }
  }

  /// 批量上报当前队列；失败丢弃，不重试。
  Future<void> flush() async {
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    final batch = List<Map<String, Object?>>.of(_queue);
    _queue.clear();
    try {
      await _client.postJson(_batchPath, data: batch);
    } catch (_) {
      // 埋点失败不影响业务，直接丢弃。
    } finally {
      _flushing = false;
      if (_queue.isNotEmpty) {
        _timer ??= Timer(_flushInterval, () {
          _timer = null;
          unawaited(flush());
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      unawaited(flush());
    }
  }

  void dispose() {
    _cancelTimer();
    WidgetsBinding.instance.removeObserver(this);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String get _platform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }
}
