import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/errors.dart';
import '../models/parking_slot.dart';
import '../models/session.dart';

bool canRequestDeparture(SessionInfo? session, SlotDetail detail) =>
    session != null &&
    session.approved &&
    session.email.isNotEmpty &&
    session.vehicleNumber.trim().isNotEmpty &&
    detail.isOccupied &&
    !detail.isOwnedBy(session.email) &&
    detail.vehicleNumber.isNotEmpty &&
    detail.vehicleNumber != '비등록 사용자' &&
    DateTime.tryParse(detail.startTime) != null;

class DepartureRequestFeedback {
  const DepartureRequestFeedback(this.message, {this.retryAfterSeconds = 300});
  final String message;
  final int retryAfterSeconds;
}

class DepartureRequestButton extends StatefulWidget {
  const DepartureRequestButton(
      {super.key,
      required this.session,
      required this.detail,
      required this.slotId,
      required this.onSend});
  final SessionInfo session;
  final SlotDetail detail;
  final String slotId;
  final Future<DepartureRequestFeedback> Function() onSend;
  @override
  State<DepartureRequestButton> createState() => _DepartureRequestButtonState();
}

class _DepartureRequestButtonState extends State<DepartureRequestButton> {
  bool _sending = false;
  String? _message;
  bool _success = false;
  bool _confirming = false;
  DateTime? _nextAllowedAt;
  Timer? _retryTimer;

  void _cooldown(int seconds) {
    _retryTimer?.cancel();
    if (seconds <= 0) {
      _nextAllowedAt = null;
      return;
    }
    _nextAllowedAt = DateTime.now().add(Duration(seconds: seconds));
    _retryTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) setState(() => _nextAllowedAt = null);
    });
  }

  Future<void> _send() async {
    if (_sending || _confirming || _nextAllowedAt != null) return;
    setState(() => _confirming = true);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('출차를 요청할까요?'),
              content:
                  Text('충전 완료를 직접 확인하셨나요?\n앱의 예상 시간은 실제 충전 상태와 다를 수 있습니다.\n\n'
                      '요청 차량: ${widget.session.vehicleNumber}\n'
                      '상대방에게 요청 차량번호와 주차 위치가 전달됩니다.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('취소')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('확인 후 요청'))
              ],
            ));
    if (!mounted) return;
    setState(() => _confirming = false);
    if (confirmed != true || _sending || _nextAllowedAt != null) return;
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      final feedback = await widget.onSend();
      if (mounted) {
        setState(() {
          _success = true;
          _message = feedback.message;
          _cooldown(feedback.retryAfterSeconds);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _success = false;
          if (e is ApiException) {
            if (e.statusCode == 429) {
              _cooldown(
                  int.tryParse('${e.rawBody?['retryAfterSeconds']}') ?? 300);
              _message = '이미 요청했습니다. 아래 시간 이후 다시 요청할 수 있습니다.';
            } else if (e.statusCode == 409) {
              _message = '주차 정보가 변경되었습니다. 화면을 닫고 새로고침해 주세요.';
            } else if (e.statusCode == 401 || e.statusCode == 403) {
              _message = '로그인과 등록 차량 승인 상태를 확인해 주세요.';
            } else {
              _message = '현재 차량에 요청을 보내지 못했습니다. 다시 시도해 주세요.';
            }
          } else {
            _message = '요청을 보내지 못했습니다. 연결을 확인하고 다시 시도해 주세요.';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!canRequestDeparture(widget.session, widget.detail)) {
      return const SizedBox.shrink();
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FilledButton.icon(
          onPressed:
              _sending || _confirming || _nextAllowedAt != null ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.notifications_active_outlined),
          label: Text(_sending
              ? '요청 중…'
              : _success && _nextAllowedAt != null
                  ? '출차 요청 접수됨'
                  : '출차 요청하기')),
      if (_nextAllowedAt != null)
        Text('다음 요청 가능: ${DateFormat('HH:mm:ss').format(_nextAllowedAt!)}'),
      if (_message != null)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_message!,
                style: TextStyle(
                    color: _success ? Colors.green.shade800 : Colors.red))),
    ]);
  }
}
