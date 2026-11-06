import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/cube_mark.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../data/auth_models.dart';
import '../data/auth_providers.dart';

/// 注册页（手机号 + 验证码）
///
/// 注：后端 `register/sms` 只接收 phone / code / agreed（注册即用、不设密码，
/// 需要密码请走「忘记密码」重置），故本页不含密码输入。
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static final RegExp _phoneReg = RegExp(r'^1\d{10}$');

  final _phone = TextEditingController();
  final _code = TextEditingController();

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
          .sendSms(phone: _phone.text.trim(), scene: SmsScene.register);
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
    if (_code.text.trim().isEmpty) {
      showToast(context, '请输入验证码');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authRepositoryProvider).registerBySms(
            phone: _phone.text.trim(),
            code: _code.text.trim(),
            agreed: _agreed,
          );
      if (!mounted) return;
      showToast(context, '注册成功，欢迎加入面立方');
      context.go('/guide/1');
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
              const Column(
                children: [
                  CubeMark(size: 54),
                  SizedBox(height: 15),
                  Text('注册账号',
                      style: TextStyle(fontSize: 27, letterSpacing: 2, fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text('加入面立方，开启 AI 模拟面试',
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
              const SizedBox(height: 18),
              Row(
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
                  const Text('我已阅读并同意',
                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  const Text('用户协议',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.blue, fontWeight: FontWeight.w700)),
                  const Text('与', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  const Text('隐私政策',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.blue, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 18),
              MlfPrimaryButton(label: '注册并登录', loading: _submitting, onPressed: _submit),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('已有账号？', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Text('去登录',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.blue, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
