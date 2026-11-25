import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/services.dart';
import 'console_parking_history.dart';

const profileRequestBaseMessage =
    '닉네임과 차량번호 한 개를 입력하고, 사진 인증이 필요한 경우 번호판 사진 비교를 완료해 주세요.';

class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({super.key, this.initialIncompleteOnly = false});
  final bool initialIncompleteOnly;
  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  static const _limit = 50;
  final _period = TextEditingController(text: '30');
  final _selected = <String>{};
  List<AppUser> _users = [];
  late bool _incompleteOnly;
  bool _inactive = false;
  int? _inactiveValue;
  String _unit = 'days';
  String _search = '';
  int _offset = 0;
  int _generation = 0;
  bool _loading = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _incompleteOnly = widget.initialIncompleteOnly;
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _period.dispose();
    super.dispose();
  }

  Future<void> _load({bool resetPage = false}) async {
    final generation = ++_generation;
    setState(() {
      if (resetPage) _offset = 0;
      _selected.clear();
      _users = [];
      _loading = true;
      _error = null;
    });
    try {
      final users = await context.read<ApiServices>().users.listMembers(
            incompleteOnly: _incompleteOnly,
            inactiveValue: _inactive ? _inactiveValue : null,
            inactiveUnit: _unit,
            limit: _limit,
            offset: _offset,
          );
      if (!mounted || generation != _generation) return;
      setState(() => _users = users);
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  List<AppUser> get _visible {
    final query = _search.toLowerCase();
    return _users
        .where((u) => [u.email, u.name, u.nickname, u.vehicleNumber]
            .any((value) => value.toLowerCase().contains(query)))
        .toList();
  }

  bool _selectable(AppUser user) {
    final self =
        context.read<AuthProvider>().session?.email.trim().toLowerCase();
    return !user.isAdmin &&
        user.email.isNotEmpty &&
        user.email.trim().toLowerCase() != self;
  }

  void _applyPeriod() {
    final value = int.tryParse(_period.text.trim());
    if (_inactive && (value == null || value < 1)) {
      _generation++;
      setState(() {
        _selected.clear();
        _users = [];
        _loading = false;
        _error = '미사용 기간은 1 이상의 정수로 입력해 주세요.';
      });
      return;
    }
    _inactiveValue = value;
    _load(resetPage: true);
  }

  List<AppUser> get _recipients => _users
      .where((u) => _selected.contains(u.email) && _selectable(u))
      .toList();
  Widget _recipientList(List<AppUser> users) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('대상 ${users.length}명',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...users.map((u) => Text(u.email))
        ],
      );

  Future<void> _clearPersonalData() async {
    final users = _recipients;
    if (users.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('선택 회원 개인정보 정리'),
                content: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _recipientList(users),
                      const SizedBox(height: 16),
                      const Text(
                          '전화번호와 남아 있는 차량 심사 사진을 정리합니다. Google 계정, 닉네임, 차량번호와 이용 이력은 유지됩니다.'),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('개인정보 정리'))
                ],
              ));
      if (confirmed != true || !mounted) return;
      final count = await context
          .read<ApiServices>()
          .users
          .clearPersonalData(users.map((u) => u.email).toList());
      if (!mounted) return;
      _notify('$count명 개인정보 정리 완료');
      await _load(resetPage: true);
    } catch (e) {
      if (mounted) _notify('개인정보 정리 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final users = _recipients;
    if (users.isEmpty) return;
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('선택 회원 앱 데이터 삭제'),
                content: SizedBox(
                    width: 420,
                    child: SingleChildScrollView(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _recipientList(users),
                        const SizedBox(height: 16),
                        const Text(
                            '앱 회원 정보, 로그인 세션 및 관련 개인 데이터를 실제로 삭제합니다. 이 작업은 되돌릴 수 없습니다.\n\nGoogle 계정은 유지됩니다. 같은 이메일로 재가입할 수 있지만 관리자 승인을 다시 받아야 합니다.')
                      ],
                    ))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('앱 데이터 삭제'))
                ],
              ));
      if (confirmed != true || !mounted) return;
      final count = await context
          .read<ApiServices>()
          .users
          .deleteMembers(users.map((u) => u.email).toList());
      if (!mounted) return;
      _notify('$count명 앱 데이터 삭제 완료');
      await _load(resetPage: true);
    } catch (e) {
      if (mounted) _notify('삭제 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestProfile() async {
    final users = _recipients;
    if (users.isEmpty || users.any((u) => !u.hasIncompleteProfile)) return;
    setState(() => _busy = true);
    final message = TextEditingController();
    try {
      final custom = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('회원 정보 입력 요청'),
                content: SizedBox(
                    width: 420,
                    child: SingleChildScrollView(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _recipientList(users),
                        const SizedBox(height: 16),
                        const Text('기본 안내'),
                        const Text(profileRequestBaseMessage),
                        const SizedBox(height: 12),
                        TextField(
                            controller: message,
                            maxLength: 2000,
                            minLines: 2,
                            maxLines: 5,
                            decoration: const InputDecoration(
                                labelText: '추가 메시지 (선택)',
                                border: OutlineInputBorder())),
                      ],
                    ))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, message.text.trim()),
                      child: const Text('발송 내용 확인'))
                ],
              ));
      if (custom == null || !mounted) return;
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('입력 요청 발송 확인'),
                content: SizedBox(
                    width: 420,
                    child: SingleChildScrollView(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _recipientList(users),
                        const SizedBox(height: 16),
                        Text(
                            '$profileRequestBaseMessage${custom.isEmpty ? '' : '\n\n$custom'}'),
                        const SizedBox(height: 12),
                        const Text(
                            '앱 내 안내를 저장하고 푸시 발송을 요청합니다. 푸시 접수는 기기 수신을 보장하지 않습니다.')
                      ],
                    ))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('발송'))
                ],
              ));
      if (confirmed != true || !mounted) return;
      final result = await context.read<ApiServices>().users.requestProfiles(
          emails: users.map((u) => u.email).toList(), message: custom);
      if (!mounted) return;
      _notify(
          '앱 내 안내 ${result.sentCount}명 저장 · 푸시 ${result.pushSentCount}건 접수 / ${result.pushFailedCount}건 실패');
      await _load();
    } catch (e) {
      if (mounted) _notify('입력 요청 실패: $e');
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) => message.dispose());
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notify(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final selectable = visible.where(_selectable).toList();
    final allSelected = selectable.isNotEmpty &&
        selectable.every((u) => _selected.contains(u.email));
    final locked = _loading || _busy;
    final canRequest = _recipients.isNotEmpty &&
        _recipients.every((u) => u.hasIncompleteProfile);
    return Scaffold(
      appBar: AppBar(title: const Text('회원 사용 정보 · 정리'), actions: [
        IconButton(
            tooltip: '새로고침',
            onPressed: locked ? null : _load,
            icon: const Icon(Icons.refresh))
      ]),
      body: RefreshIndicator(
          onRefresh: _busy ? () async {} : _load,
          child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Column(children: [
                          Align(
                              alignment: Alignment.centerLeft,
                              child: FilterChip(
                                  label: const Text('프로필 미완료만'),
                                  selected: _incompleteOnly,
                                  onSelected: _busy
                                      ? null
                                      : (v) {
                                          _incompleteOnly = v;
                                          _load(resetPage: true);
                                        })),
                          Row(children: [
                            Checkbox(
                                value: _inactive,
                                onChanged: _busy
                                    ? null
                                    : (v) {
                                        setState(() => _inactive = v!);
                                        _applyPeriod();
                                      }),
                            const Text('장기 미사용'),
                            const SizedBox(width: 8),
                            Expanded(
                                child: TextField(
                                    controller: _period,
                                    enabled: !locked,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: '기간', isDense: true),
                                    onSubmitted: (_) => _applyPeriod())),
                            DropdownButton<String>(
                                value: _unit,
                                items: const [
                                  DropdownMenuItem(
                                      value: 'days', child: Text('일')),
                                  DropdownMenuItem(
                                      value: 'months', child: Text('개월'))
                                ],
                                onChanged: locked
                                    ? null
                                    : (v) {
                                        setState(() => _unit = v!);
                                      }),
                            TextButton(
                                onPressed: locked ? null : _applyPeriod,
                                child: const Text('조회'))
                          ]),
                          const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  '마지막 주차·충전 이용 기준 · 이용 이력이 없으면 가입일\n현재 주차 중인 회원은 미사용 조회에서 제외 · 개월은 달력 기준',
                                  style: TextStyle(fontSize: 11))),
                          const SizedBox(height: 8),
                          TextField(
                              enabled: !locked,
                              decoration: const InputDecoration(
                                  hintText: '현재 페이지에서 이메일/닉네임/이름/차량 검색',
                                  prefixIcon: Icon(Icons.search),
                                  isDense: true),
                              onChanged: (v) => setState(() {
                                    _search = v.trim();
                                    _selected.clear();
                                  })),
                          Row(children: [
                            Checkbox(
                                key: const ValueKey('select-page'),
                                value: allSelected,
                                onChanged: locked || selectable.isEmpty
                                    ? null
                                    : (v) => setState(() {
                                          _selected.clear();
                                          if (v == true) {
                                            _selected.addAll(
                                                selectable.map((u) => u.email));
                                          }
                                        })),
                            const Text('현재 페이지 선택'),
                            const Spacer(),
                            Text('${_selected.length}명 선택')
                          ]),
                          Wrap(spacing: 8, children: [
                            OutlinedButton(
                                onPressed: locked || _selected.isEmpty
                                    ? null
                                    : _clearPersonalData,
                                child: const Text('개인정보 정리')),
                            OutlinedButton(
                                onPressed: locked || _selected.isEmpty
                                    ? null
                                    : _delete,
                                style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        Theme.of(context).colorScheme.error),
                                child: const Text('선택 삭제')),
                            FilledButton(
                                onPressed: locked || !canRequest
                                    ? null
                                    : _requestProfile,
                                child: const Text('정보 입력 요청'))
                          ]),
                          const Text(
                              '관리자·본인은 선택할 수 없습니다. 입력 요청은 프로필 미완료 회원만 가능합니다.',
                              style: TextStyle(fontSize: 11)),
                        ]))),
                if (_loading || _busy)
                  const SliverToBoxAdapter(child: LinearProgressIndicator()),
                if (_error != null)
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(_error!,
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.error)))),
                SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverList.builder(
                        itemCount: visible.isEmpty ? 1 : visible.length,
                        itemBuilder: (context, i) => visible.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                    child: Text(_loading
                                        ? '회원 조회 중…'
                                        : '해당 회원이 없습니다.')))
                            : _memberCard(visible[i], locked))),
              ])),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(
                onPressed: locked || _offset == 0
                    ? null
                    : () {
                        _offset -= _limit;
                        _load();
                      },
                child: const Text('이전')),
            Text('${_offset ~/ _limit + 1}페이지 · ${_users.length}명'),
            TextButton(
                onPressed: locked || _users.length < _limit
                    ? null
                    : () {
                        _offset += _limit;
                        _load();
                      },
                child: const Text('다음'))
          ])),
    );
  }

  Widget _memberCard(AppUser u, bool locked) {
    final df = DateFormat('yyyy-MM-dd HH:mm');
    return Card(
        child: ListTile(
      leading: Checkbox(
          value: _selected.contains(u.email),
          onChanged: locked || !_selectable(u)
              ? null
              : (v) => setState(() {
                    if (v == true) {
                      _selected.add(u.email);
                    } else {
                      _selected.remove(u.email);
                    }
                  })),
      title: Text(u.email),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            '닉네임: ${u.nickname.isEmpty ? '-' : u.nickname} · 차량: ${u.vehicleNumber.isEmpty ? '-' : u.vehicleNumber}'),
        Text(
            '상태: ${u.status.name} · ${u.isAdmin ? '관리자' : '회원'} · ${u.hasIncompleteProfile ? '프로필 미완료' : '정보 입력 완료'}'),
        if (u.createdAt != null)
          Text('가입: ${df.format(u.createdAt!.toLocal())}'),
        if (u.approvedAt != null)
          Text('승인: ${df.format(u.approvedAt!.toLocal())}'),
        Text(
            '마지막 이용: ${u.lastUsedAt == null ? '확인할 수 없음' : df.format(u.lastUsedAt!.toLocal())}${u.activeParking ? ' · 현재 주차 중' : ''}'),
      ]),
      trailing: IconButton(
          tooltip: '주차 이력',
          icon: const Icon(Icons.history),
          onPressed: _busy
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      ConsoleParkingHistory(initialEmail: u.email)))),
    ));
  }
}
