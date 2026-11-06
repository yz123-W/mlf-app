import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../data/questions_models.dart';
import '../data/questions_providers.dart';

/// 题库：运营公共题库浏览（行业 / 题型 / 技能方向 / 难度 +「高频真题」专场）。
///
/// 数据来源 `/interview/bank/list|options|packs`；收藏走 `/interview/favorite/*`。
/// 分类导航与 Web 学生端题库页一致：行业计数为全库口径，题型随行业统计，
/// 技能方向与难度随「行业 + 题型」统计，0 题分类不展示。
class QuestionsScreen extends ConsumerStatefulWidget {
  const QuestionsScreen({super.key});

  @override
  ConsumerState<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends ConsumerState<QuestionsScreen> {
  static const int _pageSize = 10;
  static const int _randomPool = 50;

  final _search = TextEditingController();
  final _scroll = ScrollController();

  int _tab = 0; // 0 = 全部，1 = 高频真题
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  final List<Question> _items = [];

  /// 全库行业页签（题数为全库口径，不随筛选变化）。
  List<NameCountOption> _industries = const [];
  List<NameCountOption> _types = const [];
  List<SkillFamilyOption> _skills = const [];
  List<String> _difficulties = const [];

  String? _industry;
  String? _type;
  int? _skillFamilyId;
  String? _difficulty;
  String? _keyword;
  int? _packId;
  String? _packName;

  /// 进入专场前的行业，退出专场后恢复，避免列表落回「全部行业」。
  String? _industryBeforePack;

  /// 筛选项请求序号：快速切换时只应用最后一次结果。
  int _optionsSeq = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  /// 先取筛选项，确定默认行业页签后再加载列表（与 Web 同序）。
  Future<void> _bootstrap() async {
    try {
      final options = await ref.read(
        questionOptionsProvider((industry: null, type: null)).future,
      );
      if (!mounted) return;
      NameCountOption? firstIndustry;
      for (final item in options.industries) {
        if (item.count > 0) {
          firstIndustry = item;
          break;
        }
      }
      setState(() {
        _industries = options.industries;
        _types = options.types;
        _skills = options.skillFamilies;
        _difficulties = options.difficulties;
        _industry = firstIndustry?.name;
      });
    } catch (_) {
      // 筛选项加载失败不阻塞列表，用户仍可浏览全部题目。
    }
    if (!mounted) return;
    await _refreshScopedOptions();
    await _load(reset: true);
  }

  /// 按当前「行业 + 题型」刷新题型 / 技能方向 / 难度及题数。
  Future<void> _refreshScopedOptions() async {
    final seq = ++_optionsSeq;
    try {
      final data = await ref.read(
        questionOptionsProvider((industry: _industry, type: _type)).future,
      );
      if (!mounted || seq != _optionsSeq) return;
      setState(() {
        _types = data.types;
        _skills = data.skillFamilies;
        _difficulties = data.difficulties;
      });
    } catch (_) {
      // 刷新失败保留旧筛选项，避免筛选区闪空。
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _load();
    }
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
      final page = await ref.read(questionsRepositoryProvider).list(
            pageNum: _page,
            pageSize: _pageSize,
            type: _type,
            industry: _industry,
            difficulty: _difficulty,
            skillFamilyId: _skillFamilyId,
            keyword: _keyword,
            packId: _packId,
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = _items.length < page.total;
        _page += 1;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _randomOne() async {
    showToast(context, '正在随机抽取一题…');
    try {
      final repo = ref.read(questionsRepositoryProvider);
      final page = await repo.list(
        pageNum: 1,
        pageSize: _randomPool,
        type: _type,
        industry: _industry,
        difficulty: _difficulty,
        skillFamilyId: _skillFamilyId,
      );
      if (!mounted) return;
      if (page.items.isEmpty) {
        showToast(context, '暂时没有可抽取的题目');
        return;
      }
      final pick = page.items[math.Random().nextInt(page.items.length)];
      context.push('/question/${pick.id}');
    } catch (e) {
      if (mounted) showToast(context, '$e');
    }
  }

  /// 切换行业：清空下层筛选（题型 / 方向 / 难度），并让筛选项按新行业重新统计。
  void _selectIndustry(String name) {
    if (_industry == name) return;
    setState(() {
      _industry = name;
      _type = null;
      _skillFamilyId = null;
      _difficulty = null;
    });
    _refreshScopedOptions();
    _load(reset: true);
  }

  /// 切换题型：技能方向口径随之变化，先清空已选方向避免筛出空列表。
  void _selectType(String? name) {
    if (_type == name) return;
    setState(() {
      _type = name;
      _skillFamilyId = null;
    });
    _refreshScopedOptions();
    _load(reset: true);
  }

  void _selectSkill(int? id) {
    if (_skillFamilyId == id) return;
    setState(() => _skillFamilyId = id);
    _load(reset: true);
  }

  void _selectDifficulty(String? value) {
    if (_difficulty == value) return;
    setState(() => _difficulty = value);
    _load(reset: true);
  }

  void _openPack(QuestionPack pack) {
    setState(() {
      _industryBeforePack = _industry;
      _packId = pack.id;
      _packName = pack.name;
      _tab = 0;
      _industry = null;
      _type = null;
      _skillFamilyId = null;
      _difficulty = null;
    });
    _load(reset: true);
  }

  void _clearPack() {
    setState(() {
      _packId = null;
      _packName = null;
      _industry = _industryBeforePack;
    });
    _refreshScopedOptions();
    _load(reset: true);
  }

  Future<void> _toggleFavorite(int questionId) async {
    final wasFavorited =
        ref.read(favoriteIdsProvider).asData?.value.contains(questionId) ?? false;
    try {
      await ref.read(favoriteIdsProvider.notifier).toggle(questionId);
      if (!mounted) return;
      showToast(context, wasFavorited ? '已取消收藏' : '已收藏');
    } catch (_) {
      if (!mounted) return;
      showToast(context, '操作失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoriteIds = ref.watch(favoriteIdsProvider).asData?.value ?? const <int>{};
    final showFilters = _tab == 0 && _packId == null;
    final hasSecondary = _skillFamilyId != null || _difficulty != null;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          _searchRow(),
          const SizedBox(height: 12),
          _tabs(),
          const SizedBox(height: 6),
          if (showFilters) _filterBar(),
          if (showFilters && hasSecondary) _activeSecondaryRow(),
          if (_tab == 0 && _packName != null) _activePackChip(),
          const SizedBox(height: 4),
          Expanded(
            child: _tab == 0 ? _questionList(favoriteIds) : _packList(),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 12, 8),
      child: Row(
        children: [
          const Text('题库', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const Spacer(),
          IconButton(
            tooltip: '我的收藏',
            onPressed: () => context.push('/profile/favorites'),
            icon: const Icon(Icons.bookmark_border, color: AppColors.blue),
          ),
        ],
      ),
    );
  }

  Widget _searchRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 19, color: AppColors.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: 14, color: AppColors.ink),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '搜索题号 / 题干关键词',
                        hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
                      ),
                      onSubmitted: (value) {
                        _keyword = value.trim().isEmpty ? null : value.trim();
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
                      child: const Icon(Icons.close, size: 17, color: AppColors.muted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _randomOne,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.primaryButton,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.casino_outlined, size: 17, color: Colors.white),
                  SizedBox(width: 5),
                  Text('随机一题',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0x0F002B99),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _tabItem('全部题目', 0),
            _tabItem('高频真题', 1),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(String label, int index) {
    final current = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
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

  static const TextStyle _rowLabelStyle = TextStyle(
    color: AppColors.muted,
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  /// 分类导航只保留两行：行业（主导航）+ 题型。
  /// 技能方向与难度属于低频筛选，收进「筛选」弹层，避免手机上多行 chips 显得臃肿。
  Widget _filterBar() {
    final industries = _industries.where((e) => e.count > 0).toList();
    final types = _types.where((e) => e.count > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (industries.isNotEmpty)
          _chipRow('行业', [
            for (final item in industries)
              _SelectChip(
                label: item.name,
                count: item.count,
                active: _industry == item.name,
                onTap: () => _selectIndustry(item.name),
              ),
          ]),
        if (types.isNotEmpty || _skills.isNotEmpty || _difficulties.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: SizedBox(
              height: 32,
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Center(child: Text('题型', style: _rowLabelStyle)),
                  ),
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _SelectChip(
                          label: '全部',
                          active: _type == null,
                          onTap: () => _selectType(null),
                        ),
                        for (final item in types)
                          _SelectChip(
                            label: item.name,
                            count: item.count,
                            active: _type == item.name,
                            onTap: () => _selectType(item.name),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 18, top: 3),
                    child: _filterButton(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 次级筛选入口：技能方向 + 难度在弹层里选择，确认后一次性回写并刷新列表。
  Widget _filterButton() {
    final active = _skillFamilyId != null || _difficulty != null;
    return GestureDetector(
      onTap: _openFilterSheet,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE7EDFF) : AppColors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: active ? AppColors.blue : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 13, color: active ? AppColors.blue : AppColors.muted),
            const SizedBox(width: 4),
            Text(
              '筛选',
              style: TextStyle(
                color: active ? AppColors.blue : AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    if (_skills.isEmpty && _difficulties.isEmpty) return;
    final result = await showModalBottomSheet<_SecondaryFilterResult>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
      ),
      builder: (context) => _SecondaryFilterSheet(
        skills: _skills.where((e) => e.count > 0).toList(),
        difficulties: _difficulties,
        skillId: _skillFamilyId,
        difficulty: _difficulty,
      ),
    );
    if (result == null) return;
    if (result.skillId == _skillFamilyId && result.difficulty == _difficulty) return;
    setState(() {
      _skillFamilyId = result.skillId;
      _difficulty = result.difficulty;
    });
    _load(reset: true);
  }

  /// 已选的方向 / 难度以小标签展示，可单独移除或一键清除。
  Widget _activeSecondaryRow() {
    final skill = _selectedSkill;
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 2, 18, 0),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (skill != null) _activeTag(skill.name, () => _selectSkill(null)),
                  if (_difficulty != null)
                    _activeTag(_difficulty!, () => _selectDifficulty(null)),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: _clearSecondary,
            child: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Text('清除', style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeTag(String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        height: 24,
        padding: const EdgeInsets.only(left: 9, right: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE7EDFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.blue),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.blue, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close, size: 12, color: AppColors.blue),
            ),
          ],
        ),
      ),
    );
  }

  void _clearSecondary() {
    if (_skillFamilyId == null && _difficulty == null) return;
    setState(() {
      _skillFamilyId = null;
      _difficulty = null;
    });
    _load(reset: true);
  }

  SkillFamilyOption? get _selectedSkill {
    final id = _skillFamilyId;
    if (id == null) return null;
    for (final item in _skills) {
      if (item.id == id) return item;
    }
    return null;
  }

  Widget _chipRow(String label, List<Widget> chips) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          SizedBox(
            width: 30,
            child: Center(child: Text(label, style: _rowLabelStyle)),
          ),
          ...chips,
        ],
      ),
    );
  }

  Widget _activePackChip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4D8),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Text('专场：$_packName',
                    style: const TextStyle(color: AppColors.wine, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _clearPack,
                  child: const Icon(Icons.close, size: 14, color: AppColors.wine),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionList(Set<int> favoriteIds) {
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    }
    if (_items.isEmpty && _error != null) {
      return _errorView();
    }
    if (_items.isEmpty) {
      return _emptyView();
    }
    return RefreshIndicator(
      color: AppColors.blue,
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        itemCount: _items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _items.length) return _listFooter();
          final question = _items[index];
          return _questionCard(question, favoriteIds.contains(question.id));
        },
      ),
    );
  }

  Widget _listFooter() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          _error != null ? '加载失败，点击重试' : '没有更多题目了',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ),
    );
  }

  Widget _questionCard(Question question, bool favorited) {
    return MlfCard(
      onTap: () => context.push('/question/${question.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    if (question.type.isNotEmpty) _pill(question.type, AppColors.blue, const Color(0xFFE7EDFF)),
                    if (question.difficulty.isNotEmpty)
                      _pill(question.difficulty, AppColors.wine, const Color(0xFFFFE4D8)),
                    if (question.industry.isNotEmpty) _pill(question.industry, AppColors.ink, const Color(0x0F002B99)),
                  ],
                ),
              ),
              _favoriteButton(question.id, favorited),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            question.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (question.questionNo.isNotEmpty)
                Text(question.questionNo,
                    style: const TextStyle(color: AppColors.muted, fontSize: 11)),
              const Spacer(),
              const Text('查看解析',
                  style: TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w800)),
              const Icon(Icons.chevron_right, size: 16, color: AppColors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _favoriteButton(int questionId, bool favorited) {
    return GestureDetector(
      onTap: () => _toggleFavorite(questionId),
      child: Padding(
        padding: const EdgeInsets.only(left: 6, top: 2),
        child: Icon(
          favorited ? Icons.bookmark : Icons.bookmark_border,
          size: 19,
          color: favorited ? AppColors.wine : AppColors.muted,
        ),
      ),
    );
  }

  Widget _pill(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _packList() {
    final packs = ref.watch(questionPacksProvider);
    return packs.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.blue)),
      error: (error, _) => _errorView(message: '$error', onRetry: () => ref.invalidate(questionPacksProvider)),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text('暂无高频真题专场', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          );
        }
        return RefreshIndicator(
          color: AppColors.blue,
          onRefresh: () async => ref.invalidate(questionPacksProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _packCard(list[index]),
          ),
        );
      },
    );
  }

  Widget _packCard(QuestionPack pack) {
    return MlfCard(
      onTap: () => _openPack(pack),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.blueSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.local_fire_department, color: AppColors.blue, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pack.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                if (pack.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(pack.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                ],
                const SizedBox(height: 6),
                Text('${pack.questionCount} 题',
                    style: const TextStyle(color: AppColors.wine, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }

  Widget _errorView({String message = '数据加载失败', VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.muted, size: 34),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5)),
            const SizedBox(height: 14),
            SizedBox(
              height: 42,
              child: FilledButton(
                onPressed: onRetry ?? () => _load(reset: true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('重新加载',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          '没有找到符合条件的题目\n换个关键词或清空筛选试试',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.7),
        ),
      ),
    );
  }
}

/// 分类 / 筛选小胶囊（页面与筛选弹层复用）。
class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool active;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 3),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE7EDFF) : AppColors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: active ? AppColors.blue : AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: active ? AppColors.blue : AppColors.ink,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    color: active ? AppColors.blue : AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 次级筛选结果（技能方向 + 难度），确认或重置后一次性回写。
class _SecondaryFilterResult {
  const _SecondaryFilterResult({this.skillId, this.difficulty});

  final int? skillId;
  final String? difficulty;
}

/// 技能方向 / 难度筛选弹层。
///
/// 选择只改弹层内状态，点「完成」才回写页面并刷新列表，避免每点一次就发请求。
class _SecondaryFilterSheet extends StatefulWidget {
  const _SecondaryFilterSheet({
    required this.skills,
    required this.difficulties,
    this.skillId,
    this.difficulty,
  });

  final List<SkillFamilyOption> skills;
  final List<String> difficulties;
  final int? skillId;
  final String? difficulty;

  @override
  State<_SecondaryFilterSheet> createState() => _SecondaryFilterSheetState();
}

class _SecondaryFilterSheetState extends State<_SecondaryFilterSheet> {
  int? _skillId;
  String? _difficulty;

  @override
  void initState() {
    super.initState();
    _skillId = widget.skillId;
    _difficulty = widget.difficulty;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('筛选', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context, const _SecondaryFilterResult()),
                  child: const Text('重置'),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.skills.isNotEmpty) ...[
                      const _SheetSectionTitle('技能方向'),
                      Wrap(
                        children: [
                          _SelectChip(
                            label: '全部',
                            active: _skillId == null,
                            onTap: () => setState(() => _skillId = null),
                          ),
                          for (final item in widget.skills)
                            _SelectChip(
                              label: item.name,
                              count: item.count,
                              active: _skillId == item.id,
                              onTap: () => setState(() => _skillId = item.id),
                            ),
                        ],
                      ),
                    ],
                    if (widget.difficulties.isNotEmpty) ...[
                      const _SheetSectionTitle('难度'),
                      Wrap(
                        children: [
                          _SelectChip(
                            label: '全部',
                            active: _difficulty == null,
                            onTap: () => setState(() => _difficulty = null),
                          ),
                          for (final item in widget.difficulties)
                            _SelectChip(
                              label: item,
                              active: _difficulty == item,
                              onTap: () => setState(() => _difficulty = item),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  _SecondaryFilterResult(skillId: _skillId, difficulty: _difficulty),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('完成',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}
