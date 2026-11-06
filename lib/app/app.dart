import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/network/network_status.dart';
import '../core/session/session_events.dart';
import '../features/app_update/data/app_update_service.dart';
import 'router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

/// 应用根组件。
class MlfApp extends ConsumerWidget {
  const MlfApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final online = ref.watch(isOnlineProvider);
    // 任意页面接口返回 401（令牌过期/被踢下线）时统一清理并回登录页。
    ref.listen<int>(sessionExpiredProvider, (previous, next) {
      if (previous != next) {
        router.go('/login');
      }
    });
    return MaterialApp.router(
      title: '面立方',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) {
        return _AppUpdateGate(
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.topLeft,
            children: [
              ?child,
              // 断网时顶部提示条，恢复后自动消失。
              if (!online)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Material(
                    color: AppColors.wine,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.wifi_off, size: 15, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              '当前网络不可用',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 启动后的版本检查入口：进程内只检查一次，弹窗挂在根 Navigator 上。
class _AppUpdateGate extends ConsumerStatefulWidget {
  const _AppUpdateGate({required this.child});

  final Widget child;

  @override
  ConsumerState<_AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<_AppUpdateGate> {
  /// 进程内只检查一次，页面重建不会重复弹窗。
  static bool _checked = false;

  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final info = await ref.read(appUpdateServiceProvider).check();
    if (!mounted || info == null || _dialogShown) return;
    // 开屏页切走时，挂在其上的弹窗路由会被一并移除；等离开 `/` 后再弹窗。
    final router = ref.read(routerProvider);
    for (var i = 0; i < 25; i++) {
      final path = router.routerDelegate.currentConfiguration.uri.path;
      if (path != '/') break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
    }
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null || !navigatorContext.mounted) return;
    _dialogShown = true;
    await showDialog<void>(
      context: navigatorContext,
      barrierDismissible: !info.forceUpdate,
      builder: (_) => _UpdateDialog(info: info),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 版本更新弹窗：强制更新时不可关闭、不提供「稍后」。
class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.info});

  final AppUpdateInfo info;

  Future<void> _openDownload() async {
    try {
      await launchUrl(Uri.parse(info.downloadUrl), mode: LaunchMode.externalApplication);
    } catch (_) {
      // 打开下载地址失败时保持弹窗，用户可稍后重试。
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !info.forceUpdate,
      child: AlertDialog(
        title: Text('发现新版本 ${info.versionName}'),
        content: Text(
          info.releaseNote.isEmpty ? '建议更新到最新版本以获得更好的体验。' : info.releaseNote,
        ),
        actions: [
          if (!info.forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('稍后'),
            ),
          FilledButton(
            onPressed: () async {
              await _openDownload();
              if (!info.forceUpdate && context.mounted) Navigator.pop(context);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }
}
