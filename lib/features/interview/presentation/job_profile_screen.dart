import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../features/interview/data/interview_providers.dart';
import '../../../features/interview/data/interview_models.dart';
import '../../../features/interview/data/job_presets.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/mlf_widgets.dart';

/// 岗位画像（求职期望）管理：列表 + 新增/编辑页。
///
/// 四个维度：期望职位、工作城市（多选）、薪资要求、期望行业。
/// 空串统一表示「不限」，后端 `student_job_profile.city / salary / industry`
/// 亦以空串存「不限」，避免把「不限」写进 AI 出题参数。
const _hotCities = <String>[
  '北京',
  '上海',
  '广州',
  '深圳',
  '杭州',
  '成都',
  '重庆',
  '武汉',
  '西安',
  '南京',
  '苏州',
  '天津',
  '长沙',
  '郑州',
  '青岛',
  '合肥',
  '福州',
  '厦门',
  '济南',
  '大连',
  '宁波',
  '无锡',
  '东莞',
  '佛山',
  '昆明',
  '贵阳',
  '南昌',
  '石家庄',
  '太原',
  '南宁',
  '兰州',
  '海口',
  '哈尔滨',
  '长春',
  '沈阳',
  '乌鲁木齐',
  '呼和浩特',
  '银川',
  '西宁',
  '拉萨',
];

const _salaryRanges = <String>[
  '3K 以下',
  '3-5K',
  '5-8K',
  '8-10K',
  '10-15K',
  '15-20K',
  '20-30K',
  '30-50K',
  '50K 以上',
  '面议',
];

/// 行业码：与岗位侧 `industry_type` 字典一致，空串 = 行业不限。
const _industryOptions = <({String v, String label})>[
  (v: '', label: '行业不限'),
  (v: '1', label: '互联网'),
  (v: '2', label: '金融'),
  (v: '3', label: '制造业'),
  (v: '4', label: '教育培训'),
  (v: '5', label: '文化娱乐'),
  (v: '6', label: '人工智能'),
  (v: '7', label: '通用'),
  (v: '8', label: '企业服务'),
];

String _industryLabel(String v) => _industryOptions
    .firstWhere((e) => e.v == v, orElse: () => (v: '', label: '行业不限'))
    .label;

class JobProfileScreen extends ConsumerStatefulWidget {
  const JobProfileScreen({super.key});

  @override
  ConsumerState<JobProfileScreen> createState() => _JobProfileScreenState();
}

class _JobProfileScreenState extends ConsumerState<JobProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(jobProfileListProvider);
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '目标岗位画像',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.blue),
            onPressed: () => _openForm(null),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          error: '$e',
          onRetry: () => ref.invalidate(jobProfileListProvider),
        ),
        data: (list) => list.isEmpty
            ? const _EmptyView()
            : RefreshIndicator(
                onRefresh: () => ref.refresh(jobProfileListProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _ProfileCard(
                    profile: list[i],
                    onEdit: () => _openForm(list[i]),
                    onDelete: () => _confirmDelete(list[i]),
                    onSetDefault: () => _setDefault(list[i]),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _openForm(JobProfileM? editing) async {
    final result = await context.push<bool>(
      '/interview/job-profile/edit',
      extra: editing,
    );
    if (result == true && mounted) {
      ref.invalidate(jobProfileListProvider);
      showToast(context, editing == null ? '求职期望已创建' : '求职期望已更新');
    }
  }

  /// 一键把某条画像切换为当前默认目标。
  Future<void> _setDefault(JobProfileM p) async {
    try {
      await ref
          .read(interviewRepositoryProvider)
          .updateJobProfile(
            id: p.id,
            industry: p.industry,
            jobName: p.jobName,
            city: p.city,
            salary: p.salary,
            isDefault: true,
          );
      if (!mounted) return;
      ref.invalidate(jobProfileListProvider);
      showToast(context, '已将「${_profileTitle(p)}」设为默认画像');
    } catch (e) {
      if (mounted) showToast(context, '切换失败：$e');
    }
  }

  Future<void> _confirmDelete(JobProfileM p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除岗位画像'),
        content: Text('确定删除「${_profileTitle(p)}」吗？删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '删除',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(interviewRepositoryProvider).deleteJobProfile(p.id);
      if (mounted) {
        ref.invalidate(jobProfileListProvider);
        showToast(context, '岗位画像已删除');
      }
    } catch (e) {
      if (mounted) showToast(context, '删除失败：$e');
    }
  }
}

String _profileTitle(JobProfileM p) =>
    p.jobName.isEmpty ? '职位不限的画像' : p.jobName;

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });
  final JobProfileM profile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.jobName.isEmpty ? '期望职位不限' : profile.jobName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (profile.isDefault)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    '默认',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.edit_note_outlined,
                  color: AppColors.blue,
                  size: 20,
                ),
                onPressed: onEdit,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                  size: 20,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(
                profile.cities.isEmpty ? '城市不限' : profile.cities.join('、'),
                AppColors.blue,
              ),
              _chip(
                profile.salary.isEmpty ? '薪资不限' : profile.salary,
                AppColors.wine,
              ),
              _chip(
                profile.industry.isEmpty
                    ? '行业不限'
                    : InterviewDict.industry(profile.industry),
                Colors.grey,
              ),
            ],
          ),
          if (!profile.isDefault) ...[
            const SizedBox(height: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSetDefault,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.radio_button_unchecked,
                    size: 14,
                    color: AppColors.blue,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '设为默认目标',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// 新增 / 编辑求职期望（整页表单，样式对齐设计稿）。
class JobProfileEditScreen extends ConsumerStatefulWidget {
  const JobProfileEditScreen({super.key, this.profile});

  final JobProfileM? profile;

  @override
  ConsumerState<JobProfileEditScreen> createState() =>
      _JobProfileEditScreenState();
}

class _JobProfileEditScreenState extends ConsumerState<JobProfileEditScreen> {
  late String _jobName;
  late Set<String> _cities;
  late String _salary;
  late String _industry;
  bool _busy = false;

  bool get _editing => widget.profile != null;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _jobName = p?.jobName ?? '';
    _cities = {...?p?.cities};
    _salary = p?.salary ?? '';
    _industry = p?.industry ?? '';
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(interviewRepositoryProvider);
      final p = widget.profile;
      if (p == null) {
        final list =
            ref.read(jobProfileListProvider).asData?.value ??
            const <JobProfileM>[];
        await repo.createJobProfile(
          industry: _industry,
          jobName: _jobName,
          city: _cities.join(','),
          salary: _salary,
          isDefault: list.isEmpty,
        );
      } else {
        await repo.updateJobProfile(
          id: p.id,
          industry: _industry,
          jobName: _jobName,
          city: _cities.join(','),
          salary: _salary,
          isDefault: p.isDefault,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showToast(context, '保存失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickJob() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _JobPickerSheet(selected: _jobName),
    );
    if (value != null) setState(() => _jobName = value);
  }

  Future<void> _pickCities() async {
    final value = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _CityPickerSheet(selected: _cities),
    );
    if (value != null) setState(() => _cities = value);
  }

  Future<void> _pickSalary() async {
    final value = await _showOptionSheet(
      title: '薪资要求',
      selected: _salary,
      options: [
        (v: '', label: '薪资不限'),
        ..._salaryRanges.map((e) => (v: e, label: e)),
      ],
    );
    if (value != null) setState(() => _salary = value);
  }

  Future<void> _pickIndustry() async {
    final value = await _showOptionSheet(
      title: '期望行业',
      selected: _industry,
      options: _industryOptions,
    );
    if (value != null) setState(() => _industry = value);
  }

  Future<String?> _showOptionSheet({
    required String title,
    required String selected,
    required List<({String v, String label})> options,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetTitle(title),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 20,
                  endIndent: 20,
                  color: AppColors.line,
                ),
                itemBuilder: (_, i) {
                  final option = options[i];
                  final active = option.v == selected;
                  return InkWell(
                    onTap: () => Navigator.pop(sheetContext, option.v),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: active
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: active ? AppColors.blue : AppColors.ink,
                              ),
                            ),
                          ),
                          if (active)
                            const Icon(
                              Icons.check,
                              size: 18,
                              color: AppColors.blue,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 6, top: 4),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  Text(
                    _editing ? '编辑求职期望' : '新增求职期望',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '我们会据此为你定制面试题目，让练习更贴近目标岗位',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.6,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      children: [
                        _formRow(
                          label: '期望职位',
                          value: _jobName.isEmpty ? '请选择期望职位' : _jobName,
                          placeholder: _jobName.isEmpty,
                          onTap: _pickJob,
                        ),
                        _rowDivider(),
                        _formRow(
                          label: '工作城市',
                          value: _cities.isEmpty ? '城市不限' : _cities.join('、'),
                          onTap: _pickCities,
                        ),
                        _rowDivider(),
                        _formRow(
                          label: '薪资要求',
                          value: _salary.isEmpty ? '薪资不限' : _salary,
                          onTap: _pickSalary,
                        ),
                        _rowDivider(),
                        _formRow(
                          label: '期望行业',
                          value: _industryLabel(_industry),
                          onTap: _pickIndustry,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: MlfPrimaryButton(
                label: '保存',
                loading: _busy,
                onPressed: _busy ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formRow({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool placeholder = false,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 15, 14, 15),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: placeholder ? AppColors.muted : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
        ],
      ),
    ),
  );

  Widget _rowDivider() => const Divider(
    height: 1,
    thickness: 1,
    indent: 18,
    endIndent: 18,
    color: AppColors.line,
  );
}

/// 期望职位选择：预设列表 + 搜索 + 不限。
class _JobPickerSheet extends StatefulWidget {
  const _JobPickerSheet({required this.selected});
  final String selected;

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
    final items = keyword.isEmpty
        ? kJobPresets
        : kJobPresets.where((e) => e.contains(keyword)).toList();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            _sheetTitle('期望职位'),
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
                    const Icon(Icons.search, size: 18, color: AppColors.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        autofocus: false,
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
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: items.length + 1,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 20,
                  endIndent: 20,
                  color: AppColors.line,
                ),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return _optionRow(
                      label: '职位不限',
                      active: widget.selected.isEmpty,
                      onTap: () => Navigator.pop(context, ''),
                    );
                  }
                  final job = items[i - 1];
                  return _optionRow(
                    label: job,
                    active: job == widget.selected,
                    onTap: () => Navigator.pop(context, job),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 工作城市多选 + 不限。
class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet({required this.selected});
  final Set<String> selected;

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  late Set<String> _temp;

  @override
  void initState() {
    super.initState();
    _temp = {...widget.selected};
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            _sheetTitle('工作城市（可多选）'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    _cityChip(
                      label: '城市不限',
                      active: _temp.isEmpty,
                      onTap: () => setState(() => _temp = <String>{}),
                    ),
                    ..._hotCities.map(
                      (city) => _cityChip(
                        label: city,
                        active: _temp.contains(city),
                        onTap: () => setState(() {
                          if (_temp.contains(city)) {
                            _temp.remove(city);
                          } else {
                            _temp.add(city);
                          }
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: MlfPrimaryButton(
                label: '确定',
                onPressed: () => Navigator.pop(context, _temp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cityChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE7EDFF) : AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? AppColors.blue : AppColors.line,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          color: active ? AppColors.blue : AppColors.ink,
        ),
      ),
    ),
  );
}

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

Widget _optionRow({
  required String label,
  required bool active,
  required VoidCallback onTap,
}) => InkWell(
  onTap: onTap,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              color: active ? AppColors.blue : AppColors.ink,
            ),
          ),
        ),
        if (active) const Icon(Icons.check, size: 18, color: AppColors.blue),
      ],
    ),
  ),
);

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 42, color: AppColors.danger),
        const SizedBox(height: 10),
        Text(
          '加载失败：$error',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onRetry,
          child: const Text(
            '重试',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_outlined, size: 46, color: AppColors.muted),
          SizedBox(height: 10),
          Text(
            '还没有目标岗位画像',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '点右上角 + 新建一个，AI 会据此定向出题',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}
