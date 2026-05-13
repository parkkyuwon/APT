import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/duration_presets.dart';
import '../core/privacy.dart';
import '../core/qr_payload.dart';
import '../models/app_state.dart';
import '../models/charger_type.dart';
import '../models/parking_slot.dart';
import '../models/session.dart';

enum SlotDialogAction { park, checkout, toggleBlocked }

/// 슬롯 다이얼로그 반환값.
class SlotDialogResult {
  SlotDialogResult({required this.action, this.detail});
  final SlotDialogAction action;
  final SlotDetail? detail;
}

/// [index.html slotDialog] / [script.js openSlotDialog] 포팅.
///
/// 차량번호/연락처/공개여부/시작시간/충전시간/출차시간/자동출차 입력.
/// action 은 owner 상태에 따라 "주차하기" / "수정하기" / "출차하기" / "주차 불가로 표시".
Future<SlotDialogResult?> showSlotDialog(
  BuildContext context, {
  required ParkingSlot slot,
  required SlotDetail currentDetail,
  required AppState appState,
  required SessionInfo session,
}) {
  return showModalBottomSheet<SlotDialogResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _SlotDialogBody(
        slot: slot,
        currentDetail: currentDetail,
        appState: appState,
        session: session,
      ),
    ),
  );
}

/// 슬롯 상세 다이얼로그 하단의 접이식 QR 카드. 기본 접힘.
class _SlotQrTile extends StatelessWidget {
  const _SlotQrTile({required this.slotId});
  final String slotId;

  @override
  Widget build(BuildContext context) {
    final payload = slotQrPayload(slotId);
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const Icon(Icons.qr_code_2),
        title: const Text('QR 코드'),
        subtitle: Text(slotId, style: const TextStyle(fontSize: 12)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          QrImageView(
            data: payload,
            version: QrVersions.auto,
            size: 180,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 8),
          Text(
            payload,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _SlotDialogBody extends StatefulWidget {
  const _SlotDialogBody({
    required this.slot,
    required this.currentDetail,
    required this.appState,
    required this.session,
  });

  final ParkingSlot slot;
  final SlotDetail currentDetail;
  final AppState appState;
  final SessionInfo session;

  @override
  State<_SlotDialogBody> createState() => _SlotDialogBodyState();
}

class _SlotDialogBodyState extends State<_SlotDialogBody> {
  final _vehicleNumber = TextEditingController();
  final _contact = TextEditingController();
  bool _contactVisible = false;
  bool _autoCheckout = true;
  DateTime? _start;
  DateTime? _departure;
  int _durationMinutes = 0;
  String? _error;

  bool get _isOwnedByMe =>
      widget.currentDetail.ownerEmail.isNotEmpty &&
      widget.currentDetail.ownerEmail == widget.session.email;

  bool get _isOwnedByOther =>
      widget.currentDetail.ownerEmail.isNotEmpty && !_isOwnedByMe;

  bool get _isBlocked => widget.currentDetail.parkingBlocked;

  String get _title {
    final custom = widget.appState.slotNames[widget.slot.id];
    if (custom != null && custom.isNotEmpty) return custom;
    final type = chargerTypeById(widget.slot.typeId);
    final idParts = widget.slot.id.split('-');
    final index = idParts.isNotEmpty ? idParts.last : '';
    return '${type?.name ?? widget.slot.typeId} $index번';
  }

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  void _prefill() {
    final d = widget.currentDetail;
    if (_isOwnedByMe || d.vehicleNumber.isNotEmpty) {
      _vehicleNumber.text = d.vehicleNumber;
      _contact.text = d.contact;
      _contactVisible = d.contactVisible;
      _start = DateTime.tryParse(d.startTime);
      _departure = DateTime.tryParse(d.departureTime);
      _durationMinutes = parseDurationLabel(d.chargeDuration);
    } else {
      _vehicleNumber.text = widget.session.vehicleNumber;
      _contact.text = widget.session.phoneNumber;
      _start = DateTime.now();
      _durationMinutes = defaultDurationMinutesFor(widget.slot.typeId);
    }
    _recalculateDeparture();
  }

  void _recalculateDeparture() {
    if (_start != null && _durationMinutes > 0) {
      _departure = _start!.add(Duration(minutes: _durationMinutes));
    }
  }

  Future<void> _pickStart() async {
    final now = _start ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;
    setState(() {
      _start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _recalculateDeparture();
    });
  }

  Future<void> _pickDeparture() async {
    final now = _departure ?? _start ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;
    setState(() {
      _departure = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    if (_vehicleNumber.text.trim().isEmpty ||
        _contact.text.trim().isEmpty ||
        _durationMinutes <= 0) {
      setState(() =>
          _error = '차량번호, 연락처, 충전 소요 시간을 입력해야 주차할 수 있습니다.');
      return;
    }
    final detail = SlotDetail(
      vehicleNumber: _vehicleNumber.text.trim(),
      contact: _contact.text.trim(),
      contactVisible: _contactVisible,
      startTime: _start != null ? _start!.toIso8601String() : '',
      departureTime: _departure != null ? _departure!.toIso8601String() : '',
      chargeDuration: formatDurationMinutes(_durationMinutes),
      ownerEmail: widget.session.email,
      ownerNickname: widget.session.nickname.isNotEmpty
          ? widget.session.nickname
          : widget.session.name,
      parkingBlocked: widget.currentDetail.parkingBlocked,
    );
    Navigator.of(context).pop(
      SlotDialogResult(action: SlotDialogAction.park, detail: detail),
    );
  }

  void _checkout() {
    Navigator.of(context).pop(
      SlotDialogResult(action: SlotDialogAction.checkout),
    );
  }

  void _toggleBlocked() {
    Navigator.of(context).pop(
      SlotDialogResult(action: SlotDialogAction.toggleBlocked),
    );
  }

  @override
  void dispose() {
    _vehicleNumber.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final readOnly = _isOwnedByOther;
    final presets = durationPresets;

    return Container(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (_isOwnedByOther) ...[
              Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '이미 다른 사용자가 주차 등록한 슬롯입니다.\n'
                    '차량번호: ${widget.currentDetail.vehicleNumber.isEmpty ? '비공개' : vehicleFor(widget.session, widget.currentDetail.vehicleNumber)}\n'
                    '${widget.currentDetail.contactVisible && widget.currentDetail.contact.isNotEmpty ? '연락처: ${phoneFor(widget.session, widget.currentDetail.contact)}' : ''}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_isBlocked && !readOnly) ...[
              Card(
                color: Colors.red.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('현재 주차 불가 상태로 표시되어 있습니다.'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _vehicleNumber,
              enabled: !readOnly,
              decoration: const InputDecoration(
                labelText: '차량번호',
                hintText: '예: 123가 4567',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contact,
              enabled: !readOnly,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '연락처',
                hintText: '예: 010-1234-5678',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _contactVisible,
              onChanged: readOnly ? null : (v) => setState(() => _contactVisible = v ?? true),
              title: const Text('전화번호 다른 사용자에게 표시'),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '주차 시작 시간',
                border: OutlineInputBorder(),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_start != null ? df.format(_start!) : '선택하지 않음'),
                  ),
                  TextButton(
                    onPressed: readOnly ? null : _pickStart,
                    child: const Text('선택'),
                  ),
                  TextButton(
                    onPressed: readOnly
                        ? null
                        : () => setState(() {
                              _start = DateTime.now();
                              _recalculateDeparture();
                            }),
                    child: const Text('현재 시간'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _durationMinutes,
              items: presets
                  .map((p) => DropdownMenuItem<int>(
                        value: p.minutes,
                        child: Text(p.label),
                      ))
                  .toList(),
              onChanged: readOnly
                  ? null
                  : (v) => setState(() {
                        _durationMinutes = v ?? 0;
                        _recalculateDeparture();
                      }),
              decoration: const InputDecoration(
                labelText: '충전 소요 시간',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '예상 출차 시간',
                border: OutlineInputBorder(),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_departure != null ? df.format(_departure!) : '선택하지 않음'),
                  ),
                  TextButton(
                    onPressed: readOnly ? null : _pickDeparture,
                    child: const Text('변경'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _autoCheckout,
              onChanged: readOnly ? null : (v) => setState(() => _autoCheckout = v ?? true),
              title: const Text('예상 출차 시간 도래 시 자동 출차'),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            _SlotQrTile(slotId: widget.slot.id),
            const SizedBox(height: 16),
            if (!readOnly) ...[
              if (widget.session.isAdmin)
                OutlinedButton.icon(
                  onPressed: _toggleBlocked,
                  icon: const Icon(Icons.block),
                  label: Text(_isBlocked ? '주차 가능으로 표시' : '주차 불가로 표시'),
                ),
              if (widget.session.isAdmin) const SizedBox(height: 8),
              if (_isOwnedByMe) ...[
                ElevatedButton.icon(
                  onPressed: _checkout,
                  icon: const Icon(Icons.directions_car_outlined),
                  label: const Text('출차하기'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: Colors.red.shade500,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              ElevatedButton.icon(
                onPressed: _isBlocked && !widget.session.isAdmin ? null : _submit,
                icon: const Icon(Icons.ev_station),
                label: Text(_isOwnedByMe ? '수정하기' : '주차하기'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
