import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../data/questions_models.dart';
import '../data/questions_providers.dart';

/// 我的收藏：分页展示收藏的题库题目，支持取消收藏后即时移除。
class FavoriteListScreen extends ConsumerStatefulWidget {
  const FavoriteListScreen({super.key});

  @override
  ConsumerState<FavoriteListScreen> createState() => _FavoriteListScreenState();
}

class _FavoriteListScreenState extends ConsumerState<FavoriteListScreen> {
  static const int _pageSize = 10;

  final _scroll = ScrollController();

  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  final List<Question> _items = [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
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
      final page = await ref
          .read(questionsRepositoryProvider)
          .favoriteList(pageNum: _page, pageSize: _pageSize);
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

  Future<void> _unfavorite(int questionId) async {
    try {
      await ref.read(favoriteIdsProvider.notifier).toggle(questionId);
      if (!mounted) return;
      showToast(context, '已取消收藏');
    } catch (_) {
      if (!mounted) return;
      showToast(context, '操作失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 收藏状态以 Provider 为准：详情页取消收藏后返回本页也会即时移除。
    final ids = ref.watch(favoriteIdsProvider).asData?.value;
    final items =
        ids == null ? _items : _items.where((q) => ids.contains(q.id)).toList();
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        title: const Text('我的收藏',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: _body(items),
    );
  }

  Widget _body(List<Question> items) {
    if (items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    }
    if (items.isEmpty && _error != null) {
      return _errorView();
    }
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            '还没有收藏题目\n在题库列表或题目详情点击书签即可收藏',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.7),
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.blue,
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == items.length) return _footer();
          return _card(items[index]);
        },
      ),
    );
  }

  Widget _footer() {
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

  Widget _card(Question question) {
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
                    if (question.type.isNotEmpty)
                      _pill(question.type, AppColors.blue, const Color(0xFFE7EDFF)),
                    if (question.difficulty.isNotEmpty)
                      _pill(question.difficulty, AppColors.wine, const Color(0xFFFFE4D8)),
                    if (question.industry.isNotEmpty)
                      _pill(question.industry, AppColors.ink, const Color(0x0F002B99)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _unfavorite(question.id),
                child: const Padding(
                  padding: EdgeInsets.only(left: 6, top: 2),
                  child: Icon(Icons.bookmark, size: 19, color: AppColors.wine),
                ),
              ),
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

  Widget _pill(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.muted, size: 34),
            const SizedBox(height: 12),
            Text(_error ?? '加载失败',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5)),
            const SizedBox(height: 14),
            SizedBox(
              height: 42,
              child: FilledButton(
                onPressed: () => _load(reset: true),
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
}
