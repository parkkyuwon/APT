import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/image_utils.dart';
import '../../models/community.dart';
import '../../models/app_state.dart';
import '../../providers/auth_provider.dart';
import '../../services/services.dart';
import 'board_screen.dart';

class ChargerReportsScreen extends StatefulWidget {
  const ChargerReportsScreen({super.key});
  @override
  State<ChargerReportsScreen> createState() => _ChargerReportsScreenState();
}

class _ChargerReportsScreenState extends State<ChargerReportsScreen> {
  List<ChargerReport> _reports = [];
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
      final list = await context.read<ApiServices>().community.reports(
          before: next && _reports.isNotEmpty ? _reports.last.id : null);
      if (!mounted) return;
      setState(() {
        _reports = next ? [..._reports, ...list] : list;
        _more = list.length == 50;
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

  Future<void> _create() async {
    final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const ChargerReportEditor()));
    if (saved == true && mounted) await _load();
  }

  Future<void> _detail(ChargerReport report) async {
    final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => _ReportDetail(report: report)));
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AuthProvider>().isAdmin;
    return Scaffold(
      appBar: AppBar(title: Text(admin ? '충전기 고장 신고 관리' : '내 충전기 고장 신고')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _create,
          icon: const Icon(Icons.report_problem_outlined),
          label: const Text('고장 신고')),
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
                      child: const Text('다시 시도'))
                ],
                if (!_loading && _error == null && _reports.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(30),
                      child: Text('접수된 고장 신고가 없습니다.')),
                for (final report in _reports)
                  Card(
                      child: ListTile(
                          title:
                              Text('${report.slotId} · ${report.statusLabel}'),
                          subtitle: Text(
                              '${report.description}\n${communityDate(report.createdAt)}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis),
                          isThreeLine: true,
                          trailing: Icon(!report.hasPhoto
                              ? Icons.chevron_right
                              : Icons.photo_outlined),
                          onTap: () => _detail(report))),
                if (_more)
                  TextButton(
                      onPressed: _loading ? null : () => _load(next: true),
                      child: const Text('더 불러오기')),
              ])),
    );
  }
}

class _ReportDetail extends StatefulWidget {
  const _ReportDetail({required this.report});
  final ChargerReport report;
  @override
  State<_ReportDetail> createState() => _ReportDetailState();
}

class _ReportDetailState extends State<_ReportDetail> {
  bool _busy = false;
  bool _loading = true;
  ChargerReport? _report;
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
      final report =
          await context.read<ApiServices>().community.report(widget.report.id);
      if (mounted) setState(() => _report = report);
    } catch (e) {
      if (mounted) setState(() => _error = communityError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _status(String status) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context
          .read<ApiServices>()
          .community
          .updateReportStatus(widget.report.id, status);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = communityError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report ?? widget.report;
    return Scaffold(
        appBar: AppBar(title: const Text('고장 신고 상세')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(report.slotId, style: Theme.of(context).textTheme.headlineSmall),
          Text('${report.statusLabel} · ${communityDate(report.createdAt)}'),
          if (context.watch<AuthProvider>().isAdmin)
            Text('신고자: ${report.authorName}'),
          const Divider(height: 32),
          SelectableText(report.description),
          if (report.photo.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ReportPhoto(dataUrl: report.photo)
          ],
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_error != null)
            TextButton(
                onPressed: _loading ? null : _load, child: const Text('다시 시도')),
          if (_busy) const LinearProgressIndicator(),
          if (context.watch<AuthProvider>().isAdmin) ...[
            const SizedBox(height: 24),
            const Text('처리 상태 변경'),
            for (final entry in const {
              'received': '접수',
              'in_progress': '처리 중',
              'resolved': '완료'
            }.entries)
              OutlinedButton(
                  onPressed: _busy ||
                          _loading ||
                          _report == null ||
                          report.status == entry.key
                      ? null
                      : () => _status(entry.key),
                  child: Text(entry.value)),
          ],
        ]));
  }
}

class _ReportPhoto extends StatelessWidget {
  const _ReportPhoto({required this.dataUrl});
  final String dataUrl;
  @override
  Widget build(BuildContext context) {
    try {
      final bytes = base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1));
      return Image.memory(bytes,
          height: 260,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text('사진을 표시할 수 없습니다.'));
    } catch (_) {
      return const Text('사진을 표시할 수 없습니다.');
    }
  }
}

class ChargerReportEditor extends StatefulWidget {
  const ChargerReportEditor({super.key, this.initialSlotId});
  final String? initialSlotId;
  @override
  State<ChargerReportEditor> createState() => _ChargerReportEditorState();
}

class _ChargerReportEditorState extends State<ChargerReportEditor> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  String? _slotId;
  String? _photo;
  String? _error;
  bool _busy = false;
  bool _picking = false;
  AppState? _locations;
  bool _loadingLocations = false;
  String? _locationError;
  @override
  void initState() {
    super.initState();
    _slotId = widget.initialSlotId;
    unawaited(_loadLocations());
  }

  Future<void> _loadLocations() async {
    if (_loadingLocations || _busy) return;
    setState(() {
      _loadingLocations = true;
      _locations = null;
      _locationError = null;
    });
    try {
      final locations = await context.read<ApiServices>().state.fetch();
      if (!mounted) return;
      setState(() {
        _locations = locations;
        if (!locations.slots.values
            .expand((items) => items)
            .any((slot) => slot.id == _slotId)) {
          _slotId = null;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _locationError = communityError(e));
    } finally {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_picking || _busy) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final image = await ImagePicker().pickImage(
          source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 20 * 1024 * 1024) throw StateError('large photo');
      final url = await encodeVehiclePhotoDataUrl(bytes);
      if (base64Decode(url.substring(url.indexOf(',') + 1)).length >
          900 * 1024) {
        if (mounted) setState(() => _error = '사진이 너무 큽니다. 더 작은 사진을 선택해 주세요.');
        return;
      }
      if (mounted) setState(() => _photo = url);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '사진을 읽지 못했습니다. 권한을 확인하고 다시 선택해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _picking || _loadingLocations || _locations == null) return;
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<ApiServices>().community.createReport(
          slotId: _slotId!, description: _description.text, photo: _photo);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = communityError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _locations;
    final slots = state?.slots.values.expand((items) => items).toList() ?? [];
    final validSlot = slots.any((slot) => slot.id == _slotId) ? _slotId : null;
    return Scaffold(
      appBar: AppBar(title: const Text('충전기 고장 신고')),
      body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Text('충전기 위치와 고장 내용을 알려주세요. 사진은 선택 사항입니다.'),
            const SizedBox(height: 16),
            if (_loadingLocations) const LinearProgressIndicator(),
            if (_locationError != null)
              Text(_locationError!, style: const TextStyle(color: Colors.red)),
            if (!_loadingLocations && (state == null || slots.isEmpty)) ...[
              if (_locationError == null) const Text('등록된 충전기 위치가 없습니다.'),
              TextButton(
                  onPressed: _busy ? null : _loadLocations,
                  child: const Text('위치 다시 불러오기')),
            ],
            DropdownButtonFormField<String>(
                key: ValueKey(state),
                initialValue: validSlot,
                decoration: const InputDecoration(
                    labelText: '충전기 / 주차 위치', border: OutlineInputBorder()),
                isExpanded: true,
                items: slots
                    .map((slot) => DropdownMenuItem(
                        value: slot.id,
                        child: Text(
                            '${state?.slotNames[slot.id] ?? slot.id} (${slot.id})')))
                    .toList(),
                onChanged: _busy || _loadingLocations || state == null
                    ? null
                    : (value) => setState(() => _slotId = value),
                validator: (value) =>
                    value == null || !slots.any((slot) => slot.id == value)
                        ? '신고할 위치를 선택해 주세요.'
                        : null),
            const SizedBox(height: 16),
            TextFormField(
                controller: _description,
                enabled: !_busy,
                minLines: 5,
                maxLines: 10,
                maxLength: 4000,
                decoration: const InputDecoration(
                    labelText: '고장 내용',
                    hintText: '증상과 발생 상황을 입력해 주세요.',
                    border: OutlineInputBorder()),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '고장 내용을 입력해 주세요.' : null),
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(
                  onPressed: _busy || _picking
                      ? null
                      : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('촬영')),
              OutlinedButton.icon(
                  onPressed: _busy || _picking
                      ? null
                      : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('사진 선택')),
            ]),
            if (_picking) const LinearProgressIndicator(),
            if (_photo != null) ...[
              _ReportPhoto(dataUrl: _photo!),
              TextButton(
                  onPressed: _busy || _picking
                      ? null
                      : () => setState(() => _photo = null),
                  child: const Text('사진 제거'))
            ],
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: _busy ||
                        _picking ||
                        _loadingLocations ||
                        state == null ||
                        slots.isEmpty
                    ? null
                    : _save,
                child: Text(_busy ? '접수 중...' : '신고 접수')),
          ])),
    );
  }
}
