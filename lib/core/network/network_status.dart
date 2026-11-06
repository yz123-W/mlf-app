import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 设备连通性变化流：先给出当前状态，再持续推送变化。
final networkStatusProvider = StreamProvider<List<ConnectivityResult>>((ref) async* {
  yield await Connectivity().checkConnectivity();
  yield* Connectivity().onConnectivityChanged;
});

/// 是否在线；状态未知时按在线处理，避免启动瞬间误报离线。
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(networkStatusProvider).asData?.value;
  if (status == null) return true;
  return status.any((r) => r != ConnectivityResult.none);
});
