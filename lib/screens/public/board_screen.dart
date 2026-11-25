import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../models/community.dart';
import '../../providers/auth_provider.dart';
import '../../services/services.dart';

String communityError(Object error) {
  if (error is ApiException) return error.message;
  if (error is NetworkException) return error.message;
  return '요청을 처리하지 못했습니다. 다시 시도해 주세요.';
}

String communityDate(DateTime? date) =>
    date == null ? '' : DateFormat('yyyy.MM.dd HH:mm').format(date.toLocal());

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});
  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  List<BoardPost> _posts = [];
  bool _loading = false;
  bool _refreshQueued = false;
  bool _more = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool next = false}) async {
    if (_loading) {
      if (!next) _refreshQueued = true;
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context
          .read<ApiServices>()
          .community
          .posts(before: next && _posts.isNotEmpty ? _posts.last.id : null);
      if (!mounted) return;
      setState(() {
        _posts = next ? [..._posts, ...result] : result;
        _more = result.length == 50;
      });
    } catch (e) {
      if (mounted) setState(() => _error = communityError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (_refreshQueued) {
          _refreshQueued = false;
          unawaited(_load());
        }
      }
    }
  }

  Future<void> _open(BoardPost post) async {
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => _PostDetail(post: post)));
    if (changed == true && mounted) await _load();
  }

  Future<void> _write() async {
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const PostEditor()));
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('아파트 게시판')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: _write,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('글쓰기')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_loading) const LinearProgressIndicator(),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  TextButton(
                      onPressed: _loading ? null : _load,
                      child: const Text('다시 시도')),
                ],
                if (!_loading && _error == null && _posts.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(30),
                      child: Text('아파트의 첫 이슈를 작성해 주세요.')),
                for (final post in _posts)
                  Card(
                      child: ListTile(
                          title: Text(post.title),
                          subtitle: Text(
                              '${post.authorName}\n${communityDate(post.createdAt)}'),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(post))),
                if (_more)
                  TextButton(
                      onPressed: _loading ? null : () => _load(next: true),
                      child: const Text('더 불러오기')),
              ]),
        ),
      );
}

class _PostDetail extends StatefulWidget {
  const _PostDetail({required this.post});
  final BoardPost post;
  @override
  State<_PostDetail> createState() => _PostDetailState();
}

class _PostDetailState extends State<_PostDetail> {
  bool _busy = false;
  String? _error;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('게시물 삭제'),
                content: const Text('이 게시물을 삭제하시겠습니까?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('취소')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('삭제'))
                ]));
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<ApiServices>().community.deletePost(widget.post.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = communityError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => PostEditor(post: widget.post)));
    if (changed == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final own = auth.session?.email.toLowerCase() ==
        widget.post.authorEmail.toLowerCase();
    return Scaffold(
        appBar: AppBar(title: const Text('게시물')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(widget.post.title,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
              '${widget.post.authorName} · ${communityDate(widget.post.createdAt)}'),
          const Divider(height: 32),
          SelectableText(widget.post.content),
          const SizedBox(height: 24),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_busy) const LinearProgressIndicator(),
          if (own)
            OutlinedButton(
                onPressed: _busy ? null : _edit, child: const Text('수정')),
          if (own || auth.isAdmin)
            TextButton(
                onPressed: _busy ? null : _delete, child: const Text('삭제')),
        ]));
  }
}

class PostEditor extends StatefulWidget {
  const PostEditor({super.key, this.post});
  final BoardPost? post;
  @override
  State<PostEditor> createState() => _PostEditorState();
}

class _PostEditorState extends State<PostEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.post?.title);
  late final _content = TextEditingController(text: widget.post?.content);
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<ApiServices>().community.savePost(
          id: widget.post?.id, title: _title.text, content: _content.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = communityError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.post == null ? '이슈 작성' : '이슈 수정')),
        body: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              TextFormField(
                  controller: _title,
                  enabled: !_busy,
                  maxLength: 120,
                  decoration: const InputDecoration(
                      labelText: '제목', border: OutlineInputBorder()),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '제목을 입력해 주세요.' : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _content,
                  enabled: !_busy,
                  minLines: 8,
                  maxLines: 16,
                  maxLength: 10000,
                  decoration: const InputDecoration(
                      labelText: '내용', border: OutlineInputBorder()),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '내용을 입력해 주세요.' : null),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? '저장 중...' : '저장')),
            ])),
      );
}
