import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../data/auth_models.dart';
import '../data/auth_providers.dart';

/// 忘记密码（手机号 + 验证码重置密码）。
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static final RegExp _phoneReg = RegExp(r'^1\d{10}$');

  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

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
          .sendSms(phone: _phone.text.trim(), scene: SmsScene.resetPwd);
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
    if (!_phoneValid) {
      showToast(context, '请输入正确的手机号');
      return;
    }
    if (_code.text.trim().isEmpty) {
      showToast(context, '请输入验证码');
      return;
    }
    if (_password.text.length < 8) {
      showToast(context, '请设置 8-20 位密码');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            phone: _phone.text.trim(),
            code: _code.text.trim(),
            password: _password.text,
          );
      if (!mounted) return;
      showToast(context, '密码已重置，请登录');
      context.go('/login');
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
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back, size: 18, color: AppColors.blue),
                  label: const Text('返回登录',
                      style: TextStyle(color: AppColors.blue, fontSize: 14)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ),
              const SizedBox(height: 6),
              Column(
                children: [
                  Container(
                    width: 63,
                    height: 63,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE4ECFF), Colors.white],
                      ),
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: const Icon(Icons.key_outlined, color: AppColors.wine, size: 32),
                  ),
                  const SizedBox(height: 15),
                  const Text('找回密码',
                      style: TextStyle(
                          fontSize: 27, letterSpacing: 2, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('验证手机号重置密码',
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 28),
              MlfUnderlineField(
                icon: Icons.smartphone,
                controller: _phone,
                hint: '请输入手机号',
                keyboardType: TextInputType.phone,
                maxLength: 11,
              ),
              const SizedBox(height: 9),
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
              const SizedBox(height: 9),
              MlfUnderlineField(
                icon: Icons.lock_outline,
                controller: _password,
                hint: '设置新密码（8-20 位）',
                obscure: true,
              ),
              const SizedBox(height: 24),
              MlfPrimaryButton(label: '重置密码', loading: _submitting, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
