import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../interview/data/interview_models.dart';
import '../../interview/data/interview_providers.dart';
import '../data/jobs_models.dart';
import '../data/jobs_providers.dart';
import 'apply_sheet.dart';

/// 档案纸上的细线 / 深线，取自设计稿 --line / --line-2。
const Color _line = Color(0x22121729);
const Color _line2 = Color(0x57121729);
const Color _paperHi = AppColors.white;
const Color _paperDim = Color(0xFFEFE5CC);
const String _serif = 'serif';

/// 岗位 Tab：在招岗位列表（搜索 + 分页）+ 二级入口（我的投递 / 面试邀约）。
///
/// 视觉重设计：档案纸底 + 衬线标题 + 职位流（编号式信息层级、酒红薪资位、企业直聊行）。
class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  static const int _pageSize = 10;

  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  int _page = 1;
  int _total = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  String? _keyword;
  final List<JobSummary> _items = [];

  /// 0 = 推荐（服务端顺序），1 = 最新（按发布时间倒序）。
  int _sortTab = 0;

  /// 本地筛选条件。
  String? _industry;
  String? _location;
  bool _onlyOpen = false;

  /// 未处理邀约数（用于二级入口角标；失败则不显示）。
  int _pendingInvites = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load(reset: true);
      _loadInviteBadge();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _load();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final keyword = value.trim();
      _keyword = keyword.isEmpty ? null : keyword;
      _load(reset: true);
    });
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (!reset && !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _hasMore = true;
        _items.clear();
      }
    });
    try {
      // 默认画像为空串表示「不限」，接口层自动忽略，等价于不带推荐条件。
      final profile = _defaultProfileForLoad();
      _usedProfileSig = _profileSignature(profile);
      final (rows, total) = await ref
          .read(jobsRepositoryProvider)
          .jobList(
            pageNum: _page,
            pageSize: _pageSize,
            keyword: _keyword,
            industry: profile?.industry,
            city: profile?.city,
            jobKeyword: profile?.jobName,
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(rows);
        _total = total;
        _hasMore = _items.length < total;
        _page += 1;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 供异步流程读取默认画像（不能在 build 之外 watch）。
  JobProfileM? _defaultProfileForLoad() {
    final profiles =
        ref.read(jobProfileListProvider).asData?.value ??
        const <JobProfileM>[];
    for (final profile in profiles) {
      if (profile.isDefault) return profile;
    }
    return null;
  }

  Future<void> _loadInviteBadge() async {
    try {
      final (rows, _) = await ref
          .read(jobsRepositoryProvider)
          .inviteList(pageNum: 1, pageSize: 50);
      if (!mounted) return;
      setState(() => _pendingInvites = rows.where((e) => e.isPending).length);
    } catch (_) {
      if (mounted) setState(() => _pendingInvites = 0);
    }
  }

  Future<void> _apply(JobSummary job) async {
    final ok = await showApplySheet(context: context, job: job);
    if (ok == true) {
      _load(reset: true);
      _loadInviteBadge();
    }
  }

  void _openApplications() {
    context.push('/jobs/applications').then((_) => _load(reset: true));
  }

  void _openInvites() {
    context.push('/jobs/invites').then((_) {
      _load(reset: true);
      _loadInviteBadge();
    });
  }

  /// 当前展示的岗位：本地筛选 + 排序，不动服务端分页。
  ///
  /// 命中默认目标画像的岗位始终置顶（服务端已排序，此处兜底「最新」排序）。
  List<JobSummary> get _visible {
    var list = _items.where((job) {
      if (_onlyOpen && job.applied) return false;
      if (_industry != null && job.industryText != _industry) return false;
      if (_location != null && job.workLocation != _location) return false;
      return true;
    }).toList();
    if (_sortTab == 1) {
      list = list.toList()
        ..sort(
          (a, b) => (b.publishDate.isEmpty ? '' : b.publishDate).compareTo(
            a.publishDate.isEmpty ? '' : a.publishDate,
          ),
        );
    }
    if (list.any((job) => job.isRecommended)) {
      final matched = list.where((job) => job.isRecommended).toList();
      final rest = list.where((job) => !job.isRecommended).toList();
      return [...matched, ...rest];
    }
    return list;
  }

  List<String> get _industries {
    final set = <String>{};
    for (final job in _items) {
      if (job.industryText.isNotEmpty) set.add(job.industryText);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get _locations {
    final set = <String>{};
    for (final job in _items) {
      if (job.workLocation.isNotEmpty) set.add(job.workLocation);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// 默认目标岗位画像；未显式设默认时返回 null（列表全部展示，不做推荐置顶）。
  JobProfileM? get _defaultProfile {
    final profiles =
        ref.watch(jobProfileListProvider).asData?.value ??
        const <JobProfileM>[];
    for (final profile in profiles) {
      if (profile.isDefault) return profile;
    }
    return null;
  }

  /// 画像参数签名：默认画像切换后据此触发列表重载，让推荐结果同步更新。
  String _profileSignature(JobProfileM? profile) => profile == null
      ? ''
      : '${profile.industry}|${profile.city}|${profile.jobName}';

  /// 已用于拉取列表的画像签名（避免重复加载）。
  String _usedProfileSig = '';

  JobProfileM? _pickDefault(List<JobProfileM>? list) {
    if (list == null) return null;
    for (final profile in list) {
      if (profile.isDefault) return profile;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // 默认画像加载完成或被切换后重载列表，让推荐置顶与角标同步更新。
    ref.listen(jobProfileListProvider, (previous, next) {
      final sig = _profileSignature(_pickDefault(next.asData?.value));
      if (sig != _usedProfileSig) {
        _usedProfileSig = sig;
        _load(reset: true);
      }
    });
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          _searchRow(),
          _profileMatch(),
          _toolbar(),
          Expanded(child: _list()),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ 页头

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Row(
        children: [
          Text(
            '岗位',
            style: const TextStyle(
              fontFamily: _serif,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
              height: 1.2,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '$_total 个在招',
              style: const TextStyle(
                fontSize: 9,
                letterSpacing: 1.2,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          _entryPill(),
          const SizedBox(width: 7),
          _inviteBell(),
        ],
      ),
    );
  }

  /// 「我的投递」——沿用设计稿 loc-btn 的胶囊样式。
  Widget _entryPill() {
    return GestureDetector(
      onTap: _openApplications,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _paperHi,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: const [
            Icon(
              Icons.assignment_turned_in_outlined,
              size: 12,
              color: AppColors.muted,
            ),
            SizedBox(width: 4),
            Text(
              '我的投递',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 「面试邀约」——圆形铃铛按钮 + 红点角标。
  Widget _inviteBell() {
    return GestureDetector(
      onTap: _openInvites,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _paperHi,
              shape: BoxShape.circle,
              border: Border.all(color: _line),
            ),
            child: const Icon(
              Icons.notifications_none,
              size: 16,
              color: AppColors.ink,
            ),
          ),
          if (_pendingInvites > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 15),
                height: 15,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cream, width: 1.5),
                ),
                child: Text(
                  _pendingInvites > 99 ? '99+' : '$_pendingInvites',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ 搜索

  Widget _searchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _paperHi,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 16, color: AppColors.muted),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 12, color: AppColors.ink),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '搜索职位 / 公司',
                  hintStyle: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (value) {
                  _debounce?.cancel();
                  final keyword = value.trim();
                  _keyword = keyword.isEmpty ? null : keyword;
                  _load(reset: true);
                },
              ),
            ),
            if (_search.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _search.clear();
                  _keyword = null;
                  _load(reset: true);
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
    );
  }

  // ------------------------------------------------------------------ 岗位画像

  Widget _profileMatch() {
    final profile = _defaultProfile;
    final summary = profile?.summary ?? '';
    final hasProfile = profile != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/interview/job-profile').then((_) {
          ref.invalidate(jobProfileListProvider);
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _paperHi,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0x0F6B001B),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0x1F6B001B)),
                ),
                child: const Icon(
                  Icons.my_location,
                  size: 15,
                  color: AppColors.wine,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          hasProfile ? '目标岗位 · 默认' : '目标岗位 · 未设置',
                          style: const TextStyle(
                            fontSize: 8,
                            letterSpacing: .8,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (summary.isNotEmpty)
                          Flexible(
                            child: Text(
                              summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasProfile
                          ? '已按目标岗位推荐 · 匹配岗位置顶并标记「推荐」'
                          : '设置目标岗位后，匹配岗位会置顶并标记「推荐」',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasProfile ? '调整画像' : '去设置',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blue,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: AppColors.blue,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ 工具栏

  Widget _toolbar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _tabButton('推荐', 0),
                const SizedBox(width: 22),
                _tabButton('最新', 1),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openFilterSheet,
            child: const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_alt_outlined,
                    size: 14,
                    color: AppColors.muted,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '筛选',
                    style: TextStyle(fontSize: 11, color: AppColors.ink),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 筛选弹窗：行业 / 地点 / 仅看未投递，选中即时生效。
  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void apply(VoidCallback change) {
            setState(change);
            setSheetState(() {});
          }

          Widget chip(String label, bool active, VoidCallback onTap) =>
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: active ? AppColors.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: active ? AppColors.ink : _line2),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: active ? AppColors.cream : AppColors.ink,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );

          Widget section(String title, Widget content) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              content,
            ],
          );

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '筛选',
                      style: TextStyle(
                        fontFamily: _serif,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    section(
                      '行业',
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          chip(
                            '全部',
                            _industry == null,
                            () => apply(() => _industry = null),
                          ),
                          for (final value in _industries)
                            chip(
                              value,
                              _industry == value,
                              () => apply(() => _industry = value),
                            ),
                        ],
                      ),
                    ),
                    if (_locations.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      section(
                        '地点',
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            chip(
                              '全部',
                              _location == null,
                              () => apply(() => _location = null),
                            ),
                            for (final value in _locations)
                              chip(
                                value,
                                _location == value,
                                () => apply(() => _location = value),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          '仅看未投递',
                          style: TextStyle(fontSize: 12, color: AppColors.ink),
                        ),
                        const Spacer(),
                        Switch(
                          value: _onlyOpen,
                          activeThumbColor: AppColors.blue,
                          onChanged: (value) => apply(() => _onlyOpen = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '查看结果',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final active = _sortTab == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _sortTab = index),
      child: Container(
        padding: const EdgeInsets.only(top: 7, bottom: 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.wine : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: active ? AppColors.ink : AppColors.muted,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ 列表

  Widget _list() {
    if (_items.isEmpty && _loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blue),
      );
    }
    if (_items.isEmpty && _error != null) {
      return _errorView(_error!);
    }
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            '暂时没有在招岗位\n换个关键词试试',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.7),
          ),
        ),
      );
    }
    final visible = _visible;
    return RefreshIndicator(
      color: AppColors.blue,
      onRefresh: () => _load(reset: true),
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                '当前筛选条件下没有岗位\n调整筛选或清空关键词试试',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
                  height: 1.7,
                ),
              ),
            )
          else
            for (var i = 0; i < visible.length; i++)
              _jobRow(visible[i], first: i == 0),
          _footer(visible.isEmpty),
        ],
      ),
    );
  }

  Widget _footer(bool filteredEmpty) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.blue,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          _error != null
              ? '加载失败 · 下拉重试'
              : filteredEmpty
              ? '— 已显示全部 —'
              : '加载更多岗位 · 共 $_total 个',
          style: const TextStyle(
            fontSize: 8.5,
            letterSpacing: 1.3,
            color: AppColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _jobRow(JobSummary job, {required bool first}) {
    final companyLine = [
      job.tenantName.isEmpty ? '未知企业' : job.tenantName,
      if (job.industryText.isNotEmpty) job.industryText,
      if (job.workLocation.isNotEmpty) job.workLocation,
    ].join(' · ');
    final hiring = (job.recruitCount ?? 0) > 0
        ? '招 ${job.recruitCount} 人'
        : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          context.push('/jobs/${job.id}').then((_) => _load(reset: true)),
      child: Container(
        padding: EdgeInsets.only(top: first ? 8 : 12, bottom: 11),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: first ? Colors.transparent : _line),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    job.jobName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.4,
                    ),
                  ),
                ),
                if (hiring != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    hiring,
                    style: const TextStyle(
                      fontFamily: _serif,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.wine,
                      height: 1,
                      letterSpacing: -.2,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            Text(
              companyLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                if (job.isRecommended)
                  _tag('推荐', AppColors.wine, const Color(0x0F6B001B)),
                if (job.applied)
                  _tag('已投递', AppColors.success, const Color(0x12186F45)),
                if (job.industryText.isNotEmpty) _tag(job.industryText),
                if (job.workLocation.isNotEmpty) _tag(job.workLocation),
                if (job.publishDate.isNotEmpty) _tag('发布于 ${job.publishDate}'),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _paperDim,
                    shape: BoxShape.circle,
                    border: Border.all(color: _line),
                  ),
                  child: Text(
                    _companyMark(job.tenantName),
                    style: const TextStyle(
                      fontFamily: _serif,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        job.tenantName.isEmpty
                            ? '企业招聘'
                            : '${job.tenantName} · 招聘',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2B3448),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            job.applied ? '投递已送达，等待企业查看' : '在招中 · 可直接投递',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: job.applied ? _openApplications : () => _apply(job),
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: job.applied ? Colors.transparent : AppColors.blue,
                      borderRadius: BorderRadius.circular(16),
                      border: job.applied ? Border.all(color: _line2) : null,
                    ),
                    child: Text(
                      job.applied ? '查看进度' : '立即投递',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: job.applied
                            ? AppColors.ink
                            : const Color(0xFFFBF4E2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _companyMark(String name) {
    final text = name.trim();
    if (text.isEmpty) return '企';
    return text.substring(0, 1);
  }

  Widget _tag(String text, [Color? fg, Color? bg]) {
    final color = fg ?? const Color(0xFF2B3448);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg ?? Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: fg == null ? _line2 : fg.withValues(alpha: .32),
          width: .8,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 8.5, color: color, letterSpacing: .2),
      ),
    );
  }

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.muted,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 42,
              child: FilledButton(
                onPressed: () => _load(reset: true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '重新加载',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
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
