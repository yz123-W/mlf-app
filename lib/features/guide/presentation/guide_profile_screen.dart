import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';

/// 新用户引导 · 第一步：岗位画像（UI 壳，本地选择）
///
/// 说明：原型的「意向行业」取值（互联网/金融/智能制造/教育）与后端
/// `student_job_profile.industry`（1技术 2产品 3运营 4财务 5教师）语义不一致，
/// 正式对接前需产品确认字典映射，故本期先做本地选择。
class GuideProfileScreen extends StatefulWidget {
  const GuideProfileScreen({super.key});

  @override
  State<GuideProfileScreen> createState() => _GuideProfileScreenState();
}

class _GuideProfileScreenState extends State<GuideProfileScreen> {
  static const _industries = ['互联网', '金融', '智能制造', '教育'];
  static const _jobs = ['Java 后端', '产品经理', 'UI 设计师'];
  static const _levels = ['求职新手', '中等难度', '高难挑战'];
  static const _companies = ['BAT', '央国企', '外企', '其它'];

  String _industry = _industries.first;
  String _job = _jobs.first;
  String _level = _levels.first;
  String _company = _companies.first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('01 / 03',
                    style: TextStyle(color: AppColors.wine, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 14),
              Container(
                height: 170,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Icon(Icons.face_retouching_natural, color: AppColors.blue, size: 68),
              ),
              const SizedBox(height: 18),
              const Text('先认识一下你',
                  style: TextStyle(fontSize: 27, letterSpacing: -1, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('完善岗位画像，让每一道练习题都更贴近你的目标。',
                  style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.65)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 18, bottom: 18),
                  children: [
                    _group('意向行业', _industries, _industry, (v) => setState(() => _industry = v)),
                    _group('目标岗位', _jobs, _job, (v) => setState(() => _job = v)),
                    _group('面试难度', _levels, _level, (v) => setState(() => _level = v)),
                    _group('目标企业', _companies, _company, (v) => setState(() => _company = v)),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 51,
                      child: OutlinedButton(
                        onPressed: () => context.go('/guide/2'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFE7EDFF),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text('跳过此步',
                            style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    flex: 1, // 原作是 1.28 倍，此处保持简洁
                    child: SizedBox(
                      height: 51,
                      child: FilledButton(
                        onPressed: () => context.go('/guide/2'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text('选好啦',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group(String label, List<String> options, String selected, ValueChanged<String> onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Text(label,
              style: const TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final active = o == selected;
            return GestureDetector(
              onTap: () => onPick(o),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFE7EDFF) : AppColors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: active ? AppColors.blue : AppColors.line),
                ),
                child: Text(
                  o,
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
}
