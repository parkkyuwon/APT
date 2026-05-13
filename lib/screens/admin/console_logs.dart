import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../models/activity_log.dart';
import '../../services/services.dart';

/// [console_logs_k9r2m4x.html] — 활동 이력 테이블.
class ConsoleLogs extends StatefulWidget {
  const ConsoleLogs({super.key});

  @override
  State<ConsoleLogs> createState() => _ConsoleLogsState();
}

class _ConsoleLogsState extends State<ConsoleLogs> {
  List<ActivityLog> _logs = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await context.read<ApiServices>().logs.list(limit: 120);
      setState(() => _logs = logs);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MM/dd HH:mm:ss');
    return Scaffold(
      appBar: AppBar(
        title: Text('활동 이력 (${_logs.length})'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : RefreshIndicator(
              onRefresh: _load,
              child: _logs.isEmpty && !_loading
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('기록된 활동 이력이 없습니다.')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final l = _logs[i];
                        return ListTile(
                          title: Text(
                            l.action,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${l.actorNickname.isEmpty ? l.actorEmail : l.actorNickname} · ${l.actorRole}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (l.actionTarget.isNotEmpty)
                                Text('대상: ${l.actionTarget}',
                                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              if (l.details.isNotEmpty)
                                Text(
                                  _formatDetails(l.details),
                                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                                ),
                            ],
                          ),
                          trailing: Text(
                            l.createdAt != null ? df.format(l.createdAt!.toLocal()) : '-',
                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  String _formatDetails(Map<String, dynamic> details) {
    final entries = details.entries
        .where((e) => e.value != null && '${e.value}'.isNotEmpty)
        .take(4)
        .map((e) => '${e.key}: ${e.value}')
        .join(' / ');
    return entries;
  }
}
