import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../../resume/data/resume_models.dart';
import '../../resume/data/resume_providers.dart';
import '../data/interview_models.dart';
import '../data/interview_providers.dart';
import '../data/job_presets.dart';

const String _serif = 'serif';

/// 面试定制：方案卡（岗位 / 出题方式 / 面试形式 / 难度 / 题数 / 简历 / 行业 / 题型）
/// → 创建场次 → 进入模拟面试。
///
/// 采用自由岗位模式（`jobName + industry + difficulty`）；岗位画像仅用于快速回填。
class InterviewScreen extends ConsumerStatefulWidget {
  const InterviewScreen({super.key});

  @override
  ConsumerState<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends ConsumerState<InterviewScreen> {
  /// 行业码与岗位侧 industry_type 字典一致，供画像回填时校验取值合法性。
  static const Map<String, String> _industries = {
    '1': '互联网',
    '2': '金融',
    '3': '制造业',
    '4': '教育培训',
    '5': '文化娱乐',
    '6': '人工智能',
    '7': '通用',
    '8': '企业服务',
  };
  static const Map<String, String> _difficulties = {
    '1': '初级',
    '2': '中级',
    '3': '高级',
  };
  static const Map<String, String> _types = {
    '1': '行为面',
    '2': '技术面',
    '3': 'HR 面',
    '4': '案例面',
  };
  static const List<int> _countOptions = [5, 10, 20];
  static const Map<String, String> _sources = {
    'ai': 'AI 智能',
    'bank': '题库抽题',
  };
  static const Map<String, String> _interviewTypes = {
    '1': '文字',
    '2': '语音',
    '3': '视频',
  };

  String _jobName = '';
  String _industry = '1';
  String _difficulty = '1';
  String _questionSource = 'ai';
  String _interviewType = '1';
  final Set<String> _types2 = {'1', '2'};
  int _count = 5;
  int? _resumeId;
  String _resumeName = '';
  bool _submitting = false;
  bool _profileApplied = false;
  bool _resumeApplied = false;

  Future<void> _start() async {
    final jobName = _jobName.trim();
    if (jobName.isEmpty) {
      showToast(context, '请选择目标岗位');
      return;
    }
    setState(() => _submitting = true);
    try {
      final repo = ref.read(interviewRepositoryProvider);
      final typeCodes = _types2.toList()..sort();
      final session = await repo.createSession(
        jobName: jobName,
        industry: _industry,
        difficulty: _difficulty,
        questionSource: _questionSource,
        resumeId: _questionSource == 'ai' ? _resumeId : null,
        questionType: typeCodes.isEmpty ? null : typeCodes.join(','),
        totalCount: _count,
        interviewType: _interviewType,
      );
      ref.invalidate(sessionHistoryProvider);
      if (!mounted) return;
      if (session.ongoing) {
        context.push('/room/${session.id}');
      } else {
        context.push('/interview/generating?sessionId=${session.id}');
      }
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openSession(InterviewSessionM session) {
    if (session.pending) {
      context.push('/interview/generating?sessionId=${session.id}');
    } else if (session.finished && session.reportId != null) {
      context.push('/result/${session.reportId}');
    } else if (session.ongoing) {
      context.push('/room/${session.id}');
    } else {
      showToast(
        context,
        '该场次${InterviewDict.sessionStatus(session.status)}，暂无复盘报告',
      );
    }
  }

  void _applyProfile(JobProfileM profile) {
    setState(() {
      if (profile.jobName.isNotEmpty) {
        _jobName = profile.jobName;
        _industry = _inferIndustry(profile.jobName);
      }
      // 画像里已保存的行业优先；画像为「行业不限」时保留按岗位名推断的结果。
      if (profile.industry.isNotEmpty &&
          _industries.containsKey(profile.industry)) {
        _industry = profile.industry;
      }
    });
  }

  /// 按岗位名推断行业（industry_type 码）：
  /// 1互联网 2金融 3制造业 4教育培训 5文化娱乐 6人工智能 7通用 8企业服务。
  /// 推断结果只作为出题参数传给后端，不在界面上展示。
  static String _inferIndustry(String job) {
    final j = job.trim();
    if (j.isEmpty) return '1';
    if (RegExp(
      r'AI|人工智能|算法|机器学习|深度学习|大模型|Agent|数据科学|NLP|CV',
      caseSensitive: false,
    ).hasMatch(j)) {
      return '6';
    }
    if (RegExp(r'教师|讲师|老师|课程|教育|培训|助教').hasMatch(j)) return '4';
    if (RegExp(r'金融|银行|证券|保险|基金|风控|量化|投资|理财').hasMatch(j)) return '2';
    if (RegExp(r'制造|机械|电气|自动化|工艺|生产|质量|设备|车间').hasMatch(j)) {
      return '3';
    }
    if (RegExp(r'传媒|影视|游戏|文创|娱乐|主播|编辑|短视频|主持人').hasMatch(j)) {
      return '5';
    }
    if (RegExp(r'销售|客服|行政|人事|人力|HR|财务|会计|法务|采购|运营|市场|营销')
        .hasMatch(j)) {
      return '8';
    }
    return '1';
  }

  @override
  Widget build(BuildContext context) {
    // 首次拿到岗位画像时，用默认画像回填岗位与行业。
    ref.listen(jobProfileListProvider, (_, next) {
      next.whenData((list) {
        if (_profileApplied || list.isEmpty) return;
        _profileApplied = true;
        final def = list.firstWhere(
          (e) => e.isDefault,
          orElse: () => list.first,
        );
        _applyProfile(def);
      });
    });

    // 首次拿到简历列表时，默认选中「默认简历」。
    ref.listen(resumeListProvider, (_, next) {
      next.whenData((list) {
        if (_resumeApplied || list.isEmpty) return;
        _resumeApplied = true;
        final def = list.firstWhere(
          (e) => e.isDefault,
          orElse: () => list.first,
        );
        setState(() {
          _resumeId = def.id;
          _resumeName = def.resumeName;
        });
      });
    });

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
        children: [
          const Text(
            '模拟面试',
            style: TextStyle(
              fontFamily: _serif,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            '选好岗位，即刻开练。',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11.5,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          _setupCard(),
          const SizedBox(height: 18),
          _startButton(),
          const SizedBox(height: 26),
          const Text(
            '面试历史',
            style: TextStyle(
              fontFamily: _serif,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 11),
          _historyBlock(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ 方案卡

  Widget _setupCard() {
    final customCount = !_countOptions.contains(_count);
    final countOptions = <String, String>{
      for (final n in _countOptions) '$n': '$n 题',
      'custom': customCount ? '$_count 题' : '自定义',
    };
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0E1729),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _pickRow(
            '目标岗位',
            _jobName.isEmpty ? '请选择目标岗位' : _jobName,
            placeholder: _jobName.isEmpty,
            onTap: _pickJob,
          ),
          _divider(),
          _segmentRow(
            '出题方式',
            _sources,
            _questionSource,
            (v) => setState(() => _questionSource = v),
          ),
          _divider(),
          _segmentRow(
            '面试形式',
            _interviewTypes,
            _interviewType,
            (v) => setState(() => _interviewType = v),
          ),
          _divider(),
          _segmentRow(
            '难度',
            _difficulties,
            _difficulty,
            (v) => setState(() => _difficulty = v),
          ),
          _divider(),
          _segmentRow(
            '题数',
            countOptions,
            customCount ? 'custom' : '$_count',
            (v) {
              if (v == 'custom') {
                _pickCustomCount();
              } else {
                setState(() => _count = int.parse(v));
              }
            },
          ),
          if (_questionSource == 'ai') ...[
            _divider(),
            _pickRow(
              '参考简历',
              _resumeName.isEmpty ? '不使用简历' : _resumeName,
              onTap: _pickResume,
            ),
          ],
          _divider(),
          _chipsRow(
            '题型',
            options: _types,
            isActive: (k) => _types2.contains(k),
            onTap: (k) => setState(() {
              if (!_types2.add(k)) _types2.remove(k);
            }),
          ),
        ],
      ),
    );
  }

  Widget _rowShell(String label, Widget content) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: content),
      ],
    ),
  );

  Widget _pickRow(
    String label,
    String value, {
    required VoidCallback onTap,
    bool placeholder = false,
  }) => InkWell(
    onTap: onTap,
    child: _rowShell(
      label,
      Row(
        children: [
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: placeholder ? AppColors.muted : AppColors.ink,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.muted,
          ),
        ],
      ),
    ),
  );

  Widget _segmentRow(
    String label,
    Map<String, String> options,
    String selected,
    ValueChanged<String> onPick,
  ) => _rowShell(
    label,
    Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: options.entries.map((e) {
          final active = e.key == selected;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onPick(e.key),
              child: Container(
                height: 33,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppColors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  e.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );

  Widget _chipsRow(
    String label, {
    required Map<String, String> options,
    required bool Function(String) isActive,
    required ValueChanged<String> onTap,
  }) => _rowShell(
    label,
    Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.entries.map((e) {
        final active = isActive(e.key);
        return GestureDetector(
          onTap: () => onTap(e.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: active ? AppColors.blueSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active ? AppColors.blue : AppColors.line,
              ),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? AppColors.blue : AppColors.ink,
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );

  Widget _divider() => const Divider(
    height: 1,
    thickness: 1,
    color: AppColors.line,
  );

  Widget _startButton() {
    final enabled = !_submitting;
    return GestureDetector(
      onTap: enabled ? _start : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryButton,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22002B99),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const Text(
                '开始挑战',
                style: TextStyle(
                  color: Color(0xFFFFF7E4),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              if (_submitting)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x80FFF7E4)),
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Color(0xFFFFF7E4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ 选择器

  Future<void> _pickJob() async {
    final profiles =
        ref.read(jobProfileListProvider).asData?.value ??
        const <JobProfileM>[];
    final result = await showModalBottomSheet<_JobPick>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _JobPickerSheet(profiles: profiles),
    );
    if (result == null) return;
    if (result.custom) {
      final text = await _promptCustomJob();
      if (text == null || text.isEmpty) return;
      setState(() {
        _jobName = text;
        _industry = _inferIndustry(text);
      });
      return;
    }
    if (result.profile != null) {
      _applyProfile(result.profile!);
      return;
    }
    setState(() {
      _jobName = result.jobName;
      _industry = _inferIndustry(result.jobName);
    });
  }

  Future<String?> _promptCustomJob() => showDialog<String>(
    context: context,
    builder: (_) => _TextInputDialog(
      title: '自定义目标岗位',
      hint: '如：Java 后端',
      initial: _jobName,
    ),
  );

  Future<void> _pickResume() async {
    final resumes =
        ref.read(resumeListProvider).asData?.value ?? const <ResumeItem>[];
    final result = await showModalBottomSheet<_ResumePick>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _ResumePickerSheet(
        resumes: resumes,
        selectedId: _resumeId,
      ),
    );
    if (result == null) return;
    setState(() {
      _resumeId = result.id;
      _resumeName = result.name;
    });
  }

  Future<void> _pickCustomCount() async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _TextInputDialog(
        title: '自定义题数',
        hint: '请输入 1-30 之间的整数',
        initial: _countOptions.contains(_count) ? '' : '$_count',
        keyboardType: TextInputType.number,
      ),
    );
    if (!mounted || text == null) return;
    final value = int.tryParse(text);
    if (value == null || value < 1 || value > 30) {
      showToast(context, '题数需在 1-30 之间');
      return;
    }
    setState(() => _count = value);
  }

  // ------------------------------------------------------------------ 面试历史

  Widget _historyBlock() {
    final history = ref.watch(sessionHistoryProvider);
    return history.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: AppColors.blue)),
      ),
      error: (error, _) => MlfCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.muted,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$error',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
            GestureDetector(
              onTap: () => ref.invalidate(sessionHistoryProvider),
              child: const Text(
                '重试',
                style: TextStyle(
                  color: AppColors.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const MlfCard(
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.history, color: AppColors.muted, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '还没有面试记录，完成一场后就能在这里复盘',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return MlfCard(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.line),
                _historyRow(list[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _historyRow(InterviewSessionM session) {
    final time = session.startTime;
    return InkWell(
      onTap: () => _openSession(session),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.jobName.isEmpty ? '模拟面试' : session.jobName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    time == null
                        ? '时间未知'
                        : DateFormat('yyyy-MM-dd HH:mm').format(time),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _statusBadge(session),
            const SizedBox(width: 10),
            Text(
              session.score == null
                  ? '-'
                  : '${session.score!.toStringAsFixed(1)} 分',
              style: const TextStyle(
                color: AppColors.wine,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(InterviewSessionM session) {
    if (session.pending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x1A002B99),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          '出题中',
          style: TextStyle(
            color: AppColors.blue,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    final (Color fg, Color bg) = switch (session.status) {
      '1' => (AppColors.blue, const Color(0xFFE7EDFF)),
      '2' => (AppColors.success, const Color(0xFFDCF5E6)),
      '3' => (AppColors.wine, const Color(0xFFFFE4D8)),
      _ => (AppColors.muted, const Color(0x0F002B99)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        InterviewDict.sessionStatus(session.status),
        style: TextStyle(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 选择结果

class _JobPick {
  const _JobPick.job(this.jobName) : profile = null, custom = false;
  const _JobPick.profile(JobProfileM this.profile)
    : jobName = '',
      custom = false;
  const _JobPick.custom() : jobName = '', profile = null, custom = true;

  final String jobName;
  final JobProfileM? profile;
  final bool custom;
}

class _ResumePick {
  const _ResumePick(this.id, this.name);
  final int? id;
  final String name;
}

// ------------------------------------------------------------------ 目标岗位弹层

class _JobPickerSheet extends StatefulWidget {
  const _JobPickerSheet({required this.profiles});
  final List<JobProfileM> profiles;

  @override
  State<_JobPickerSheet> createState() => _JobPickerSheetState();
}

class _JobPickerSheetState extends State<_JobPickerSheet> {
  final _search = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _keyword.trim();
    final presets = keyword.isEmpty
        ? kJobPresets
        : kJobPresets.where((e) => e.contains(keyword)).toList();
    final showProfiles = keyword.isEmpty && widget.profiles.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            _sheetTitle('目标岗位'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: '搜索职位',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                        onChanged: (v) => setState(() => _keyword = v),
                      ),
                    ),
                    if (_keyword.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _search.clear();
                          setState(() => _keyword = '');
                        },
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (showProfiles) ...[
                    _sheetSectionLabel('我的岗位画像'),
                    for (final p in widget.profiles)
                      _sheetOption(
                        title: p.jobName.isEmpty ? '职位不限' : p.jobName,
                        subtitle: p.summary,
                        active: false,
                        onTap: () => Navigator.pop(
                          context,
                          _JobPick.profile(p),
                        ),
                      ),
                    const SizedBox(height: 6),
                  ],
                  _sheetSectionLabel('预设职位'),
                  for (final job in presets)
                    _sheetOption(
                      title: job,
                      active: false,
                      onTap: () => Navigator.pop(context, _JobPick.job(job)),
                    ),
                  if (presets.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Text(
                        '没有匹配的预设职位，可点下方「自定义输入」',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  side: const BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () =>
                    Navigator.pop(context, const _JobPick.custom()),
                child: const Text(
                  '自定义输入',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 参考简历弹层

class _ResumePickerSheet extends StatelessWidget {
  const _ResumePickerSheet({
    required this.resumes,
    required this.selectedId,
  });

  final List<ResumeItem> resumes;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle('参考简历'),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                _sheetOption(
                  title: '不使用简历',
                  active: selectedId == null,
                  onTap: () =>
                      Navigator.pop(context, const _ResumePick(null, '')),
                ),
                for (final r in resumes)
                  _sheetOption(
                    title: r.parseStatus == '2'
                        ? r.resumeName
                        : '${r.resumeName}（未解析）',
                    active: selectedId == r.id,
                    onTap: () => Navigator.pop(
                      context,
                      _ResumePick(r.id, r.resumeName),
                    ),
                  ),
                if (resumes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Text(
                      '暂无简历，将按岗位通用要求出题',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 文本输入弹窗

/// 自持 TextEditingController 的输入弹窗。
///
/// 不能在 showDialog 返回后立刻 dispose controller：弹窗退场动画仍会重建 TextField。
class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.hint,
    this.initial = '',
    this.keyboardType = TextInputType.text,
  });

  final String title;
  final String hint;
  final String initial;
  final TextInputType keyboardType;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void initState() {
    super.initState();
    if (widget.initial.isNotEmpty) {
      // 预填时全选，用户直接输入即可覆盖，不会拼在原值后面。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ 弹层小组件

Widget _sheetTitle(String title) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
  child: Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
      ),
    ],
  ),
);

Widget _sheetSectionLabel(String label) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
  child: Text(
    label,
    style: const TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: AppColors.muted,
    ),
  ),
);

Widget _sheetOption({
  required String title,
  String? subtitle,
  required bool active,
  required VoidCallback onTap,
}) => InkWell(
  onTap: onTap,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? AppColors.blue : AppColors.ink,
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (active) const Icon(Icons.check, size: 18, color: AppColors.blue),
      ],
    ),
  ),
);
