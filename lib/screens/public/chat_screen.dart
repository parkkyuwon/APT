import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../models/chat_message.dart';
import '../../providers/auth_provider.dart';
import '../../services/services.dart';

/// [chat.html] — 채팅 목록 + 입력. 15초 자동 폴링.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = false;
  bool _submitting = false;
  String? _error;
  Timer? _poll;
  int? _editingId;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _inputCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = await context.read<ApiServices>().chat.list(limit: 40);
      if (!mounted) return;
      setState(() {
        _messages = list;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_editingId != null) {
        await context.read<ApiServices>().chat.edit(id: _editingId!, message: text);
      } else {
        await context.read<ApiServices>().chat.send(text);
      }
      _inputCtrl.clear();
      _editingId = null;
      await _refresh();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteMessage(ChatMessage m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메시지 삭제'),
        content: const Text('이 메시지를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ApiServices>().chat.delete(m.id);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _startEdit(ChatMessage m) {
    setState(() {
      _editingId = m.id;
      _inputCtrl.text = m.message;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _inputCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;
    return Scaffold(
      appBar: AppBar(
        title: const Text('입주민 대화방'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade50,
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('아직 등록된 메시지가 없습니다.'))
                : ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final isMine = session?.email == m.authorEmail;
                      final canDelete = isMine || session?.role == 'admin';
                      return _MessageBubble(
                        message: m,
                        isMine: isMine,
                        canDelete: canDelete,
                        onEdit: isMine ? () => _startEdit(m) : null,
                        onDelete: canDelete ? () => _deleteMessage(m) : null,
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_editingId != null)
                  Row(
                    children: [
                      const Icon(Icons.edit, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      const Text('수정 중', style: TextStyle(color: Colors.blue)),
                      const Spacer(),
                      TextButton(onPressed: _cancelEdit, child: const Text('취소')),
                    ],
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        maxLines: 3,
                        minLines: 1,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          hintText: '운영 관련 의견이나 확인이 필요한 내용을 남겨 주세요.',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      onPressed: _submitting ? null : _submit,
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final ChatMessage message;
  final bool isMine;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isAdmin = message.authorRole == 'admin';
    final df = DateFormat('MM/dd HH:mm');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMine ? Colors.blue.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                message.authorNickname.isEmpty ? '사용자' : message.authorNickname,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isAdmin ? Colors.green.shade100 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isAdmin ? '관리자' : '사용자',
                  style: TextStyle(
                    fontSize: 10,
                    color: isAdmin ? Colors.green.shade800 : Colors.blue.shade800,
                  ),
                ),
              ),
              const Spacer(),
              if (message.createdAt != null)
                Text(
                  df.format(message.createdAt!.toLocal()),
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(message.message),
          if (onEdit != null || onDelete != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEdit != null)
                    TextButton(
                      onPressed: onEdit,
                      style: TextButton.styleFrom(minimumSize: Size.zero),
                      child: const Text('수정', style: TextStyle(fontSize: 12)),
                    ),
                  if (onDelete != null)
                    TextButton(
                      onPressed: onDelete,
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('삭제', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
