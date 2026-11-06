import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/cube_mark.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../../guide/data/onboarding_gate.dart';
import '../data/auth_models.dart';
import '../data/auth_providers.dart';

/// 登录页（验证码登录 / 密码登录）。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static final RegExp _phoneReg = RegExp(r'^1\d{10}$');

  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

  int _mode = 0; // 0 = 验证码登录，1 = 密码登录
  bool _agreed = true;
  bool _submitting = false;
  int _countdown = 0;
  String? _mockCode;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _phoneValid => _phoneReg.hasMatch(_phone.text.trim());

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _countdown--;
        if (_countdown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _sendCode() async {
    if (!_phoneValid) {
      showToast(context, '请输入正确的手机号');
      return;
    }
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .sendSms(phone: _phone.text.trim(), scene: SmsScene.login);
      if (!mounted) return;
      setState(() {
        _mockCode = result.mock ? result.mockCode : null;
        if (result.mockCode != null) _code.text = result.mockCode!;
      });
      showToast(context, result.mock ? '开发模式验证码已自动填入' : '验证码已发送');
      _startCountdown();
    } catch (e) {
      if (mounted) showToast(context, '$e');
    }
  }

  Future<void> _submit() async {
    if (!_agreed) {
      showToast(context, '请先阅读并同意用户协议与隐私政策');
      return;
    }
    if (!_phoneValid) {
      showToast(context, '请输入正确的手机号');
      return;
    }
    if (_mode == 0 && _code.text.trim().isEmpty) {
      showToast(context, '请输入验证码');
      return;
    }
    if (_mode == 1 && _password.text.isEmpty) {
      showToast(context, '请输入密码');
      return;
    }

    setState(() => _submitting = true);
    final repo = ref.read(authRepositoryProvider);
    try {
      if (_mode == 0) {
        await repo.loginBySms(phone: _phone.text.trim(), code: _code.text.trim());
      } else {
        await repo.loginByPassword(phone: _phone.text.trim(), password: _password.text);
      }
      if (!mounted) return;
      ref.read(analyticsProvider).track('login_success');
      // 方案 B：按「该账号是否已有岗位画像」判定是否为老用户，
      // 已存在画像说明引导过，直接进首页；否则才走新手引导。
      final skipGuide = await ref.read(onboardingGateProvider).completedGuide();
      if (!mounted) return;
      if (skipGuide) {
        showToast(context, '欢迎回来');
        context.go('/home');
      } else {
        showToast(context, '登录成功，先完善你的岗位画像');
        context.go('/guide/1');
      }
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 33, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 26),
              _tabs(),
              const SizedBox(height: 22),
              MlfUnderlineField(
                icon: Icons.smartphone,
                controller: _phone,
                hint: '请输入手机号',
                keyboardType: TextInputType.phone,
                maxLength: 11,
              ),
              const SizedBox(height: 9),
              if (_mode == 0)
                MlfUnderlineField(
                  icon: Icons.shield_outlined,
                  controller: _code,
                  hint: '请输入验证码',
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  trailing: TextButton(
                    onPressed: _countdown > 0 ? null : _sendCode,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _countdown > 0 ? '$_countdown 秒后重发' : '获取验证码',
                      style: const TextStyle(
                        color: AppColors.wine,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else
                MlfUnderlineField(
                  icon: Icons.lock_outline,
                  controller: _password,
                  hint: '请输入密码',
                  obscure: true,
                ),
              if (_mockCode != null)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '开发模式验证码：$_mockCode（已自动填入）',
                    style: const TextStyle(color: Color(0xFF8A6D1F), fontSize: 12),
                  ),
                ),
              const SizedBox(height: 18),
              _agreement(),
              const SizedBox(height: 18),
              MlfPrimaryButton(label: '登录', loading: _submitting, onPressed: _submit),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _link('注册账号', () => context.push('/register')),
                  const SizedBox(width: 18),
                  _link('忘记密码？', () => context.push('/forgot')),
                ],
              ),
              const SizedBox(height: 26),
              _divider('其他登录方式'),
              const SizedBox(height: 16),
              _socials(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return const Column(
      children: [
        CubeMark(size: 54),
        SizedBox(height: 15),
        Text('面立方',
            style: TextStyle(fontSize: 27, letterSpacing: 2, fontWeight: FontWeight.w800)),
        SizedBox(height: 8),
        Text('欢迎回来', style: TextStyle(fontSize: 13, color: AppColors.muted)),
      ],
    );
  }

  Widget _tabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x0F002B99),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _tab('验证码登录', 0),
          _tab('密码登录', 1),
        ],
      ),
    );
  }

  Widget _tab(String label, int index) {
    final current = _mode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = index),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: current ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: current
                ? const [BoxShadow(color: Color(0x17002B99), blurRadius: 9, offset: Offset(0, 3))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: current ? AppColors.blue : AppColors.muted,
              fontWeight: current ? FontWeight.w700 : FontWeight.w400,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _agreement() {
    return Row(
      children: [
        SizedBox(
          height: 22,
          width: 22,
          child: Checkbox(
            value: _agreed,
            onChanged: (v) => setState(() => _agreed = v ?? false),
            activeColor: AppColors.blue,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 4),
        const Text('我已阅读并同意', style: TextStyle(fontSize: 12, color: AppColors.muted)),
        _link('用户协议', _openProtocol),
        const Text('与', style: TextStyle(fontSize: 12, color: AppColors.muted)),
        _link('隐私政策', _openProtocol),
      ],
    );
  }

  Widget _link(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.blue,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _divider(String label) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.line, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: const TextStyle(color: Color(0xFF9B9BAA), fontSize: 12)),
        ),
        const Expanded(child: Divider(color: AppColors.line, height: 1)),
      ],
    );
  }

  Widget _socials() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _social(Icons.wechat, const Color(0xFF0AB969), '正在唤起微信登录'),
        const SizedBox(width: 24),
        _social(Icons.support_agent, const Color(0xFF2985ED), '正在唤起 QQ 登录'),
      ],
    );
  }

  Widget _social(IconData icon, Color color, String message) {
    return GestureDetector(
      onTap: () => showToast(context, message),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  void _openProtocol() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
      ),
      builder: (context) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 22, 24, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('用户协议与隐私政策',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            SizedBox(height: 12),
            Text(
              '欢迎使用面立方。我们仅在提供模拟面试服务所必需的范围内收集手机号、简历与面试录音录像等数据。\n\n'
              '面试过程中的录音录像仅用于生成评估报告，不会对外公开。你可随时在设置中清理缓存或申请注销账号。\n\n'
              '本页为原型静态文案，正式上线以法务审定版本为准。',
              style: TextStyle(fontSize: 13, height: 1.75, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
