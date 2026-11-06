import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/env.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/cube_mark.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../data/splash_ad_models.dart';
import '../data/splash_ad_providers.dart';

/// 开屏页。
///
/// 不论是否登录都加载并展示开屏广告；广告结束（或跳过）后按登录态进入首页或登录页。
/// 已登录但无广告时展示短暂品牌帧后直接进首页。
/// 广告来自学生端匿名接口 `/interview/advert/active`（`mobile_splash` 位），
/// 拉取超时、无素材、图片失败都不阻塞。
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const Duration _fetchTimeout = Duration(milliseconds: 1500);
  static const Duration _brandHold = Duration(milliseconds: 600);

  /// 已登录用户是否展示开屏广告；默认关闭，可用编译参数恢复全量展示。
  static const bool _adForLoggedIn = bool.fromEnvironment(
    'SPLASH_AD_FOR_LOGGED_IN',
    defaultValue: false,
  );

  /// 站内跳转白名单：只允许已注册的页面前缀。
  static const List<String> _routePrefixes = [
    '/home',
    '/interview',
    '/jobs',
    '/questions',
    '/question/',
    '/profile',
    '/warmup/',
    '/result/',
    '/login',
    '/register',
  ];

  SplashAdvert? _ad;
  Timer? _timer;
  int _left = 0;
  bool _navigated = false;

  /// 开屏流程结束后的去向：已登录进首页，未登录 / token 失效进登录页。
  String _destination = '/login';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    SessionGate gate = SessionGate.loggedOut;
    try {
      gate = await ref.read(authRepositoryProvider).validateSession();
    } catch (_) {
      // 校验异常兜底：保留 token，按已登录处理，避免误退登录。
      gate = SessionGate.networkError;
    }
    if (!mounted) return;

    _destination = gate == SessionGate.loggedOut ? '/login' : '/home';

    // 已登录用户默认直接进入首页，不再请求广告（冷启动更快）。
    if (gate != SessionGate.loggedOut && !_adForLoggedIn) {
      await _leave();
      return;
    }

    SplashAdvert? ad;
    try {
      ad = await ref.read(splashAdApiProvider).mobileSplash().timeout(_fetchTimeout);
    } catch (_) {
      ad = null;
    }
    if (!mounted || _navigated) return;
    if (ad == null || ad.imageUrl.isEmpty) {
      await _leave();
      return;
    }

    // frequency=day：同一广告每天只展示一次（session 由冷启动天然保证一次）。
    if (ad.frequency == 'day') {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString('splash_ad_day_${ad.id}') == _dayKey()) {
          ad = null;
        }
      } catch (_) {
        // 本地存储不可用时按可展示处理。
      }
      if (!mounted || _navigated) return;
      if (ad == null) {
        await _leave();
        return;
      }
    }

    // 图片预加载成功后再展示，避免白屏或半张图；本地已缓存时只做极短确认。
    final url = _imageUrl(ad.imageUrl);
    try {
      final cached = await DefaultCacheManager().getFileFromCache(url);
      if (!mounted || _navigated) return;
      final wait = cached == null
          ? const Duration(seconds: 2)
          : const Duration(milliseconds: 300);
      await precacheImage(CachedNetworkImageProvider(url), context).timeout(wait);
    } catch (_) {
      await _leave();
      return;
    }
    if (!mounted || _navigated) return;

    final seconds = ad.duration > 0 ? ad.duration.clamp(3, 5) : 4;
    setState(() {
      _ad = ad;
      _left = seconds;
    });
    ref.read(analyticsProvider).track('ad_impression', {
      'adId': ad.id,
      'position': 'mobile_splash',
    });
    if (ad.frequency == 'day') {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('splash_ad_day_${ad.id}', _dayKey());
      } catch (_) {
        // 忽略频次写入失败。
      }
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        timer.cancel();
        _go(_destination);
      }
    });
  }

  /// 无广告可展示时收尾：已登录保留品牌帧停留后进首页，未登录直接去登录页。
  Future<void> _leave() async {
    if (_destination == '/home') {
      await Future<void>.delayed(_brandHold);
      if (!mounted) return;
    }
    _go(_destination);
  }

  String _dayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  void _go(String location) {
    if (!mounted || _navigated) return;
    _navigated = true;
    _timer?.cancel();
    context.go(location);
  }

  Future<void> _onAdTap() async {
    final ad = _ad;
    if (ad == null) return;
    if (ad.jumpType == 'url' && _isHttpUrl(ad.jumpTarget)) {
      _timer?.cancel();
      try {
        await launchUrl(Uri.parse(ad.jumpTarget), mode: LaunchMode.externalApplication);
      } catch (_) {
        // 打不开外链时按跳过处理。
      }
      _go(_destination);
      return;
    }
    if (ad.jumpType == 'route' && _isAllowedRoute(ad.jumpTarget)) {
      _go(ad.jumpTarget);
    }
  }

  bool _isHttpUrl(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  bool _isAllowedRoute(String value) {
    if (!value.startsWith('/') || value.contains('://')) return false;
    return _routePrefixes.any(value.startsWith);
  }

  String _imageUrl(String path) {
    if (_isHttpUrl(path)) return Uri.encodeFull(path);
    final base = Env.apiBaseUrl.endsWith('/')
        ? Env.apiBaseUrl.substring(0, Env.apiBaseUrl.length - 1)
        : Env.apiBaseUrl;
    return Uri.encodeFull('$base${path.startsWith('/') ? '' : '/'}$path');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _ad == null
            ? _brandFrame(key: const ValueKey('brand'))
            : _adFrame(_ad!, key: const ValueKey('ad')),
      ),
    );
  }

  /// 品牌帧：无广告 / 加载中的白色底品牌页。
  Widget _brandFrame({Key? key}) {
    return Stack(
      key: key,
      children: [
        Positioned(right: -110, top: 94, child: _ring(340, 40, 31)),
        Positioned(left: -136, bottom: 56, child: _ring(250, 34, 22)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CubeMark(size: 150),
              const SizedBox(height: 32),
              const Text(
                '面立方',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 35,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '每一次开口，都离理想更近',
                style: TextStyle(color: AppColors.muted, fontSize: 14, letterSpacing: 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 广告帧：全屏素材 + 跳过胶囊 + 广告标识 + 底部品牌条。
  Widget _adFrame(SplashAdvert ad, {Key? key}) {
    return Stack(
      key: key,
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: _onAdTap,
          child: CachedNetworkImage(
            imageUrl: _imageUrl(ad.imageUrl),
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            errorWidget: (_, _, _) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _go(_destination));
              return Container(color: AppColors.white);
            },
          ),
        ),
        // 顶部压暗，保证跳过胶囊在浅色素材上也清晰。
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 120,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.22), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 16, 0),
              child: _skipPill(),
            ),
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _bottomBar()),
      ],
    );
  }

  Widget _skipPill() {
    return GestureDetector(
      onTap: () => _go(_destination),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(
          '跳过 $_left',
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        border: const Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: EdgeInsets.fromLTRB(16, 9, 16, 9 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          const CubeMark(size: 22),
          const SizedBox(width: 8),
          const Text(
            '面立方',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '每一次开口，都离理想更近',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.muted, fontSize: 10.5),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.blueSoft,
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              '广告',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(double size, double radius, double rotate) {
    return Transform.rotate(
      angle: rotate * 3.1415926 / 180,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x14002B99)),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
