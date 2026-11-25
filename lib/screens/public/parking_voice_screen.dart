import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/parking_voice_controller.dart';

class ParkingVoiceScreen extends StatelessWidget {
  const ParkingVoiceScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('앱 음성통화')),
      body: const SingleChildScrollView(
          child: ParkingVoicePanel(showAvailability: true)));
}

/// Embedded above the app navigator so a call remains visible on pushed routes.
class ParkingVoicePanel extends StatelessWidget {
  const ParkingVoicePanel(
      {super.key, this.controller, this.showAvailability = false});
  final ParkingVoiceController? controller;
  final bool showAvailability;

  @override
  Widget build(BuildContext context) {
    final voice = controller ?? context.watch<ParkingVoiceController?>();
    if (voice == null) return const SizedBox.shrink();
    return ListenableBuilder(
        listenable: voice,
        builder: (context, _) {
          final call = voice.activeCall;
          final incoming = voice.incomingCalls;
          if (call == null &&
              incoming.isEmpty &&
              voice.message == null &&
              !showAvailability) {
            return const SizedBox.shrink();
          }
          return SafeArea(
              bottom: false,
              child: Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('앱 음성통화',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          if (call != null) ...[
                            Text(
                                '${call['slotName'] ?? call['slotId'] ?? ''} · ${call['peerNickname'] ?? '회원'}'),
                            Text(call['status'] == 'ringing'
                                ? '상대방의 수락을 기다리고 있습니다.'
                                : voice.connected
                                    ? '통화 중 · 최대 3분 · 앱을 열어 두세요.'
                                    : '음성을 연결하고 있습니다.'),
                            if (call['status'] == 'accepted')
                              Wrap(spacing: 8, children: [
                                FilterChip(
                                    label: const Text('음소거'),
                                    selected: voice.muted,
                                    onSelected: voice.setMuted),
                                FilterChip(
                                    label: const Text('스피커'),
                                    selected: voice.speakerEnabled,
                                    onSelected: voice.setSpeaker),
                              ]),
                            TextButton.icon(
                                onPressed: voice.end,
                                icon: const Icon(Icons.call_end),
                                label: Text(call['status'] == 'ringing'
                                    ? '요청 취소'
                                    : '통화 종료')),
                          ] else if (incoming.isNotEmpty) ...[
                            Text(
                                '${incoming.first['slotName'] ?? incoming.first['slotId'] ?? '주차면'} 관련 통화 요청'),
                            Text(
                                '${incoming.first['peerNickname'] ?? '회원'}님이 통화를 요청했습니다.'),
                            const Text(
                                '수락하기 전에는 마이크를 켜지 않습니다. 앱을 열고 있을 때 최대 3분 통화할 수 있습니다.'),
                            const Text(
                                '음성과 연결 정보가 통화에 사용됩니다. 앱에서 음성을 녹음하지 않습니다.'),
                            Wrap(spacing: 8, children: [
                              OutlinedButton(
                                  onPressed: voice.busy
                                      ? null
                                      : () => voice.reject(incoming.first),
                                  child: const Text('거절')),
                              FilledButton(
                                  onPressed: voice.busy
                                      ? null
                                      : () => voice.accept(incoming.first),
                                  child: const Text('수락')),
                            ]),
                          ] else if (showAvailability) ...[
                            Text(voice.available
                                ? '현재 통화를 허용한 주차 차량의 상세에서 통화를 요청할 수 있습니다.'
                                : voice.unavailableReason),
                            const Text(
                                '수신 허용은 주차 건마다 기본 꺼짐입니다. 앱에서 음성을 녹음하지 않습니다.'),
                          ],
                          if (voice.busy) const LinearProgressIndicator(),
                          if (voice.message != null)
                            Row(children: [
                              Expanded(
                                  child: Text(voice.message!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                              IconButton(
                                  onPressed: voice.clearMessage,
                                  icon: const Icon(Icons.close),
                                  tooltip: '알림 닫기'),
                            ]),
                        ]),
                  )));
        });
  }
}
