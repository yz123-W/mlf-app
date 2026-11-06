import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/env.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../../resume/data/resume_providers.dart';
import '../data/profile_providers.dart';
import '../data/student_profile_models.dart';

/// 我的档案：只编辑白名单字段，等级 / 积分等系统字段只读展示。
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nickname = TextEditingController();
  final _realName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _school = TextEditingController();
  final _major = TextEditingController();
  final _graduationYear = TextEditingController();

  String _gender = '2';
  String _education = '';
  String _avatar = '';

  bool _filled = false;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void dispose() {
    _nickname.dispose();
    _realName.dispose();
    _phone.dispose();
    _email.dispose();
    _school.dispose();
    _major.dispose();
    _graduationYear.dispose();
    super.dispose();
  }

  void _fill(StudentProfileM profile) {
    if (_filled) return;
    _filled = true;
    _nickname.text = profile.nickname;
    _realName.text = profile.realName;
    _phone.text = profile.phone;
    _email.text = profile.email;
    _school.text = profile.school;
    _major.text = profile.major;
    _graduationYear.text = profile.graduationYear;
    _gender = profile.gender.isEmpty ? '2' : profile.gender;
    _education = profile.education;
    _avatar = profile.avatar;
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final uploaded = await ref.read(resumeRepositoryProvider).upload(
            bytes: bytes,
            filename: picked.name.isEmpty ? 'avatar.jpg' : picked.name,
          );
      if (uploaded.fileName.isEmpty) {
        throw Exception('服务器未返回文件地址');
      }
      if (!mounted) return;
      setState(() => _avatar = uploaded.fileName);
    } catch (e) {
      if (mounted) showToast(context, '头像上传失败：$e');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty) {
      showToast(context, '昵称不能为空');
      return;
    }
    final phone = _phone.text.trim();
    if (phone.isNotEmpty && !RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      showToast(context, '请输入正确的手机号');
      return;
    }
    final email = _email.text.trim();
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      showToast(context, '请输入正确的邮箱地址');
      return;
    }
    final year = _graduationYear.text.trim();
    if (year.isNotEmpty && !RegExp(r'^(19|20)\d{2}$').hasMatch(year)) {
      showToast(context, '请输入正确的毕业年份');
      return;
    }

    setState(() => _saving = true);
    try {
      final current = ref.read(myStudentProfileProvider).value;
      final payload = (current ?? const StudentProfileM()).copyWith(
        nickname: nickname,
        avatar: _avatar,
        realName: _realName.text.trim(),
        gender: _gender,
        phone: phone,
        email: email,
        school: _school.text.trim(),
        major: _major.text.trim(),
        education: _education,
        graduationYear: year,
      );
      await ref.read(studentProfileRepositoryProvider).updateMyProfile(payload);
      ref.invalidate(myStudentProfileProvider);
      ref.invalidate(profileDashboardProvider);
      if (!mounted) return;
      showToast(context, '档案已保存');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myStudentProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: const Text('我的档案', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.blue)),
        error: (error, _) => _errorBlock('$error'),
        data: (data) {
          _fill(data);
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              _avatarBlock(),
              const SizedBox(height: 16),
              MlfCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    MlfUnderlineField(
                      icon: Icons.badge_outlined,
                      controller: _nickname,
                      hint: '昵称（必填）',
                      maxLength: 50,
                    ),
                    MlfUnderlineField(
                      icon: Icons.person_outline,
                      controller: _realName,
                      hint: '真实姓名',
                      maxLength: 50,
                    ),
                    MlfUnderlineField(
                      icon: Icons.phone_outlined,
                      controller: _phone,
                      hint: '手机号',
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                    ),
                    MlfUnderlineField(
                      icon: Icons.mail_outline,
                      controller: _email,
                      hint: '邮箱',
                      keyboardType: TextInputType.emailAddress,
                      maxLength: 100,
                    ),
                    MlfUnderlineField(
                      icon: Icons.school_outlined,
                      controller: _school,
                      hint: '学校',
                      maxLength: 100,
                    ),
                    MlfUnderlineField(
                      icon: Icons.menu_book_outlined,
                      controller: _major,
                      hint: '专业',
                      maxLength: 100,
                    ),
                    MlfUnderlineField(
                      icon: Icons.event_outlined,
                      controller: _graduationYear,
                      hint: '毕业年份（如 2026）',
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _chipGroup(
                '性别',
                const {'0': '男', '1': '女', '2': '未知'},
                _gender,
                (v) => setState(() => _gender = v),
              ),
              _chipGroup(
                '学历',
                const {'1': '专科', '2': '本科', '3': '硕士', '4': '博士'},
                _education,
                (v) => setState(() => _education = v),
              ),
              const SizedBox(height: 18),
              _readonlyBlock(data),
              const SizedBox(height: 22),
              MlfPrimaryButton(
                label: '保存档案',
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _avatarBlock() {
    return Center(
      child: GestureDetector(
        onTap: _uploadingAvatar ? null : _pickAvatar,
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: const Color(0xFFDCE4FF),
                  backgroundImage: _avatarUrl.isEmpty
                      ? null
                      : CachedNetworkImageProvider(_avatarUrl),
                  child: _avatarUrl.isEmpty
                      ? const Icon(Icons.person, color: AppColors.blue, size: 42)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cream, width: 2),
                    ),
                    child: _uploadingAvatar
                        ? const Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(strokeWidth: 1.6, color: Colors.white),
                          )
                        : const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            const Text('点击更换头像',
                style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  String get _avatarUrl {
    if (_avatar.isEmpty) return '';
    if (_avatar.startsWith('http://') || _avatar.startsWith('https://')) return _avatar;
    return '${Env.apiBaseUrl}$_avatar';
  }

  Widget _chipGroup(
    String label,
    Map<String, String> options,
    String selected,
    ValueChanged<String> onPick,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Text(label,
              style: const TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.entries.map((e) {
            final active = e.key == selected;
            return GestureDetector(
              onTap: () => onPick(e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFE7EDFF) : AppColors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: active ? AppColors.blue : AppColors.line),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    color: active ? AppColors.blue : AppColors.ink,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _readonlyBlock(StudentProfileM profile) {
    return MlfCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('成长信息（由系统维护）',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: [
              _readonlyItem('当前等级', profile.currentLevel.isEmpty ? '-' : profile.currentLevel),
              const SizedBox(width: 24),
              _readonlyItem('当前积分', '${profile.currentPoints}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _readonlyItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _errorBlock(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.6)),
            const SizedBox(height: 16),
            SizedBox(
              height: 42,
              child: FilledButton(
                onPressed: () => ref.invalidate(myStudentProfileProvider),
                style: FilledButton.styleFrom(backgroundColor: AppColors.blue),
                child: const Text('重新加载',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
