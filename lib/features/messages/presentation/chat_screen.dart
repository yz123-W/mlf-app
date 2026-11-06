import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/async/polling_controller.dart';
import '../../../shared/utils/toast.dart';
import '../data/message_models.dart';
import '../data/message_providers.dart';

/// 企业会话：气泡消息 + 发送 + 定时轮询（进入即已读）。
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.talentId});

  final int talentId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const Duration _pollInterval = Duration(seconds: 8);

  final _input = TextEditingController();
  final _scroll = ScrollController();

  late final PollingController _controller;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<ChatMessage> _messages = const [];
  String _title = '企业会话';
  String _subtitle = '';

  @override
  void initState() {
    super.initState();
    _controller = PollingController(
      interval: _pollInterval,
      onTick: () => _load(silent: true),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _load();
      await _markRead();
      if (mounted) _controller.start();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final detail = await ref
          .read(messageRepositoryProvider)
          .chatList(widget.talentId, cancelToken: _controller.cancelToken);
      if (!mounted) return;
      setState(() {
        _messages = detail.messages;
        if (detail.tenantName.isNotEmpty) _title = detail.tenantName;
        _subtitle = detail.positionName;
        _error = null;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _markRead() async {
    try {
      await ref.read(messageRepositoryProvider).readChat(widget.talentId);
      ref.invalidate(messageOverviewProvider);
    } catch (_) {
      // 已读失败不阻断会话
    }
  }

  Future<void> _send() async {
    final content = _input.text.trim();
    if (content.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(messageRepositoryProvider).sendChat(talentId: widget.talentId, content: content);
      if (!mounted) return;
      _input.clear();
      setState(() {
        _messages = [
          ..._messages,
          ChatMessage(id: -DateTime.now().millisecondsSinceEpoch, isMine: true, content: content),
        ];
      });
      _scrollToBottom();
      await _load(silent: true);
      ref.invalidate(messageOverviewProvider);
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (_subtitle.isNotEmpty)
              Text(_subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _body()),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, color: AppColors.muted, size: 34),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5)),
              const SizedBox(height: 14),
              SizedBox(
                height: 42,
                child: FilledButton(
                  onPressed: () => _load(),
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
    if (_messages.isEmpty) {
      return const Center(
        child: Text('还没有消息\n发出你的第一条打招呼吧',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.7)),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _bubble(_messages[index]),
    );
  }

  Widget _bubble(ChatMessage message) {
    final mine = message.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.blue : AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(mine ? 15 : 4),
            bottomRight: Radius.circular(mine ? 4 : 15),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x0D002B99), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: mine ? Colors.white : AppColors.ink,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(fontSize: 14, color: AppColors.ink),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '说点什么…',
                    hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryButton,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
