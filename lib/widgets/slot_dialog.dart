import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';

import '../core/duration_presets.dart';
import '../core/privacy.dart';
import '../core/plate_recognition.dart';
import '../core/qr_payload.dart';
import '../models/app_state.dart';
import '../models/charger_type.dart';
import '../models/parking_slot.dart';
import '../models/session.dart';
import '../services/services.dart';
import '../services/parking_voice_controller.dart';
import 'departure_request_button.dart';

enum SlotDialogAction { park, checkout, toggleBlocked }

/// 슬롯 다이얼로그 반환값.
class SlotDialogResult {
  SlotDialogResult({required this.action, this.detail, this.callAllowed});
  final SlotDialogAction action;
  final SlotDetail? detail;
  final bool? callAllowed;
}

/// [index.html slotDialog] / [script.js openSlotDialog] 포팅.
///
/// 차량번호/시작시간/충전시간/출차시간/자동출차 입력.
/// action 은 owner 상태에 따라 "주차하기" / "수정하기" / "출차하기" / "주차 불가로 표시".
Future<SlotDialogResult?> showSlotDialog(
  BuildContext context, {
  required ParkingSlot slot,
  required SlotDetail currentDetail,
  required AppState appState,
  required SessionInfo session,
  bool? voiceAvailable,
  Future<void> Function()? onVoiceCall,
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
        voiceAvailable: voiceAvailable,
        onVoiceCall: onVoiceCall,
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
    this.voiceAvailable,
    this.onVoiceCall,
  });

  final ParkingSlot slot;
  final SlotDetail currentDetail;
  final AppState appState;
  final SessionInfo session;
  final bool? voiceAvailable;
  final Future<void> Function()? onVoiceCall;

  @override
  State<_SlotDialogBody> createState() => _SlotDialogBodyState();
}

class _SlotDialogBodyState extends State<_SlotDialogBody> {
  final _vehicleNumber = TextEditingController();
  bool _autoCheckout = true;
  DateTime? _start;
  DateTime? _departure;
  int _durationMinutes = 0;
  String? _error;
  bool _callAllowed = false;

  bool get _isOwnedByMe => widget.currentDetail.isOwnedBy(widget.session.email);

  bool get _isOwnedByOther =>
      widget.currentDetail.hasParkingRecord && !_isOwnedByMe;

  bool get _readOnly => _isOwnedByOther && !widget.session.isAdmin;

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
    _callAllowed = _isOwnedByMe && widget.currentDetail.callAllowed;
  }

  void _prefill() {
    final d = widget.currentDetail;
    if (d.hasParkingRecord) {
      _vehicleNumber.text = _readOnly
          ? vehicleFor(widget.session, d.vehicleNumber)
          : widget.session.isAdmin
              ? d.vehicleNumber
              : widget.session.vehicleNumber;
      _start = DateTime.tryParse(d.startTime);
      _departure = DateTime.tryParse(d.departureTime);
      _durationMinutes = parseDurationLabel(d.chargeDuration);
    } else {
      _vehicleNumber.text = widget.session.vehicleNumber;
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
      _start =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
      _departure =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    if (_readOnly) return;
    if (!isSinglePlate(_vehicleNumber.text) || _durationMinutes <= 0) {
      setState(() => _error = '차량번호 한 개와 충전 소요 시간을 정확히 입력해 주세요.');
      return;
    }
    final detail = SlotDetail(
      vehicleNumber: normalizePlate(_vehicleNumber.text),
      contact: '',
      contactVisible: false,
      startTime: _start != null ? _start!.toIso8601String() : '',
      departureTime: _departure != null ? _departure!.toIso8601String() : '',
      chargeDuration: formatDurationMinutes(_durationMinutes),
      ownerEmail: _isOwnedByOther
          ? widget.currentDetail.ownerEmail
          : widget.session.email,
      ownerNickname: _isOwnedByOther
          ? widget.currentDetail.ownerNickname
          : widget.session.nickname.isNotEmpty
              ? widget.session.nickname
              : widget.session.name,
      ownerInstanceAt: widget.currentDetail.ownerInstanceAt,
      parkingBlocked: widget.currentDetail.parkingBlocked,
      parkingRegistrationId: widget.currentDetail.parkingRegistrationId,
      callAllowed: widget.currentDetail.callAllowed,
    );
    Navigator.of(context).pop(
      SlotDialogResult(
          action: SlotDialogAction.park,
          detail: detail,
          callAllowed: _isOwnedByOther ||
                  _callAllowed ==
                      (_isOwnedByMe && widget.currentDetail.callAllowed)
              ? null
              : _callAllowed),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final readOnly = _readOnly;
    final presets = durationPresets;
    final voice = context.watch<ParkingVoiceController?>();
    final voiceAvailable = widget.voiceAvailable ?? voice?.available ?? false;

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
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
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
                    '차량번호: ${widget.currentDetail.vehicleNumber.isEmpty ? '비공개' : vehicleFor(widget.session, widget.currentDetail.vehicleNumber)}',
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
              readOnly: !widget.session.isAdmin,
              decoration: const InputDecoration(
                labelText: '차량번호',
                hintText: '예: 123가 4567',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (!_isOwnedByOther) ...[
              CheckboxListTile(
                value: _callAllowed,
                onChanged: widget.session.approved &&
                        (voiceAvailable || _callAllowed)
                    ? (value) => setState(() => _callAllowed = value ?? false)
                    : null,
                title: const Text('이번 주차 중 앱 음성통화 받기'),
                subtitle: Text(voiceAvailable
                    ? '앱을 열고 있을 때만 통화할 수 있습니다.'
                    : voice?.unavailableReason ??
                        '음성통화 중계 서버가 준비되지 않아 사용할 수 없습니다.'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 8),
            ],
            if (_isOwnedByOther &&
                widget.currentDetail.hasParkingRecord &&
                !widget.currentDetail.parkingBlocked &&
                widget.currentDetail.callAllowed &&
                widget.currentDetail.parkingRegistrationId.isNotEmpty &&
                voiceAvailable &&
                widget.session.approved)
              OutlinedButton.icon(
                  onPressed: () async {
                    final callback = widget.onVoiceCall;
                    Navigator.of(context).pop();
                    try {
                      if (callback != null) {
                        await callback();
                      } else {
                        await voice?.startCall(
                            widget.slot.id, widget.currentDetail);
                      }
                    } catch (_) {
                      /* Controller presents call errors in the global call panel. */
                    }
                  },
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('차주에게 앱 통화')),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '주차 시작 시간',
                border: OutlineInputBorder(),
              ),
              child: Row(
                children: [
                  Expanded(
                    child:
                        Text(_start != null ? df.format(_start!) : '선택하지 않음'),
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
                    child: Text(_departure != null
                        ? df.format(_departure!)
                        : '선택하지 않음'),
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
              onChanged: readOnly
                  ? null
                  : (v) => setState(() => _autoCheckout = v ?? true),
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
            if (canRequestDeparture(widget.session, widget.currentDetail)) ...[
              DepartureRequestButton(
                session: widget.session,
                detail: widget.currentDetail,
                slotId: widget.slot.id,
                onSend: () async {
                  final request = await context
                      .read<ApiServices>()
                      .departureRequests
                      .send(
                          slotId: widget.slot.id, detail: widget.currentDetail);
                  return DepartureRequestFeedback(
                      request.pushStatus == 'sent'
                          ? '출차 요청이 접수되고 알림 발송이 처리되었습니다. 상대방의 확인을 기다려 주세요.'
                          : '출차 요청이 접수되었습니다. 상대방이 앱의 출차 요청 목록에서 확인할 수 있습니다. 휴대폰 알림은 전달되지 않았을 수 있습니다.',
                      retryAfterSeconds: request.retryAfterSeconds);
                },
              ),
              const SizedBox(height: 8),
            ],
            if (!readOnly) ...[
              if (widget.session.isAdmin)
                OutlinedButton.icon(
                  onPressed: _toggleBlocked,
                  icon: const Icon(Icons.block),
                  label: Text(_isBlocked ? '주차 가능으로 표시' : '주차 불가로 표시'),
                ),
              if (widget.session.isAdmin) const SizedBox(height: 8),
              if (_isOwnedByMe ||
                  (widget.session.isAdmin &&
                      widget.currentDetail.hasParkingRecord)) ...[
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
                onPressed:
                    _isBlocked && !widget.session.isAdmin ? null : _submit,
                icon: const Icon(Icons.ev_station),
                label: Text(
                    widget.currentDetail.hasParkingRecord ? '수정하기' : '주차하기'),
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
