import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/departure_request.dart';
import '../../services/services.dart';

class DepartureRequestsScreen extends StatefulWidget {
  const DepartureRequestsScreen({super.key, this.initialRequestId});
  final int? initialRequestId;
  @override
  State<DepartureRequestsScreen> createState() =>
      _DepartureRequestsScreenState();
}

class _DepartureRequestsScreenState extends State<DepartureRequestsScreen> {
  final List<DepartureRequest> _requests = [];
  bool _loading = false;
  bool _more = false;
  bool _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.initialRequestId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open(widget.initialRequestId!);
      });
    }
  }

  Future<void> _load({bool append = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<ApiServices>().departureRequests.list(
          beforeId: append && _requests.isNotEmpty ? _requests.last.id : null);
      if (!mounted) return;
      setState(() {
        if (!append) _requests.clear();
        final ids = _requests.map((r) => r.id).toSet();
        _requests.addAll(items.where((r) => !ids.contains(r.id)));
        _more = items.length == 30;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '출차 요청을 불러오지 못했습니다. $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(int id) async {
    if (_opening) return;
    _opening = true;
    try {
      final service = context.read<ApiServices>().departureRequests;
      final request = await service.get(id);
      if (!mounted) return;
      // 현재 로그인한 수신자의 요청인지 서버에서 확인한 후에만 상세 표시.
      await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('출차 요청'),
                content: Text(
                    '${request.requesterVehicleNumber} 차량에서 출차를 요청했습니다.\n\n'
                    '위치: ${request.slotName.isEmpty ? request.slotId : request.slotName}\n'
                    '요청 시간: ${_time(request.createdAt)}\n\n'
                    '실제 충전 상태를 확인하고 차량을 이동한 후 앱에서 출차하기를 눌러 주세요.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('확인'))
                ],
              ));
      if (!mounted) return;
      final read = await service.markRead(id);
      if (mounted) {
        setState(() {
          final index = _requests.indexWhere((r) => r.id == id);
          if (index >= 0) _requests[index] = read;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('요청을 확인할 수 없습니다. $e')));
      }
    } finally {
      _opening = false;
    }
  }

  String _time(DateTime? value) =>
      value == null ? '-' : DateFormat('MM/dd HH:mm').format(value.toLocal());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('받은 출차 요청'), actions: [
          IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh)),
        ]),
        body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                const Text('요청 차량과 위치를 확인한 후 실제 충전 상태에 맞춰 출차해 주세요.'),
                const SizedBox(height: 12),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  TextButton(
                      onPressed: _loading ? null : _load,
                      child: const Text('다시 시도'))
                ],
                if (!_loading && _error == null && _requests.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: Text('받은 출차 요청이 없습니다.'))),
                for (final request in _requests)
                  Card(
                      child: ListTile(
                    leading: Icon(request.isRead
                        ? Icons.mark_email_read_outlined
                        : Icons.notifications_active_outlined),
                    title: Text('${request.requesterVehicleNumber} 차량의 출차 요청'),
                    subtitle: Text(
                        '${request.slotName.isEmpty ? request.slotId : request.slotName}\n${_time(request.createdAt)} · ${request.isRead ? '확인함' : '새 요청'}'),
                    isThreeLine: true,
                    onTap: () => _open(request.id),
                  )),
                if (_loading)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator())),
                if (_more && !_loading)
                  TextButton(
                      onPressed: () => _load(append: true),
                      child: const Text('이전 요청 더 보기')),
              ],
            )),
      );
}
